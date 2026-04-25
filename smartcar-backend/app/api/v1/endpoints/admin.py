from fastapi import APIRouter, HTTPException, Depends, Query
from datetime import datetime
from bson import ObjectId
from typing import Optional
from app.core.database import get_db
from app.core.security import get_current_admin, hash_password
from app.schemas.schemas import RegisterRequest, TokenResponse, UserResponse
from app.services.ws_manager import manager

router = APIRouter(prefix="/admin", tags=["Admin"])


# ─── DASHBOARD ────────────────────────────────────────────────────────────────

@router.get("/dashboard")
async def dashboard(admin=Depends(get_current_admin)):
    db = get_db()
    from datetime import timedelta
    now = datetime.utcnow()
    today_start = now - timedelta(hours=24)

    total_users     = await db.users.count_documents({})
    active_users    = await db.users.count_documents({"is_active": True})
    new_today_users = await db.users.count_documents({"created_at": {"$gte": today_start}})

    total_orders = await db.orders.count_documents({})
    today_orders = await db.orders.count_documents({"created_at": {"$gte": today_start}})

    status_pipeline = [{"$group": {"_id": "$status", "count": {"$sum": 1}}}]
    status_dist_raw = await db.orders.aggregate(status_pipeline).to_list(length=10)
    by_status       = {item["_id"]: item["count"] for item in status_dist_raw}

    rev_pipeline = [
        {"$match": {"status": {"$in": ["paid", "shipped", "delivered"]}}},
        {"$group": {"_id": None, "total": {"$sum": "$total"}}},
    ]
    rev_today_pipeline = [
        {"$match": {"status": {"$in": ["paid", "shipped", "delivered"]}, "created_at": {"$gte": today_start}}},
        {"$group": {"_id": None, "total": {"$sum": "$total"}}},
    ]
    rev_result       = await db.orders.aggregate(rev_pipeline).to_list(length=1)
    rev_today_result = await db.orders.aggregate(rev_today_pipeline).to_list(length=1)
    revenue_total    = rev_result[0]["total"] if rev_result else 0.0
    revenue_today    = rev_today_result[0]["total"] if rev_today_result else 0.0

    active_products    = await db.products.count_documents({"is_active": True})
    low_stock_products = await db.products.count_documents({"is_active": True, "stock": {"$lte": 5}})

    ws_status = manager.get_status()

    return {
        "users": {
            "total":     total_users,
            "active":    active_users,
            "new_today": new_today_users,
        },
        "orders": {
            "total":     total_orders,
            "today":     today_orders,
            "by_status": by_status,
        },
        "revenue": {
            "total": revenue_total,
            "today": revenue_today,
        },
        "products": {
            "active":    active_products,
            "low_stock": low_stock_products,
        },
        "connected_cars":    ws_status["connected_cars"],
        "controller_counts": ws_status["controller_counts"],
    }


# ─── GRAFİK VERİLERİ ──────────────────────────────────────────────────────────

@router.get("/charts")
async def get_charts(admin=Depends(get_current_admin)):
    db = get_db()
    from datetime import timedelta
    now = datetime.utcnow()

    days = []
    for i in range(29, -1, -1):
        day_start = (now - timedelta(days=i)).replace(hour=0, minute=0, second=0, microsecond=0)
        day_end   = day_start + timedelta(days=1)
        days.append((day_start, day_end))

    revenue_chart = []
    for day_start, day_end in days:
        pipe = [
            {"$match": {
                "status": {"$in": ["paid", "shipped", "delivered"]},
                "created_at": {"$gte": day_start, "$lt": day_end},
            }},
            {"$group": {"_id": None, "total": {"$sum": "$total"}}},
        ]
        result = await db.orders.aggregate(pipe).to_list(length=1)
        revenue_chart.append({
            "date":  day_start.strftime("%d/%m"),
            "total": round(result[0]["total"], 2) if result else 0.0,
        })

    orders_chart = []
    for day_start, day_end in days:
        count = await db.orders.count_documents({
            "created_at": {"$gte": day_start, "$lt": day_end}
        })
        orders_chart.append({
            "date":  day_start.strftime("%d/%m"),
            "count": count,
        })

    return {
        "revenue_chart": revenue_chart,
        "orders_chart":  orders_chart,
    }


# ─── SON SİPARİŞLER ───────────────────────────────────────────────────────────

@router.get("/recent-orders")
async def recent_orders(admin=Depends(get_current_admin)):
    db = get_db()
    cursor = db.orders.find({}).sort("created_at", -1).limit(5)
    orders = await cursor.to_list(length=5)
    result = []
    for o in orders:
        result.append({
            "id":         str(o["_id"]),
            "user_id":    str(o["user_id"]),
            "total":      o.get("total", 0),
            "status":     o.get("status", ""),
            "created_at": o["created_at"].isoformat() if o.get("created_at") else None,
        })
    return {"orders": result}


# ─── DÜŞÜK STOKLU ÜRÜNLER ─────────────────────────────────────────────────────

@router.get("/low-stock")
async def low_stock_products_list(admin=Depends(get_current_admin)):
    db = get_db()
    cursor = db.products.find(
        {"is_active": True, "stock": {"$lte": 10}}
    ).sort("stock", 1).limit(8)
    products = await cursor.to_list(length=8)
    result = []
    for p in products:
        name = p.get("name", {})
        result.append({
            "id":    str(p["_id"]),
            "name":  name.get("tr", str(name)) if isinstance(name, dict) else str(name),
            "stock": p.get("stock", 0),
        })
    return {"products": result}


# ─── KULLANICILAR ─────────────────────────────────────────────────────────────

def _serialize_user(u: dict) -> dict:
    u["id"] = str(u["_id"])
    del u["_id"]
    u.pop("password_hash", None)
    for key, value in list(u.items()):
        if isinstance(value, ObjectId):
            u[key] = str(value)
        elif isinstance(value, datetime):
            u[key] = value.isoformat()
    return u


@router.get("/users")
async def list_users(
    search: Optional[str] = None,
    role:   Optional[str] = None,
    page:   int = Query(1, ge=1),
    limit:  int = Query(20, ge=1, le=100),
    admin=Depends(get_current_admin),
):
    db = get_db()
    skip = (page - 1) * limit

    search_filter: dict = {}
    if search:
        search_filter["$or"] = [
            {"username":  {"$regex": search, "$options": "i"}},
            {"email":     {"$regex": search, "$options": "i"}},
            {"full_name": {"$regex": search, "$options": "i"}},
        ]

    if role == "admin":
        cursor = db.admins.find(search_filter).sort("created_at", -1).skip(skip).limit(limit)
        users  = await cursor.to_list(length=limit)
        total  = await db.admins.count_documents(search_filter)
    elif role == "user":
        cursor = db.users.find(search_filter).sort("created_at", -1).skip(skip).limit(limit)
        users  = await cursor.to_list(length=limit)
        total  = await db.users.count_documents(search_filter)
    else:
        u_cursor   = db.users.find(search_filter).sort("created_at", -1)
        a_cursor   = db.admins.find(search_filter).sort("created_at", -1)
        all_users  = await u_cursor.to_list(length=None)
        all_admins = await a_cursor.to_list(length=None)
        combined   = sorted(
            all_users + all_admins,
            key=lambda x: x.get("created_at", datetime.min),
            reverse=True,
        )
        total = len(combined)
        users = combined[skip: skip + limit]

    return {"total": total, "page": page, "users": [_serialize_user(u) for u in users]}


def _get_collection(db, role: str):
    return db.admins if role == "admin" else db.users


async def _find_user_any_col(db, oid):
    user = await db.users.find_one({"_id": oid})
    if user:
        return user, "users"
    admin = await db.admins.find_one({"_id": oid})
    if admin:
        return admin, "admins"
    return None, None


@router.get("/users/{user_id}")
async def get_user(user_id: str, admin=Depends(get_current_admin)):
    db = get_db()
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(400, "Geçersiz kullanıcı ID")
    user, _ = await _find_user_any_col(db, oid)
    if not user:
        raise HTTPException(404, "Kullanıcı bulunamadı")
    return _serialize_user(user)


@router.patch("/users/{user_id}")
async def update_user(user_id: str, data: dict, admin=Depends(get_current_admin)):
    db = get_db()
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(400, "Geçersiz kullanıcı ID")

    user, col_name = await _find_user_any_col(db, oid)
    if not user:
        raise HTTPException(404, "Kullanıcı bulunamadı")

    if "role" in data and data["role"] not in {"user", "admin"}:
        raise HTTPException(400, "Geçersiz rol. 'user' veya 'admin' olmalı")
    allowed = {"full_name", "phone", "is_active", "language", "role"}
    update  = {k: v for k, v in data.items() if k in allowed}
    if not update:
        raise HTTPException(400, "Güncellenecek geçerli alan yok")

    update["updated_at"] = datetime.utcnow()
    collection = db.admins if col_name == "admins" else db.users
    result = await collection.find_one_and_update(
        {"_id": oid},
        {"$set": update},
        return_document=True,
    )
    if not result:
        raise HTTPException(404, "Kullanıcı bulunamadı")
    return _serialize_user(result)


@router.delete("/users/{user_id}")
async def delete_user(user_id: str, admin=Depends(get_current_admin)):
    db = get_db()
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(400, "Geçersiz kullanıcı ID")

    user, col_name = await _find_user_any_col(db, oid)
    if not user:
        raise HTTPException(404, "Kullanıcı bulunamadı")

    collection = db.admins if col_name == "admins" else db.users
    await collection.delete_one({"_id": oid})
    return {"message": "Kullanıcı silindi"}


# ─── SİPARİŞ YARDIMCILARI ────────────────────────────────────────────────────

def _serialize_order(o: dict) -> dict:
    o["id"]      = str(o["_id"])
    o["user_id"] = str(o["user_id"])
    del o["_id"]
    for item in o.get("items", []):
        if "product_id" in item:
            item["product_id"] = str(item["product_id"])
    if isinstance(o.get("created_at"), datetime):
        o["created_at"] = o["created_at"].isoformat()
    if isinstance(o.get("updated_at"), datetime):
        o["updated_at"] = o["updated_at"].isoformat()
    return o


async def _get_user_info(db, user_id_str: str):
    try:
        oid = ObjectId(user_id_str)
    except Exception:
        return None
    user = await db.users.find_one({"_id": oid}, {"username": 1, "email": 1, "full_name": 1})
    if not user:
        user = await db.admins.find_one({"_id": oid}, {"username": 1, "email": 1, "full_name": 1})
    if user:
        return {"username": user.get("username", ""), "email": user.get("email", ""), "full_name": user.get("full_name", "")}
    return None


# ─── SİPARİŞLER ───────────────────────────────────────────────────────────────

@router.get("/orders")
async def list_orders(
    status:  Optional[str] = None,
    user_id: Optional[str] = None,
    page:    int = Query(1, ge=1),
    limit:   int = Query(20, ge=1, le=100),
    admin=Depends(get_current_admin),
):
    db = get_db()
    query: dict = {}
    if status:
        query["status"] = status
    if user_id:
        try:
            query["user_id"] = ObjectId(user_id)
        except Exception:
            pass

    skip   = (page - 1) * limit
    cursor = db.orders.find(query).sort("created_at", -1).skip(skip).limit(limit)
    raw    = await cursor.to_list(length=limit)
    total  = await db.orders.count_documents(query)

    orders = [_serialize_order(o) for o in raw]

    # Kullanıcı bilgilerini toplu getir
    uid_set  = {o["user_id"] for o in orders}
    user_map = {}
    for uid in uid_set:
        info = await _get_user_info(db, uid)
        if info:
            user_map[uid] = info
    for o in orders:
        o["user"] = user_map.get(o["user_id"])

    return {"total": total, "page": page, "orders": orders}


@router.get("/orders/{order_id}")
async def get_order(order_id: str, admin=Depends(get_current_admin)):
    db = get_db()
    try:
        oid = ObjectId(order_id)
    except Exception:
        raise HTTPException(400, "Geçersiz sipariş ID")
    order = await db.orders.find_one({"_id": oid})
    if not order:
        raise HTTPException(404, "Sipariş bulunamadı")
    order = _serialize_order(order)
    order["user"] = await _get_user_info(db, order["user_id"])
    return order


@router.patch("/orders/{order_id}/status")
async def update_order_status(order_id: str, data: dict, admin=Depends(get_current_admin)):
    db = get_db()
    allowed_statuses = {"pending", "paid", "shipped", "delivered", "cancelled"}
    new_status = data.get("status")
    if new_status not in allowed_statuses:
        raise HTTPException(400, f"Geçersiz durum. İzin verilenler: {allowed_statuses}")
    try:
        oid = ObjectId(order_id)
    except Exception:
        raise HTTPException(400, "Geçersiz sipariş ID")
    result = await db.orders.find_one_and_update(
        {"_id": oid},
        {"$set": {"status": new_status, "updated_at": datetime.utcnow()}},
        return_document=True,
    )
    if not result:
        raise HTTPException(404, "Sipariş bulunamadı")
    return _serialize_order(result)


# ─── ÜRÜNLER ──────────────────────────────────────────────────────────────────

@router.get("/products")
async def list_admin_products(
    category:         Optional[str]  = None,
    search:           Optional[str]  = None,
    page:             int  = Query(1, ge=1),
    limit:            int  = Query(20, ge=1, le=100),
    include_inactive: bool = Query(False),
    low_stock_only:   bool = Query(False),
    admin=Depends(get_current_admin),
):
    db = get_db()
    query: dict = {} if include_inactive else {"is_active": True}
    if category:
        query["category"] = category
    if search:
        query["$or"] = [
            {"name.tr":        {"$regex": search, "$options": "i"}},
            {"name.en":        {"$regex": search, "$options": "i"}},
            {"description.tr": {"$regex": search, "$options": "i"}},
        ]
    if low_stock_only:
        query["stock"] = {"$lte": 5}

    skip     = (page - 1) * limit
    cursor   = db.products.find(query).sort("created_at", -1).skip(skip).limit(limit)
    products = await cursor.to_list(length=limit)
    total    = await db.products.count_documents(query)

    for p in products:
        p["id"] = str(p["_id"])
        del p["_id"]

    return {"total": total, "page": page, "products": products}


# ─── YENİ KULLANICI / ADMIN OLUŞTUR ──────────────────────────────────────────

@router.post("/users")
async def create_user(data: dict, admin=Depends(get_current_admin)):
    db = get_db()

    required = {"email", "username", "password", "full_name"}
    if not required.issubset(data.keys()):
        raise HTTPException(400, f"Zorunlu alanlar eksik: {required}")

    role = data.get("role", "user")
    if role not in {"user", "admin"}:
        raise HTTPException(400, "Geçersiz rol")

    collection = db.admins if role == "admin" else db.users

    if await collection.find_one({"email": data["email"]}):
        raise HTTPException(400, "Bu email zaten kayıtlı")
    if await collection.find_one({"username": data["username"]}):
        raise HTTPException(400, "Bu kullanıcı adı alınmış")

    new_user = {
        "email":         data["email"],
        "username":      data["username"],
        "password_hash": hash_password(data["password"]),
        "full_name":     data["full_name"],
        "phone":         data.get("phone"),
        "role":          role,
        "language":      data.get("language", "tr"),
        "address":       None,
        "is_active":     True,
        "created_at":    datetime.utcnow(),
        "updated_at":    datetime.utcnow(),
    }
    result = await collection.insert_one(new_user)
    new_user["_id"] = result.inserted_id
    return _serialize_user(new_user)


# ─── BAĞLI ARABALAR ───────────────────────────────────────────────────────────

@router.get("/cars/connected")
async def connected_cars(admin=Depends(get_current_admin)):
    return manager.get_status()