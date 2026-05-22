from fastapi import APIRouter, HTTPException, Depends, Query, UploadFile, File
from datetime import datetime
from bson import ObjectId
from typing import List, Optional
import os
import re
import uuid
from app.core.database import get_db
from app.core.security import get_current_admin
from app.core.config import settings
from app.schemas.schemas import ProductCreate, ProductResponse, ProductUpdate

router = APIRouter(prefix="/products", tags=["Products"])


def normalize_category(category: Optional[str]) -> Optional[str]:
    if category is None:
        return None
    value = category.strip()
    category_map = {
        "araba": "Araba",
        "aksesuar": "Aksesuar",
    }
    return category_map.get(value.lower(), value)


def serialize_product(p: dict) -> dict:
    p["id"] = str(p["_id"])
    del p["_id"]
    if isinstance(p.get("owner_id"), ObjectId):
        p["owner_id"] = str(p["owner_id"])
    return p


async def product_owner_query(db, admin: dict) -> dict:
    first_admin = await db.admins.find_one({}, sort=[("created_at", 1)])
    if first_admin and first_admin.get("_id") == admin["_id"]:
        return {"$or": [{"owner_id": admin["_id"]}, {"owner_id": {"$exists": False}}]}
    return {"owner_id": admin["_id"]}


@router.get("/", response_model=List[ProductResponse])
async def list_products(
    category: Optional[str] = None,
    search: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    lang: str = "tr",
):
    db = get_db()
    query = {"is_active": True}
    if category:
        normalized = normalize_category(category)
        query["category"] = {"$regex": f"^{re.escape(normalized)}$", "$options": "i"}
    if search:
        query["$or"] = [
            {f"name.{lang}": {"$regex": search, "$options": "i"}},
            {f"description.{lang}": {"$regex": search, "$options": "i"}},
        ]
    skip = (page - 1) * limit
    cursor = db.products.find(query).skip(skip).limit(limit).sort("created_at", -1)
    products = await cursor.to_list(length=limit)
    return [serialize_product(p) for p in products]


@router.post("/upload-image")
async def upload_image(file: UploadFile = File(...), admin=Depends(get_current_admin)):
    if not file.filename:
        raise HTTPException(400, "Dosya adi bulunamadi")
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in ["jpg", "jpeg", "png", "webp"]:
        raise HTTPException(400, "Sadece jpg, jpeg, png, webp desteklenir")
    filename = f"{uuid.uuid4()}.{ext}"
    save_dir = settings.uploads_dir
    os.makedirs(save_dir, exist_ok=True)
    path = os.path.join(save_dir, filename)
    try:
        content = await file.read()
        with open(path, "wb") as f:
            f.write(content)
    except Exception as e:
        raise HTTPException(500, f"Dosya kaydedilemedi: {str(e)}")
    base = settings.SERVER_BASE_URL.rstrip("/")
    return {"url": f"{base}/uploads/{filename}"}


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: str):
    db = get_db()
    try:
        oid = ObjectId(product_id)
    except Exception:
        raise HTTPException(400, "Gecersiz urun ID")
    product = await db.products.find_one({"_id": oid, "is_active": True})
    if not product:
        raise HTTPException(404, "Urun bulunamadi")
    return serialize_product(product)


@router.post("/", response_model=ProductResponse)
async def create_product(data: ProductCreate, admin=Depends(get_current_admin)):
    db = get_db()
    product = {
        **data.model_dump(),
        "owner_id": admin["_id"],
        "owner_email": admin.get("email"),
        "owner_username": admin.get("username"),
        "is_active": True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    product["category"] = normalize_category(product.get("category"))
    result = await db.products.insert_one(product)
    product["_id"] = result.inserted_id
    return serialize_product(product)


@router.put("/{product_id}", response_model=ProductResponse)
async def update_product(product_id: str, data: ProductUpdate, admin=Depends(get_current_admin)):
    db = get_db()
    try:
        oid = ObjectId(product_id)
    except Exception:
        raise HTTPException(400, "Gecersiz urun ID")
    update_data = {k: v for k, v in data.model_dump().items() if v is not None}
    if "category" in update_data:
        update_data["category"] = normalize_category(update_data["category"])
    update_data["updated_at"] = datetime.utcnow()
    owner_query = await product_owner_query(db, admin)
    result = await db.products.find_one_and_update(
        {"_id": oid, **owner_query},
        {"$set": update_data},
        return_document=True,
    )
    if not result:
        raise HTTPException(404, "Urun bulunamadi veya bu urunu duzenleme yetkiniz yok")
    return serialize_product(result)


@router.delete("/{product_id}")
async def delete_product(product_id: str, admin=Depends(get_current_admin)):
    db = get_db()
    try:
        oid = ObjectId(product_id)
    except Exception:
        raise HTTPException(400, "Gecersiz urun ID")
    owner_query = await product_owner_query(db, admin)
    result = await db.products.update_one(
        {"_id": oid, **owner_query},
        {"$set": {"is_active": False, "updated_at": datetime.utcnow()}},
    )
    if result.matched_count == 0:
        raise HTTPException(404, "Urun bulunamadi veya bu urunu silme yetkiniz yok")
    return {"message": "Urun silindi"}
