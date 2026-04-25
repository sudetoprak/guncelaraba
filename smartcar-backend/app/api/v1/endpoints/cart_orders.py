from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
from bson import ObjectId
from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.schemas import CartItem, CartResponse, OrderCreate, OrderResponse

cart_router = APIRouter(prefix="/cart", tags=["Cart"])
order_router = APIRouter(prefix="/orders", tags=["Orders"])


# ─── CART ─────────────────────────────────────────────────────────────────────

@cart_router.get("/", response_model=CartResponse)
async def get_cart(current_user=Depends(get_current_user)):
    db = get_db()
    user_id = current_user["_id"]
    cart = await db.cart.find_one({"user_id": user_id})
    if not cart or not cart.get("items"):
        return CartResponse(items=[], total=0.0)

    enriched = []
    total = 0.0
    for item in cart["items"]:
        product = await db.products.find_one({"_id": item["product_id"]})
        if product:
            subtotal = product["price"] * item["quantity"]
            total += subtotal
            enriched.append({
                "product_id": str(item["product_id"]),
                "name": product["name"],
                "price": product["price"],
                "quantity": item["quantity"],
                "subtotal": subtotal,
                "image": product["images"][0] if product.get("images") else None,
            })
    return CartResponse(items=enriched, total=total)


@cart_router.post("/add")
async def add_to_cart(item: CartItem, current_user=Depends(get_current_user)):
    db = get_db()
    user_id = current_user["_id"]

    try:
        product_oid = ObjectId(item.product_id)
    except Exception:
        raise HTTPException(400, "Geçersiz ürün ID")

    product = await db.products.find_one({"_id": product_oid, "is_active": True})
    if not product:
        raise HTTPException(404, "Ürün bulunamadı")
    if product["stock"] < item.quantity:
        raise HTTPException(400, "Yeterli stok yok")

    cart = await db.cart.find_one({"user_id": user_id})
    if cart:
        # Ürün zaten sepette mi?
        existing = next((i for i in cart["items"] if i["product_id"] == product_oid), None)
        if existing:
            await db.cart.update_one(
                {"user_id": user_id, "items.product_id": product_oid},
                {"$inc": {"items.$.quantity": item.quantity}, "$set": {"updated_at": datetime.utcnow()}}
            )
        else:
            await db.cart.update_one(
                {"user_id": user_id},
                {"$push": {"items": {"product_id": product_oid, "quantity": item.quantity}},
                 "$set": {"updated_at": datetime.utcnow()}}
            )
    else:
        await db.cart.insert_one({
            "user_id": user_id,
            "items": [{"product_id": product_oid, "quantity": item.quantity}],
            "updated_at": datetime.utcnow()
        })
    return {"message": "Sepete eklendi"}


@cart_router.delete("/remove/{product_id}")
async def remove_from_cart(product_id: str, current_user=Depends(get_current_user)):
    db = get_db()
    user_id = current_user["_id"]
    try:
        product_oid = ObjectId(product_id)
    except Exception:
        raise HTTPException(400, "Geçersiz ürün ID")

    await db.cart.update_one(
        {"user_id": user_id},
        {"$pull": {"items": {"product_id": product_oid}}}
    )
    return {"message": "Üründen kaldırıldı"}


@cart_router.delete("/clear")
async def clear_cart(current_user=Depends(get_current_user)):
    db = get_db()
    await db.cart.update_one(
        {"user_id": current_user["_id"]},
        {"$set": {"items": [], "updated_at": datetime.utcnow()}}
    )
    return {"message": "Sepet temizlendi"}


# ─── ORDERS ───────────────────────────────────────────────────────────────────

@order_router.post("/", response_model=OrderResponse)
async def create_order(data: OrderCreate, current_user=Depends(get_current_user)):
    db = get_db()
    user_id = current_user["_id"]

    cart = await db.cart.find_one({"user_id": user_id})
    if not cart or not cart.get("items"):
        raise HTTPException(400, "Sepet boş")

    items = []
    total = 0.0
    for cart_item in cart["items"]:
        product = await db.products.find_one({"_id": cart_item["product_id"]})
        if not product or product["stock"] < cart_item["quantity"]:
            raise HTTPException(400, f"Stok sorunu: {cart_item['product_id']}")
        subtotal = product["price"] * cart_item["quantity"]
        total += subtotal
        items.append({
            "product_id": cart_item["product_id"],
            "name": product["name"],
            "price": product["price"],
            "quantity": cart_item["quantity"],
            "subtotal": subtotal,
        })
        # Stok düş
        await db.products.update_one(
            {"_id": cart_item["product_id"]},
            {"$inc": {"stock": -cart_item["quantity"]}}
        )

    order = {
        "user_id": user_id,
        "items": items,
        "total": total,
        "status": "pending",
        "payment_method": data.payment_method,
        "payment_id": None,
        "shipping_address": data.shipping_address.model_dump(),
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    result = await db.orders.insert_one(order)
    order["id"] = str(result.inserted_id)

    # Sepeti temizle
    await db.cart.update_one({"user_id": user_id}, {"$set": {"items": []}})

    return OrderResponse(
        id=order["id"],
        items=[{**i, "product_id": str(i["product_id"])} for i in items],
        total=total,
        status="pending",
        shipping_address=data.shipping_address,
        created_at=order["created_at"],
    )


@order_router.get("/", response_model=list)
async def list_orders(current_user=Depends(get_current_user)):
    db = get_db()
    cursor = db.orders.find({"user_id": current_user["_id"]}).sort("created_at", -1)
    orders = await cursor.to_list(length=50)
    for o in orders:
        o["id"] = str(o["_id"])
        del o["_id"]
        o["user_id"] = str(o["user_id"])
        for item in o.get("items", []):
            item["product_id"] = str(item["product_id"])
    return orders