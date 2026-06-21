from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import os
from app.core.config import settings
from app.core.database import connect_db, close_db
from app.middleware.ddos import DDoSProtectionMiddleware
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.products import router as products_router
from app.api.v1.endpoints.cart_orders import cart_router, order_router
from app.api.v1.endpoints.websocket import router as ws_router
from app.api.v1.endpoints.logs import router as logs_router
from app.api.v1.endpoints.admin import router as admin_router
#bu dosya app.py, uygulamanın giriş noktasıdır. FastAPI uygulamasını oluşturur, yapılandırır ve tüm rotaları ekler.
# Ayrıca, veritabanı bağlantısı ve diğer kaynakların yönetimi için bir yaşam döngüsü sağlar.
@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    yield
    await close_db()

app = FastAPI(
    title="SmartCar API",
    description="Akıllı RC Araba — Backend API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.ENVIRONMENT == "development" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT == "development" else None,
)

# ─── UPLOADS KLASÖRÜ ──────────────────────────────────────────────────────────
os.makedirs(settings.uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.uploads_dir), name="uploads")

# ─── MIDDLEWARE ────────────────────────────────────────────────────────────────
# CORS en önce eklenmeli (LIFO sırası nedeniyle ilk çalışan olur)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# DDoS koruması CORS'tan sonra eklenir
app.add_middleware(DDoSProtectionMiddleware, rate_limit=settings.RATE_LIMIT_PER_MINUTE)

# ─── ROUTERS ──────────────────────────────────────────────────────────────────
API_PREFIX = "/api/v1"
app.include_router(auth_router,     prefix=API_PREFIX)
app.include_router(products_router, prefix=API_PREFIX)
app.include_router(cart_router,     prefix=API_PREFIX)
app.include_router(order_router,    prefix=API_PREFIX)
app.include_router(logs_router,     prefix=API_PREFIX)
app.include_router(admin_router,    prefix=API_PREFIX)
app.include_router(ws_router,       prefix=API_PREFIX)

# ─── HEALTH CHECK ─────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0.0"}

@app.get("/")
async def root():
    return {"message": "SmartCar API çalışıyor "}