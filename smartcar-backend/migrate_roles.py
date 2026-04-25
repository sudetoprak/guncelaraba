"""
Migration: roles koleksiyonu olusturur ve users/admins belgelerine role_id ekler.

Calistirmak icin:
    python migrate_roles.py
"""

import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from datetime import datetime

MONGO_URI = "mongodb://localhost:27017"
MONGO_DB  = "smartcar"


async def migrate():
    client = AsyncIOMotorClient(MONGO_URI)
    db     = client[MONGO_DB]

    # ── 1. roles koleksiyonunu olustur ─────────────────────────────────────────
    existing_roles = await db.roles.find().to_list(length=None)
    role_map = {r["name"]: r["_id"] for r in existing_roles}

    for role_name in ["user", "admin"]:
        if role_name not in role_map:
            result = await db.roles.insert_one({
                "name":        role_name,
                "created_at":  datetime.utcnow(),
            })
            role_map[role_name] = result.inserted_id
            print(f"  Rol olusturuldu: {role_name}")
        else:
            print(f"  Rol zaten var: {role_name}")

    user_role_id  = role_map["user"]
    admin_role_id = role_map["admin"]

    # ── 2. users koleksiyonuna role_id ekle ────────────────────────────────────
    users_updated = 0
    users = await db.users.find({"role_id": {"$exists": False}}).to_list(length=None)
    for u in users:
        await db.users.update_one(
            {"_id": u["_id"]},
            {"$set": {"role_id": user_role_id}}
        )
        users_updated += 1

    print(f"\nusers koleksiyonu: {users_updated} belgeye role_id eklendi.")

    # ── 3. admins koleksiyonuna role_id ekle ───────────────────────────────────
    admins_updated = 0
    admins = await db.admins.find({"role_id": {"$exists": False}}).to_list(length=None)
    for a in admins:
        await db.admins.update_one(
            {"_id": a["_id"]},
            {"$set": {"role_id": admin_role_id}}
        )
        admins_updated += 1

    print(f"admins koleksiyonu: {admins_updated} belgeye role_id eklendi.")
    print("\nMigration tamamlandi.")

    # ── Sonucu goster ──────────────────────────────────────────────────────────
    print("\n--- roles koleksiyonu ---")
    for r in await db.roles.find().to_list(length=None):
        print(f"  _id: {r['_id']}  name: {r['name']}")

    client.close()


if __name__ == "__main__":
    asyncio.run(migrate())
