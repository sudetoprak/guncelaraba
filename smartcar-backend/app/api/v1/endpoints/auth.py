from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
from bson import ObjectId
from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token,
    decode_token, get_current_user, get_current_admin
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


@router.post("/register", response_model=TokenResponse)
async def register(data: RegisterRequest):
    db = get_db()
    if await db.users.find_one({"email": data.email}):
        raise HTTPException(400, "Bu email zaten kayıtlı")
    if await db.users.find_one({"username": data.username}):
        raise HTTPException(400, "Bu kullanıcı adı alınmış")

    user = {
        "email":         data.email,
        "username":      data.username,
        "password_hash": hash_password(data.password),
        "full_name":     data.full_name,
        "phone":         data.phone,
        "role":          "user",
        "language":      data.language,
        "address":       None,
        "is_active":     True,
        "created_at":    datetime.utcnow(),
        "updated_at":    datetime.utcnow(),
    }
    result = await db.users.insert_one(user)
    user_id = str(result.inserted_id)

    return TokenResponse(
        access_token=create_access_token({"sub": user_id, "col": "users"}),
        refresh_token=create_refresh_token({"sub": user_id, "col": "users"}),
    )


@router.post("/admin-register", response_model=TokenResponse)
async def admin_register(data: RegisterRequest):
    """
    İlk admin kaydı: DB'de hiç admin yoksa serbest,
    sonraki admin kayıtları mevcut bir admin token'ı gerektirir.
    Adminler ayrı 'admins' koleksiyonuna kaydedilir.
    """
    db = get_db()

    # Var olan admin sayısını 'admins' koleksiyonunda kontrol et
    existing_admin_count = await db.admins.count_documents({})
    if existing_admin_count > 0:
        raise HTTPException(
            403,
            "Admin kaydı kapalı. İlk admin zaten oluşturulmuş. "
            "Yeni admin eklemek için mevcut bir admin hesabıyla /admin/users endpoint'ini kullanın."
        )

    if await db.admins.find_one({"email": data.email}):
        raise HTTPException(400, "Bu email zaten kayıtlı")
    if await db.admins.find_one({"username": data.username}):
        raise HTTPException(400, "Bu kullanıcı adı alınmış")

    admin = {
        "email":         data.email,
        "username":      data.username,
        "password_hash": hash_password(data.password),
        "full_name":     data.full_name,
        "phone":         data.phone,
        "role":          "admin",
        "language":      data.language,
        "address":       None,
        "is_active":     True,
        "created_at":    datetime.utcnow(),
        "updated_at":    datetime.utcnow(),
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

    # Önce kullanıcılar, sonra adminler koleksiyonuna bak
    user = await db.users.find_one({"email": data.email})
    col  = "users"
    if not user:
        user = await db.admins.find_one({"email": data.email})
        col  = "admins"

    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(401, "Email veya şifre hatalı")
    if not user.get("is_active"):
        raise HTTPException(403, "Hesabınız askıya alınmış")

    user_id = str(user["_id"])
    return TokenResponse(
        access_token=create_access_token({"sub": user_id, "col": col}),
        refresh_token=create_refresh_token({"sub": user_id, "col": col}),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(data: RefreshRequest):
    payload = decode_token(data.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(401, "Geçersiz refresh token")
    user_id = payload.get("sub")
    col     = payload.get("col", "users")
    return TokenResponse(
        access_token=create_access_token({"sub": user_id, "col": col}),
        refresh_token=create_refresh_token({"sub": user_id, "col": col}),
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user=Depends(get_current_user)):
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
    )