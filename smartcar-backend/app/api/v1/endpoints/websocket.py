from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, HTTPException
from fastapi import status as http_status
from datetime import datetime
import json
import time

from app.services.ws_manager import manager, validate_command, VALID_COMMANDS
from app.core.database import get_db
from app.core.security import decode_token
from app.middleware.ddos import check_ws_rate_limit

router = APIRouter(tags=["WebSocket"])


async def authenticate_ws(token: str) -> dict | None:
    """WebSocket token doğrulama"""
    try:
        payload = decode_token(token)
        user_id = payload.get("sub")
        if not user_id:
            return None
        from bson import ObjectId
        db = get_db()
        user = await db.users.find_one({"_id": ObjectId(user_id)})
        return user
    except Exception:
        return None


@router.websocket("/ws/control/{car_id}")
async def controller_ws(
    websocket: WebSocket,
    car_id: str,
    token: str = Query(...),
):
    """
    Joystick / mobil uygulama bağlantısı.
    Komutları arabaya iletir ve DB'ye loglar.
    """
    ip = websocket.client.host if websocket.client else "unknown"

    # Rate limit kontrolü
    if not check_ws_rate_limit(ip, limit=30):
        await websocket.close(code=1008)
        return

    # Kimlik doğrulama
    user = await authenticate_ws(token)
    if not user:
        await websocket.close(code=1008)
        return

    await manager.connect_controller(car_id, websocket)
    session_id = f"{str(user['_id'])}_{car_id}_{int(time.time())}"
    db = get_db()

    # İlk mesaj: bağlantı durumu
    car_connected = manager.is_car_connected(car_id)
    await websocket.send_text(json.dumps({
        "type": "connected",
        "car_connected": car_connected,
        "session_id": session_id,
    }))

    try:
        while True:
            raw = await websocket.receive_text()

            # Komut rate limit
            if not check_ws_rate_limit(f"cmd_{ip}", limit=120):
                await websocket.send_text(json.dumps({
                    "type": "error",
                    "message": "Çok hızlı komut gönderiyorsunuz"
                }))
                continue

            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_text(json.dumps({"type": "error", "message": "Geçersiz JSON"}))
                continue

            # Komut doğrulama
            valid, err = validate_command(data)
            if not valid:
                await websocket.send_text(json.dumps({"type": "error", "message": err}))
                continue

            # Arabaya gönder
            send_start = time.time()
            command_payload = {
                "type": "command",
                "command": data["command"],
                "x": data.get("x", 0.0),
                "y": data.get("y", 0.0),
                "speed": data.get("speed", 128),
            }
            sent = await manager.send_command_to_car(car_id, command_payload)
            latency_ms = int((time.time() - send_start) * 1000)

            # DB'ye log
            log_ts = datetime.utcnow()
            await db.command_logs.insert_one({
                "user_id": user["_id"],
                "session_id": session_id,
                "car_id": car_id,
                "command": data["command"],
                "x_axis": data.get("x", 0.0),
                "y_axis": data.get("y", 0.0),
                "speed": data.get("speed", 128),
                "ip_address": ip,
                "timestamp": log_ts,
                "latency_ms": latency_ms,
                "car_reached": sent,
            })

            # Admin gözlemcilere canlı yayın
            await manager.broadcast_to_admins({
                "type": "live_command",
                "user_id": str(user["_id"]),
                "username": user.get("username", "?"),
                "car_id": car_id,
                "command": data["command"],
                "x_axis": data.get("x", 0.0),
                "y_axis": data.get("y", 0.0),
                "speed": data.get("speed", 128),
                "latency_ms": latency_ms,
                "car_reached": sent,
                "timestamp": log_ts.isoformat(),
            })

            await websocket.send_text(json.dumps({
                "type": "ack",
                "command": data["command"],
                "car_reached": sent,
                "latency_ms": latency_ms,
            }))

    except WebSocketDisconnect:
        await manager.disconnect_controller(car_id, websocket)


@router.websocket("/ws/car/{car_id}")
async def car_ws(
    websocket: WebSocket,
    car_id: str,
    token: str = Query(...),
):
    """
    ESP32 / araba tarafı bağlantısı.
    Komutları dinler ve uygular.
    Cihaz secret'ı veya admin JWT token ile kimlik doğrulama.
    """
    from app.core.config import settings

    ip = websocket.client.host if websocket.client else "unknown"

    # Cihaz secret'ı veya admin JWT ile kimlik doğrulama
    if token == settings.CAR_DEVICE_SECRET:
        pass  # ESP32 cihaz token'ı geçerli
    else:
        user = await authenticate_ws(token)
        if not user or user.get("role") != "admin":
            await websocket.close(code=1008)
            return

    await manager.connect_car(car_id, websocket)

    # Controller'lara arabanın bağlandığını bildir
    await manager.broadcast_to_controllers(car_id, {
        "type": "car_connected",
        "car_id": car_id,
    })

    try:
        while True:
            # Arabadan durum mesajı bekle (batarya, sensör vb.)
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)

                # car_ready mesajını yoksay
                if data.get("type") == "car_ready":
                    continue

                # Arabadan gelen log mesajlarını admin paneline ilet
                if data.get("type") == "log":
                    await manager.broadcast_to_admins({
                        "type": "car_log",
                        "car_id": car_id,
                        "command": data.get("command", ""),
                        "speed": data.get("speed", 0),
                        "uptime": data.get("uptime", 0),
                        "timestamp": datetime.utcnow().isoformat(),
                    })

                # Controller'lara da ilet
                await manager.broadcast_to_controllers(car_id, {
                    "type": "car_status",
                    **data
                })
            except Exception:
                pass

    except WebSocketDisconnect:
        await manager.disconnect_car(car_id)


@router.websocket("/ws/admin/live")
async def admin_live_ws(
    websocket: WebSocket,
    token: str = Query(...),
):
    """
    Admin paneli canlı komut akışı.
    Joystick'ten gelen her komut anlık olarak iletilir.
    """
    user = await authenticate_ws(token)
    if not user or user.get("role") != "admin":
        await websocket.close(code=1008)
        return

    await manager.connect_admin_observer(websocket)

    # Son 20 komutu DB'den çekip gönder
    db = get_db()
    recent = await db.command_logs.find({}).sort("timestamp", -1).limit(20).to_list(length=20)
    recent.reverse()  # eskiden yeniye sırala
    for log in recent:
        await websocket.send_text(json.dumps({
            "type": "live_command",
            "user_id":   str(log.get("user_id", "")),
            "username":  log.get("username", "?"),
            "car_id":    log.get("car_id", ""),
            "command":   log.get("command", ""),
            "x_axis":    log.get("x_axis", 0.0),
            "y_axis":    log.get("y_axis", 0.0),
            "speed":     log.get("speed", 0),
            "latency_ms": log.get("latency_ms"),
            "car_reached": log.get("car_reached", False),
            "timestamp": log["timestamp"].isoformat() if log.get("timestamp") else None,
            "historic":  True,
        }, default=str))

    await websocket.send_text(json.dumps({
        "type": "connected",
        "message": "Canlı komut akışına bağlandınız",
    }))

    try:
        while True:
            # Admin'den ping bekliyoruz (bağlantıyı canlı tutar)
            await websocket.receive_text()
    except WebSocketDisconnect:
        await manager.disconnect_admin_observer(websocket)


@router.get("/ws/status")
async def ws_status():
    """Bağlı araba ve controller sayısı"""
    return manager.get_status()