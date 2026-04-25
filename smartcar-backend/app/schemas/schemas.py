from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime


# ─── AUTH ──────────────────────────────────────────────
class RegisterRequest(BaseModel):
    email: EmailStr
    username: str = Field(min_length=3, max_length=30)
    password: str = Field(min_length=8)
    full_name: str
    phone: Optional[str] = None
    language: str = "tr"


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


# ─── USER ──────────────────────────────────────────────
class AddressSchema(BaseModel):
    street: str
    city: str
    country: str
    zip: str


class UserResponse(BaseModel):
    id: str
    email: str
    username: str
    full_name: str
    phone: Optional[str]
    role: str
    language: str
    address: Optional[AddressSchema]
    created_at: datetime


class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    language: Optional[str] = None
    address: Optional[AddressSchema] = None


# ─── PRODUCT ───────────────────────────────────────────
class LocalizedText(BaseModel):
    tr: str
    en: str


class ProductCreate(BaseModel):
    name: LocalizedText
    description: LocalizedText
    price: float = Field(gt=0)
    currency: str = "TRY"
    stock: int = Field(ge=0)
    images: List[str] = []
    category: str
    tags: List[str] = []


class ProductResponse(BaseModel):
    id: str
    name: LocalizedText
    description: LocalizedText
    price: float
    currency: str
    stock: int
    images: List[str]
    category: str
    tags: List[str]
    is_active: bool
    created_at: datetime


class ProductUpdate(BaseModel):
    name: Optional[LocalizedText] = None
    description: Optional[LocalizedText] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    images: Optional[List[str]] = None
    category: Optional[str] = None
    tags: Optional[List[str]] = None
    is_active: Optional[bool] = None


# ─── CART ──────────────────────────────────────────────
class CartItem(BaseModel):
    product_id: str
    quantity: int = Field(ge=1)


class CartResponse(BaseModel):
    items: List[dict]
    total: float


# ─── ORDER ─────────────────────────────────────────────
class OrderCreate(BaseModel):
    shipping_address: AddressSchema
    payment_method: str = "credit_card"


class OrderResponse(BaseModel):
    id: str
    items: List[dict]
    total: float
    status: str
    shipping_address: AddressSchema
    created_at: datetime


# ─── COMMAND LOG ───────────────────────────────────────
class CommandLog(BaseModel):
    command: str
    x_axis: float = 0.0
    y_axis: float = 0.0
    speed: int = 0
    session_id: str
    latency_ms: Optional[int] = None


class CommandLogResponse(BaseModel):
    id: str
    user_id: str
    command: str
    x_axis: float
    y_axis: float
    speed: int
    timestamp: datetime
    latency_ms: Optional[int]


# ─── WEBSOCKET ─────────────────────────────────────────
class WSCommand(BaseModel):
    command: str      # forward | backward | left | right | stop
    x: float = 0.0   # -1.0 ile 1.0 arası
    y: float = 0.0
    speed: int = 128  # 0-255