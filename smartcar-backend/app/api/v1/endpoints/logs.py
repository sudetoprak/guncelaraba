from fastapi import APIRouter, Depends, Query
from datetime import datetime, timedelta
from app.core.database import get_db
from app.core.security import get_current_admin, get_current_user
from app.services.ws_manager import manager

router = APIRouter(prefix="/logs", tags=["Logs"])


@router.post("/command")
async def log_command_direct(data: dict, user=Depends(get_current_user)):
    """
    Flutter → ESP32 direkt modunda her komut buraya POST edilir.
    DB'ye kaydeder ve admin WebSocket gözlemcilerine yayınlar.
    """
    db = get_db()
    log_ts = datetime.utcnow()
    
    latency_ms = data.get("latency_ms", 0)
    car_reached = data.get("car_reached", True)

    await db.command_logs.insert_one({
        "user_id":    user["_id"],
        "car_id":     data.get("car_id", "car1"),
        "command":    data.get("command", "stop"),
        "x_axis":     data.get("x", 0.0),
        "y_axis":     data.get("y", 0.0),
        "speed":      data.get("speed", 128),
        "ip_address": "direct",
        "timestamp":  log_ts,
        "latency_ms": latency_ms,
        "car_reached": car_reached,
        "source":     "esp32_direct",
    })

    await manager.broadcast_to_admins({
        "type":       "live_command",
        "user_id":    str(user["_id"]),
        "username":   user.get("username", "?"),
        "car_id":     data.get("car_id", "car1"),
        "command":    data.get("command", "stop"),
        "x_axis":     data.get("x", 0.0),
        "y_axis":     data.get("y", 0.0),
        "speed":      data.get("speed", 128),
        "latency_ms": latency_ms,
        "car_reached": car_reached,
        "timestamp":  log_ts.isoformat(),
        "source":     "esp32_direct",
    })

    return {"status": "logged", "timestamp": log_ts.isoformat()}


@router.get("/commands")
async def get_command_logs(
    car_id:  str = None,
    user_id: str = None,
    command: str = None,
    hours:   int = Query(24, ge=1, le=168),
    page:    int = Query(1, ge=1),
    limit:   int = Query(50, ge=1, le=200),
    admin=Depends(get_current_admin)
):
    db = get_db()
    since = datetime.utcnow() - timedelta(hours=hours)
    query = {"timestamp": {"$gte": since}}

    if car_id:
        query["car_id"] = car_id
    if command:
        query["command"] = command
    if user_id:
        from bson import ObjectId
        try:
            query["user_id"] = ObjectId(user_id)
        except Exception:
            pass

    skip   = (page - 1) * limit
    cursor = db.command_logs.find(query).sort("timestamp", -1).skip(skip).limit(limit)
    logs   = await cursor.to_list(length=limit)
    total  = await db.command_logs.count_documents(query)

    for log in logs:
        log["id"]      = str(log["_id"])
        log["user_id"] = str(log["user_id"])
        del log["_id"]

    return {"total": total, "page": page, "logs": logs}


@router.get("/stats")
async def get_stats(admin=Depends(get_current_admin)):
    db  = get_db()
    now = datetime.utcnow()
    today = now - timedelta(hours=24)

    total_commands  = await db.command_logs.count_documents({})
    today_commands  = await db.command_logs.count_documents({"timestamp": {"$gte": today}})
    total_users     = await db.users.count_documents({})
    total_orders    = await db.orders.count_documents({})
    pending_orders  = await db.orders.count_documents({"status": "pending"})

    pipeline = [
        {"$match": {"timestamp": {"$gte": today}}},
        {"$group": {"_id": "$command", "count": {"$sum": 1}}},
    ]
    cmd_dist = await db.command_logs.aggregate(pipeline).to_list(length=10)

    ws_status = manager.get_status()   # ← bug fix: len(list({})) yerine

    return {
        "total_commands":       total_commands,
        "today_commands":       today_commands,
        "total_users":          total_users,
        "total_orders":         total_orders,
        "pending_orders":       pending_orders,
        "connected_cars":       ws_status["connected_cars"],
        "command_distribution": {item["_id"]: item["count"] for item in cmd_dist},
    }