from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token,
    decode_token, get_current_user
)
from app.schemas.schemas import (
    RegisterRequest, LoginRequest,
    TokenResponse, RefreshRequest, UserResponse
)

router = APIRouter(prefix="/auth", tags=["Auth"])


def serialize_user(user: dict) -> dict:
    user["id"] = str(user["_id"])
    del user["_id"]
    user.pop("password_hash", None)
    return user


async def _email_or_username_exists(db, email: str, username: str) -> bool:
    query = {"$or": [{"email": email}, {"username": username}]}
    return any([
        await db.users.find_one(query),
        await db.admins.find_one(query),
        await db.pending_admins.find_one({**query, "status": "pending"}),
    ])


@router.post("/register", response_model=TokenResponse)
async def register(data: RegisterRequest):
    db = get_db()
    if await _email_or_username_exists(db, data.email, data.username):
        raise HTTPException(400, "Bu email veya kullanici adi zaten kayitli")

    user = {
        "email": data.email,
        "username": data.username,
        "password_hash": hash_password(data.password),
        "full_name": data.full_name,
        "phone": data.phone,
        "role": "user",
        "language": data.language,
        "address": None,
        "is_active": True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    result = await db.users.insert_one(user)
    user_id = str(result.inserted_id)

    return TokenResponse(
        access_token=create_access_token({"sub": user_id, "col": "users"}),
        refresh_token=create_refresh_token({"sub": user_id, "col": "users"}),
    )


@router.post("/admin-register")
async def admin_register(data: RegisterRequest):
    db = get_db()
    if await _email_or_username_exists(db, data.email, data.username):
        raise HTTPException(400, "Bu email veya kullanici adi zaten kayitli")

    admin = {
        "email": data.email,
        "username": data.username,
        "password_hash": hash_password(data.password),
        "full_name": data.full_name,
        "phone": data.phone,
        "role": "admin",
        "language": data.language,
        "address": None,
        "is_active": True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }

    existing_admin_count = await db.admins.count_documents({})
    if existing_admin_count > 0:
        admin["is_active"] = False
        admin["status"] = "pending"
        await db.pending_admins.insert_one(admin)
        return {
            "status": "pending",
            "message": "Kullanici basvurunuz alindi. Yetki icin kullanici onayi gerekiyor.",
        }

    result = await db.admins.insert_one(admin)
    admin_id = str(result.inserted_id)

    return TokenResponse(
        access_token=create_access_token({"sub": admin_id, "col": "admins"}),
        refresh_token=create_refresh_token({"sub": admin_id, "col": "admins"}),
    )


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest):
    db = get_db()

    user = await db.users.find_one({"email": data.email})
    col = "users"
    if not user:
        user = await db.admins.find_one({"email": data.email})
        col = "admins"

    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(401, "Email veya sifre hatali")
    if not user.get("is_active"):
        raise HTTPException(403, "Hesabiniz aktif degil veya onay bekliyor")

    user_id = str(user["_id"])
    return TokenResponse(
        access_token=create_access_token({"sub": user_id, "col": col}),
        refresh_token=create_refresh_token({"sub": user_id, "col": col}),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(data: RefreshRequest):
    payload = decode_token(data.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(401, "Gecersiz refresh token")
    user_id = payload.get("sub")
    col = payload.get("col", "users")
    return TokenResponse(
        access_token=create_access_token({"sub": user_id, "col": col}),
        refresh_token=create_refresh_token({"sub": user_id, "col": col}),
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user=Depends(get_current_user)):
    db = get_db()
    is_super_admin = False
    if current_user.get("role") == "admin":
        first_admin = await db.admins.find_one({}, sort=[("created_at", 1)])
        is_super_admin = bool(first_admin and first_admin.get("_id") == current_user["_id"])

    return UserResponse(
        id=str(current_user["_id"]),
        email=current_user["email"],
        username=current_user["username"],
        full_name=current_user["full_name"],
        phone=current_user.get("phone"),
        role=current_user["role"],
        language=current_user.get("language", "tr"),
        address=current_user.get("address"),
        created_at=current_user["created_at"],
        is_super_admin=is_super_admin,
    )
