from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
from collections import defaultdict
from datetime import datetime, timedelta
import time
import asyncio


# In-memory rate limit store (production'da Redis kullan)
class RateLimitStore:
    def __init__(self):
        self.requests: dict = defaultdict(list)
        self.blocked_ips: dict = {}
        self.ws_requests: dict = defaultdict(list)

    def is_blocked(self, ip: str) -> bool:
        if ip in self.blocked_ips:
            if datetime.utcnow() < self.blocked_ips[ip]:
                return True
            else:
                del self.blocked_ips[ip]
        return False

    def block_ip(self, ip: str, minutes: int = 30):
        self.blocked_ips[ip] = datetime.utcnow() + timedelta(minutes=minutes)

    def check_rate_limit(self, ip: str, limit: int, window: int = 60) -> bool:
        """True = geçti, False = engellendi"""
        now = time.time()
        window_start = now - window
        self.requests[ip] = [t for t in self.requests[ip] if t > window_start]
        self.requests[ip].append(now)

        if len(self.requests[ip]) > limit:
            # Sürekli aşıyorsa IP'yi engelle
            if len(self.requests[ip]) > limit * 3:
                self.block_ip(ip, minutes=60)
            return False
        return True

    def cleanup(self):
        now = time.time()
        window_start = now - 60
        for ip in list(self.requests.keys()):
            self.requests[ip] = [t for t in self.requests[ip] if t > window_start]
            if not self.requests[ip]:
                del self.requests[ip]


rate_store = RateLimitStore()


class DDoSProtectionMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, rate_limit: int = 60):
        super().__init__(app)
        self.rate_limit = rate_limit

    async def dispatch(self, request: Request, call_next):
        # CORS preflight isteklerini doğrudan geç
        if request.method == "OPTIONS":
            return await call_next(request)

        ip = request.client.host if request.client else "unknown"

        # IP engel kontrolü
        if rate_store.is_blocked(ip):
            return JSONResponse(
                status_code=429,
                content={"detail": "IP geçici olarak engellendi. Lütfen bekleyin."}
            )

        # WebSocket endpoint'leri için farklı limit
        if request.url.path.startswith("/ws") or "/ws/" in request.url.path:
            allowed = rate_store.check_rate_limit(f"ws_{ip}", limit=120, window=60)
        else:
            allowed = rate_store.check_rate_limit(ip, limit=self.rate_limit, window=60)

        if not allowed:
            return JSONResponse(
                status_code=429,
                content={"detail": "Çok fazla istek. Lütfen bekleyin."}
            )

        # Şüpheli header kontrolü
        user_agent = request.headers.get("user-agent", "")
        if not user_agent or len(user_agent) < 5:
            return JSONResponse(
                status_code=400,
                content={"detail": "Geçersiz istek"}
            )

        response = await call_next(request)
        return response


# WebSocket bağlantı yöneticisi için rate limit yardımcısı
def check_ws_rate_limit(ip: str, limit: int = 120) -> bool:
    return rate_store.check_rate_limit(f"ws_cmd_{ip}", limit=limit, window=60)