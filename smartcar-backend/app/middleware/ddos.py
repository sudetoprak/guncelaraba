from collections import defaultdict
from datetime import datetime, timedelta
import time

from fastapi import Request
from redis.asyncio import Redis
from redis.exceptions import RedisError
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.core.config import settings


class MemoryRateLimitStore:
    def __init__(self):
        self.requests: dict = defaultdict(list)
        self.blocked_ips: dict = {}

    async def is_blocked(self, ip: str) -> bool:
        if ip in self.blocked_ips:
            if datetime.utcnow() < self.blocked_ips[ip]:
                return True
            del self.blocked_ips[ip]
        return False

    async def block_ip(self, ip: str, minutes: int):
        self.blocked_ips[ip] = datetime.utcnow() + timedelta(minutes=minutes)

    async def check_rate_limit(self, key: str, limit: int, window: int = 60) -> tuple[bool, int]:
        now = time.time()
        window_start = now - window
        self.requests[key] = [t for t in self.requests[key] if t > window_start]
        self.requests[key].append(now)
        remaining = max(limit - len(self.requests[key]), 0)
        return len(self.requests[key]) <= limit, remaining


class RedisRateLimitStore:
    def __init__(self, redis_url: str):
        self.redis = Redis.from_url(redis_url, decode_responses=True)

    async def is_blocked(self, ip: str) -> bool:
        return await self.redis.exists(f"rl:block:{ip}") == 1

    async def block_ip(self, ip: str, minutes: int):
        await self.redis.setex(f"rl:block:{ip}", minutes * 60, "1")

    async def check_rate_limit(self, key: str, limit: int, window: int = 60) -> tuple[bool, int]:
        redis_key = f"rl:req:{key}"
        count = await self.redis.incr(redis_key)
        if count == 1:
            await self.redis.expire(redis_key, window)
        remaining = max(limit - count, 0)
        return count <= limit, remaining


memory_store = MemoryRateLimitStore()
redis_store: RedisRateLimitStore | None = None


def get_rate_store():
    global redis_store
    if redis_store is not None:
        return redis_store
    if settings.REDIS_URL:
        redis_store = RedisRateLimitStore(settings.REDIS_URL)
        return redis_store
    return memory_store


def client_ip(request: Request) -> str:
    if settings.TRUST_PROXY_HEADERS:
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        real_ip = request.headers.get("x-real-ip")
        if real_ip:
            return real_ip.strip()
    return request.client.host if request.client else "unknown"


def limit_for_path(path: str, default_limit: int) -> int:
    if path.startswith("/api/v1/auth/login") or path.startswith("/api/v1/auth/register"):
        return settings.AUTH_RATE_LIMIT_PER_MINUTE
    if path.startswith("/api/v1/logs/command/public"):
        return settings.WS_RATE_LIMIT_PER_MINUTE
    if path.startswith("/api/v1/ws") or "/ws/" in path:
        return settings.WS_RATE_LIMIT_PER_MINUTE
    return default_limit


class DDoSProtectionMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, rate_limit: int = 60):
        super().__init__(app)
        self.rate_limit = rate_limit

    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS":
            return await call_next(request)

        ip = client_ip(request)
        path = request.url.path
        limit = limit_for_path(path, self.rate_limit)
        store = get_rate_store()

        try:
            if await store.is_blocked(ip):
                return JSONResponse(
                    status_code=429,
                    content={"detail": "IP gecici olarak engellendi. Lutfen bekleyin."},
                    headers={"Retry-After": str(settings.RATE_LIMIT_BLOCK_MINUTES * 60)},
                )

            allowed, remaining = await store.check_rate_limit(f"{ip}:{path}", limit=limit, window=60)
            if not allowed:
                if remaining == 0:
                    await store.block_ip(ip, minutes=settings.RATE_LIMIT_BLOCK_MINUTES)
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Cok fazla istek. Lutfen bekleyin."},
                    headers={"Retry-After": "60", "X-RateLimit-Remaining": "0"},
                )
        except RedisError:
            allowed, remaining = await memory_store.check_rate_limit(f"{ip}:{path}", limit=limit, window=60)
            if not allowed:
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Cok fazla istek. Lutfen bekleyin."},
                    headers={"Retry-After": "60", "X-RateLimit-Remaining": "0"},
                )

        user_agent = request.headers.get("user-agent", "")
        if not user_agent or len(user_agent) < 5:
            return JSONResponse(status_code=400, content={"detail": "Gecersiz istek"})

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response


async def check_ws_rate_limit(ip: str, limit: int = 120) -> bool:
    store = get_rate_store()
    try:
        allowed, _ = await store.check_rate_limit(f"ws_cmd:{ip}", limit=limit, window=60)
        return allowed
    except RedisError:
        allowed, _ = await memory_store.check_rate_limit(f"ws_cmd:{ip}", limit=limit, window=60)
        return allowed
