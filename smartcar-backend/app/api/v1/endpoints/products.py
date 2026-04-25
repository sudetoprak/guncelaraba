from fastapi import APIRouter, HTTPException, Depends, Query, UploadFile, File
from datetime import datetime
from bson import ObjectId
from typing import List, Optional
import os
import uuid
from app.core.database import get_db
from app.core.security import get_current_user, get_current_admin
from app.core.config import settings
from app.schemas.schemas import ProductCreate, ProductResponse, ProductUpdate

router = APIRouter(prefix="/products", tags=["Products"])

def serialize_product(p: dict) -> dict:
    p["id"] = str(p["_id"])
    del p["_id"]
    return p

@router.get("/", response_model=List[ProductResponse])
async def list_products(
    category: Optional[str] = None,
    search: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    lang: str = "tr"
):
    db = get_db()
    query = {"is_active": True}
    if category:
        query["category"] = category
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
        raise HTTPException(400, "Dosya adı bulunamadı")
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
        raise HTTPException(400, "Geçersiz ürün ID")
    product = await db.products.find_one({"_id": oid, "is_active": True})
    if not product:
        raise HTTPException(404, "Ürün bulunamadı")
    return serialize_product(product)

@router.post("/", response_model=ProductResponse)
async def create_product(data: ProductCreate, admin=Depends(get_current_admin)):
    db = get_db()
    product = {
        **data.model_dump(),
        "is_active": True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    result = await db.products.insert_one(product)
    product["_id"] = result.inserted_id
    return serialize_product(product)

@router.put("/{product_id}", response_model=ProductResponse)
async def update_product(product_id: str, data: ProductUpdate, admin=Depends(get_current_admin)):
    db = get_db()
    try:
        oid = ObjectId(product_id)
    except Exception:
        raise HTTPException(400, "Geçersiz ürün ID")
    update_data = {k: v for k, v in data.model_dump().items() if v is not None}
    update_data["updated_at"] = datetime.utcnow()
    result = await db.products.find_one_and_update(
        {"_id": oid},
        {"$set": update_data},
        return_document=True
    )
    if not result:
        raise HTTPException(404, "Ürün bulunamadı")
    return serialize_product(result)

@router.delete("/{product_id}")
async def delete_product(product_id: str, admin=Depends(get_current_admin)):
    db = get_db()
    try:
        oid = ObjectId(product_id)
    except Exception:
        raise HTTPException(400, "Geçersiz ürün ID")
    await db.products.update_one({"_id": oid}, {"$set": {"is_active": False}})
    return {"message": "Ürün silindi"}