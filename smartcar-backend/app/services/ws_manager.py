from fastapi import WebSocket
from typing import Dict, Set
import json
import asyncio
from datetime import datetime


class ConnectionManager:
    """
    Her arabaya (car_id) birden fazla controller bağlanabilir.
    Araba da aynı car_id ile bağlanır ve komutları dinler.
    Admin gözlemciler tüm canlı komutları alır.
    """

    def __init__(self):
        # car_id → araba WebSocket
        self.cars: Dict[str, WebSocket] = {}
        # car_id → controller WebSocket seti
        self.controllers: Dict[str, Set[WebSocket]] = {}
        # admin gözlemci WebSocket seti (canlı komut akışı için)
        self.admin_observers: Set[WebSocket] = set()

    async def connect_car(self, car_id: str, websocket: WebSocket):
        await websocket.accept()
        self.cars[car_id] = websocket
        print(f"🚗 Araba bağlandı: {car_id}")

    async def connect_controller(self, car_id: str, websocket: WebSocket):
        await websocket.accept()
        if car_id not in self.controllers:
            self.controllers[car_id] = set()
        self.controllers[car_id].add(websocket)
        print(f"🕹️  Controller bağlandı: {car_id}, toplam: {len(self.controllers[car_id])}")

    async def disconnect_car(self, car_id: str):
        if car_id in self.cars:
            del self.cars[car_id]
            print(f"🚗 Araba ayrıldı: {car_id}")
            # Controller'lara arabının ayrıldığını bildir
            await self.broadcast_to_controllers(car_id, {
                "type": "car_disconnected",
                "car_id": car_id
            })

    async def disconnect_controller(self, car_id: str, websocket: WebSocket):
        if car_id in self.controllers:
            self.controllers[car_id].discard(websocket)
            if not self.controllers[car_id]:
                del self.controllers[car_id]

    async def connect_admin_observer(self, websocket: WebSocket):
        await websocket.accept()
        self.admin_observers.add(websocket)
        print(f"👁️  Admin gözlemci bağlandı, toplam: {len(self.admin_observers)}")

    async def disconnect_admin_observer(self, websocket: WebSocket):
        self.admin_observers.discard(websocket)
        print(f"👁️  Admin gözlemci ayrıldı, kalan: {len(self.admin_observers)}")

    async def broadcast_to_admins(self, message: dict):
        """Tüm admin gözlemcilere canlı komut yayını"""
        disconnected = set()
        for ws in self.admin_observers:
            try:
                await ws.send_text(json.dumps(message, default=str))
            except Exception:
                disconnected.add(ws)
        for ws in disconnected:
            self.admin_observers.discard(ws)

    async def send_command_to_car(self, car_id: str, command: dict) -> bool:
        """Arabaya komut gönder. Başarılıysa True döner."""
        if car_id not in self.cars:
            return False
        try:
            await self.cars[car_id].send_text(json.dumps(command))
            return True
        except Exception as e:
            print(f"⚠️  Arabaya komut gönderilemedi: {e}")
            await self.disconnect_car(car_id)
            return False

    async def broadcast_to_controllers(self, car_id: str, message: dict):
        """Tüm controller'lara mesaj gönder (örn: araba durumu)"""
        if car_id not in self.controllers:
            return
        disconnected = set()
        for ws in self.controllers[car_id]:
            try:
                await ws.send_text(json.dumps(message))
            except Exception:
                disconnected.add(ws)
        for ws in disconnected:
            self.controllers[car_id].discard(ws)

    def is_car_connected(self, car_id: str) -> bool:
        return car_id in self.cars

    def get_status(self) -> dict:
        return {
            "connected_cars": list(self.cars.keys()),
            "controller_counts": {
                car_id: len(ws_set)
                for car_id, ws_set in self.controllers.items()
            }
        }


manager = ConnectionManager()


VALID_COMMANDS = {"forward", "backward", "left", "right", "stop"}


def validate_command(data: dict) -> tuple[bool, str]:
    """Komut doğrulama. (geçerli_mi, hata_mesajı)"""
    cmd = data.get("command", "")
    if cmd not in VALID_COMMANDS:
        return False, f"Geçersiz komut: {cmd}"

    x = data.get("x", 0.0)
    y = data.get("y", 0.0)
    speed = data.get("speed", 128)

    if not (-1.0 <= x <= 1.0):
        return False, "x ekseni -1.0 ile 1.0 arasında olmalı"
    if not (-1.0 <= y <= 1.0):
        return False, "y ekseni -1.0 ile 1.0 arasında olmalı"
    if not (0 <= speed <= 255):
        return False, "speed 0 ile 255 arasında olmalı"

    return True, ""