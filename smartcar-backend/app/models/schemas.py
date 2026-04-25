"""
MongoDB koleksiyon şemaları — referans amaçlıdır.
Motor ile doğrudan dict kullanıyoruz ama burada yapıyı netleştiriyoruz.

Collections:
  - users   (role = "user")
  - admins  (role = "admin")
  - products
  - orders
  - cart
  - command_logs
  - sessions (WebSocket)
"""

# users — sadece normal kullanıcılar (role="user")
USER_SCHEMA = {
    "_id": "ObjectId",
    "email": "str",
    "username": "str",
    "password_hash": "str",
    "role": "str",           # her zaman "user"
    "full_name": "str",
    "phone": "str",
    "address": {
        "street": "str",
        "city": "str",
        "country": "str",
        "zip": "str"
    },
    "created_at": "datetime",
    "updated_at": "datetime",
    "is_active": "bool",
    "language": "str",       # "tr" | "en"
}

# products
PRODUCT_SCHEMA = {
    "_id": "ObjectId",
    "name": {"tr": "str", "en": "str"},
    "description": {"tr": "str", "en": "str"},
    "price": "float",
    "currency": "str",       # "TRY" | "USD"
    "stock": "int",
    "images": ["str"],       # URL listesi
    "category": "str",
    "tags": ["str"],
    "is_active": "bool",
    "created_at": "datetime",
    "updated_at": "datetime",
}

# orders
ORDER_SCHEMA = {
    "_id": "ObjectId",
    "user_id": "ObjectId",
    "items": [
        {
            "product_id": "ObjectId",
            "name": "str",
            "price": "float",
            "quantity": "int",
        }
    ],
    "total": "float",
    "status": "str",         # "pending" | "paid" | "shipped" | "delivered" | "cancelled"
    "payment_method": "str",
    "payment_id": "str",
    "shipping_address": "dict",
    "created_at": "datetime",
    "updated_at": "datetime",
}

# cart
CART_SCHEMA = {
    "_id": "ObjectId",
    "user_id": "ObjectId",
    "items": [
        {
            "product_id": "ObjectId",
            "quantity": "int",
        }
    ],
    "updated_at": "datetime",
}

# command_logs — joystick verileri
COMMAND_LOG_SCHEMA = {
    "_id": "ObjectId",
    "user_id": "ObjectId",
    "session_id": "str",
    "command": "str",        # "forward" | "backward" | "left" | "right" | "stop"
    "x_axis": "float",       # joystick x pozisyonu (-1.0 ile 1.0)
    "y_axis": "float",       # joystick y pozisyonu (-1.0 ile 1.0)
    "speed": "int",          # 0-255
    "ip_address": "str",
    "timestamp": "datetime",
    "latency_ms": "int",     # komut gecikmesi
}