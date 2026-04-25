from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings

client: AsyncIOMotorClient = None


async def connect_db():
    global client
    client = AsyncIOMotorClient(settings.MONGO_URI)
    await client.admin.command("ping")
    print("✅ MongoDB bağlantısı kuruldu")


async def close_db():
    global client
    if client:
        client.close()
        print("🔌 MongoDB bağlantısı kapatıldı")


def get_db():
    return client[settings.MONGO_DB]