"""
Migration: users koleksiyonundaki adminleri admins koleksiyonuna taşır.

Çalıştırmak için:
    python migrate_admins.py
"""

import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

MONGO_URI = "mongodb://localhost:27017"
MONGO_DB  = "smartcar"


async def migrate():
    client = AsyncIOMotorClient(MONGO_URI)
    db     = client[MONGO_DB]

    # users koleksiyonundaki tüm adminleri bul
    admins = await db.users.find({"role": "admin"}).to_list(length=None)

    if not admins:
        print("OK - users koleksiyonunda tasınacak admin yok.")
        client.close()
        return

    print(f"Bulunan admin sayisi: {len(admins)} - admins koleksiyonuna tasiniyor...")

    moved = 0
    skipped = 0

    for admin in admins:
        admin_id = admin["_id"]

        # Zaten admins koleksiyonunda var mı?
        exists = await db.admins.find_one({"_id": admin_id})
        if exists:
            print(f"  Atlandi (zaten mevcut): {admin.get('email')}")
            skipped += 1
            continue

        # admins koleksiyonuna ekle
        await db.admins.insert_one(admin)

        # users koleksiyonundan sil
        await db.users.delete_one({"_id": admin_id})

        print(f"  Tasindi: {admin.get('email')}")
        moved += 1

    print(f"\nMigration tamamlandi: {moved} tasindi, {skipped} atlandi.")
    client.close()


if __name__ == "__main__":
    asyncio.run(migrate())
