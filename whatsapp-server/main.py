import os
import json
import httpx
from datetime import datetime, timezone
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Query
from fastapi.responses import PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client, Client

# ── تحميل المتغيرات من .env ──
load_dotenv()

# ── إعداد السيرفر ──
app = FastAPI(title="SI Exporter Server (WhatsApp & Facebook)")

# ✅ إعداد CORS (ضروري جداً عشان Flutter Web على Chrome يقدر يتصل)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── إعداد Supabase (بمفتاح Service Role) ──
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
)

# ── إعدادات Meta ──
WA_API_VERSION = os.getenv("WHATSAPP_API_VERSION", "v20.0")
WA_TOKEN = os.getenv("WHATSAPP_ACCESS_TOKEN")
WA_PHONE_ID = os.getenv("WHATSAPP_PHONE_NUMBER_ID")

FB_PAGE_ID = os.getenv("FACEBOOK_PAGE_ID")
FB_TOKEN = os.getenv("FACEBOOK_PAGE_ACCESS_TOKEN")

VERIFY_TOKEN = os.getenv("META_VERIFY_TOKEN")


# ══════════════════════════════════════════════════════════
# Helpers — جلب org_id للـ Multi-Tenant
# ══════════════════════════════════════════════════════════
async def get_org_id_for_whatsapp() -> str | None:
    if WA_PHONE_ID:
        try:
            res = supabase.table("whatsapp_installations").select("org_id").eq("phone_number_id", WA_PHONE_ID).limit(1).execute()
            if res.data and res.data[0].get("org_id"): return res.data[0]["org_id"]
        except: pass
    try:
        res = supabase.table("whatsapp_conversations").select("org_id").not_.is_("org_id", "null").limit(1).execute()
        if res.data and res.data[0].get("org_id"): return res.data[0]["org_id"]
    except: pass
    try:
        res = supabase.table("organizations").select("id").limit(1).execute()
        if res.data: return res.data[0]["id"]
    except: pass
    return None


async def get_org_id_for_facebook() -> str | None:
    if FB_PAGE_ID:
        try:
            res = supabase.table("facebook_installations").select("org_id").eq("page_id", FB_PAGE_ID).limit(1).execute()
            if res.data and res.data[0].get("org_id"): return res.data[0]["org_id"]
        except: pass
    try:
        res = supabase.table("facebook_conversations").select("org_id").not_.is_("org_id", "null").limit(1).execute()
        if res.data and res.data[0].get("org_id"): return res.data[0]["org_id"]
    except: pass
    try:
        res = supabase.table("organizations").select("id").limit(1).execute()
        if res.data: return res.data[0]["id"]
    except: pass
    return None


# ✅ دالة بتجيب اسم العميل الحقيقي من فيسبوك (عشان بدل "عميل فيسبوك")
async def get_fb_user_name(psid: str) -> str:
    if not FB_TOKEN: return "عميل فيسبوك"
    url = f"https://graph.facebook.com/{WA_API_VERSION}/{psid}"
    params = {"fields": "name,first_name,last_name", "access_token": FB_TOKEN}
    try:
        async with httpx.AsyncClient() as client:
            res = await client.get(url, params=params)
            if res.status_code == 200:
                data = res.json()
                return data.get("name", "عميل فيسبوك")
    except Exception as e:
        print(f"⚠️ Failed to fetch FB name for {psid}: {e}")
    return "عميل فيسبوك"


# ══════════════════════════════════════════════════════════
# 1. Webhook Verification (GET)
# ══════════════════════════════════════════════════════════
@app.get("/webhook")
async def verify_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
    hub_verify_token: str = Query(None, alias="hub.verify_token"),
):
    if hub_mode == "subscribe" and hub_verify_token == VERIFY_TOKEN:
        print("✅ Webhook verified successfully!")
        return PlainTextResponse(content=hub_challenge, status_code=200)
    print("❌ Webhook verification failed!")
    raise HTTPException(status_code=403, detail="Verification failed")


# ══════════════════════════════════════════════════════════
# 2. Webhook Receiver (POST)
# ══════════════════════════════════════════════════════════
@app.post("/webhook")
async def receive_webhook(request: Request):
    body = await request.json()
    print("\n🔴 PAYLOAD RECEIVED:", json.dumps(body, indent=2))

    try:
        obj = body.get("object")
        if obj == "whatsapp_business_account":
            await handle_whatsapp(body)
        elif obj == "page":
            await handle_facebook(body)
    except Exception as e:
        print(f"❌ CRITICAL ERROR: {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    return {"status": "ok"}


# ══════════════════════════════════════════════════════════
# 3. WhatsApp Handler
# ══════════════════════════════════════════════════════════
async def handle_whatsapp(payload: dict):
    for entry in payload.get("entry", []):
        for change in entry.get("changes", []):
            value = change.get("value", {})
            if "messages" not in value: continue
            contacts = value.get("contacts", [])
            messages = value.get("messages", [])
            for msg in messages:
                if msg.get("type") != "text": continue
                sender_phone = msg.get("from")
                text = msg.get("text", {}).get("body", "")
                message_id = msg.get("id")
                contact_name = sender_phone
                for contact in contacts:
                    if contact.get("wa_id") == sender_phone:
                        contact_name = contact.get("profile", {}).get("name", sender_phone)
                        break
                await save_whatsapp_message(sender_phone, contact_name, text, message_id, False)


async def save_whatsapp_message(phone: str, name: str, text: str, message_id: str = None, from_me: bool = False, sender_id: str = None):
    org_id = await get_org_id_for_whatsapp()
    conv_res = supabase.table("whatsapp_conversations").select("id").eq("customer_phone", phone).execute()
    
    if conv_res.data:
        conversation_id = conv_res.data[0]["id"]
        if org_id:
            try: supabase.table("whatsapp_conversations").update({"org_id": org_id}).eq("id", conversation_id).is_("org_id", "null").execute()
            except: pass
    else:
        new_conv = supabase.table("whatsapp_conversations").insert({
            "customer_phone": phone, "customer_name": name, "last_message_preview": text[:100],
            "last_message_at": datetime.now(timezone.utc).isoformat(), "status": "open",
            "org_id": org_id, "phone_number_id": WA_PHONE_ID,
        }).execute()
        conversation_id = new_conv.data[0]["id"]

    supabase.table("whatsapp_conversations").update({
        "last_message_preview": text[:100], "last_message_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", conversation_id).execute()

    msg_payload = {
        "conversation_id": conversation_id, "message_id": message_id, "from_me": from_me,
        "content": text, "message_type": "text", "timestamp": datetime.now(timezone.utc).isoformat(), "org_id": org_id,
    }
    if sender_id: msg_payload["sender_id"] = sender_id

    if message_id: supabase.table("whatsapp_messages").upsert(msg_payload, on_conflict="message_id").execute()
    else: supabase.table("whatsapp_messages").insert(msg_payload).execute()
    print(f"✅ WA: Saved {'outgoing' if from_me else 'incoming'} for {phone}")


# ══════════════════════════════════════════════════════════
# 4. Facebook Handler
# ══════════════════════════════════════════════════════════
async def handle_facebook(payload: dict):
    for entry in payload.get("entry", []):
        for messaging in entry.get("messaging", []):
            sender = messaging.get("sender", {}).get("id")
            recipient = messaging.get("recipient", {}).get("id")
            message = messaging.get("message", {})
            if not message: continue
            
            text = message.get("text", "")
            message_id = message.get("mid")
            is_echo = message.get("is_echo", False)
            if not text and message.get("attachments"): text = "[مرفق / صورة]"

            if is_echo:
                await save_facebook_message(recipient, "Agent", text, message_id, True)
            else:
                # بنجيب اسم العميل الحقيقي من فيسبوك
                real_name = await get_fb_user_name(sender)
                await save_facebook_message(sender, real_name, text, message_id, False)


async def save_facebook_message(psid: str, name: str, text: str, message_id: str = None, from_me: bool = False, sender_id: str = None):
    if not FB_PAGE_ID: raise Exception("FB_PAGE_ID is missing in .env")
    org_id = await get_org_id_for_facebook()
    
    conv_res = supabase.table("facebook_conversations").select("id, customer_name").eq("psid", psid).execute()
    
    if conv_res.data:
        conversation_id = conv_res.data[0]["id"]
        current_name = conv_res.data[0].get("customer_name", "")
        update_data = {}
        
        # لو الـ org_id ناقص نحدثه، ولو الاسم قديم نحدثه بالاسم الحقيقي
        if org_id and conv_res.data[0].get("org_id") is None: update_data["org_id"] = org_id
        if name and name != "عميل فيسبوك" and (current_name == "عميل فيسبوك" or not current_name): 
            update_data["customer_name"] = name
        
        if update_data:
            try: supabase.table("facebook_conversations").update(update_data).eq("id", conversation_id).execute()
            except: pass
    else:
        new_conv = supabase.table("facebook_conversations").insert({
            "page_id": FB_PAGE_ID, "psid": psid, "customer_name": name, "last_message_preview": text[:100],
            "last_message_at": datetime.now(timezone.utc).isoformat(), "status": "open", "org_id": org_id,
        }).execute()
        conversation_id = new_conv.data[0]["id"]

    supabase.table("facebook_conversations").update({
        "last_message_preview": text[:100], "last_message_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", conversation_id).execute()

    msg_payload = {
        "conversation_id": conversation_id, "message_id": message_id, "from_me": from_me,
        "content": text, "timestamp": datetime.now(timezone.utc).isoformat(), "org_id": org_id,
    }
    if sender_id: msg_payload["sender_id"] = sender_id

    if message_id: supabase.table("facebook_messages").upsert(msg_payload, on_conflict="message_id").execute()
    else: supabase.table("facebook_messages").insert(msg_payload).execute()
    print(f"✅ FB: Saved {'outgoing' if from_me else 'incoming'} for {psid} (name: {name})")


# ══════════════════════════════════════════════════════════
# 5. Send Endpoints (عشان نبعت من Flutter)
# ══════════════════════════════════════════════════════════
class SendRequest(BaseModel):
    phone: str
    text: str
    agent_id: str | None = None


@app.post("/send")
async def send_whatsapp_message(req: SendRequest):
    try:
        url = f"https://graph.facebook.com/{WA_API_VERSION}/{WA_PHONE_ID}/messages"
        headers = {"Authorization": f"Bearer {WA_TOKEN}", "Content-Type": "application/json"}
        payload = {"messaging_product": "whatsapp", "to": req.phone, "type": "text", "text": {"body": req.text}}

        async with httpx.AsyncClient() as client:
            res = await client.post(url, headers=headers, json=payload)
            if res.status_code != 200: raise Exception(f"Meta API Error: {res.text}")

        meta_data = res.json()
        meta_message_id = meta_data["messages"][0]["id"] if meta_data.get("messages") else None

        try: await save_whatsapp_message(req.phone, "Agent", req.text, message_id=meta_message_id, from_me=True, sender_id=req.agent_id)
        except Exception as save_err: print(f"⚠️ WA saved after send failed: {save_err}")

        return {"success": True, "message": "تم الإرسال"}
    except Exception as e:
        print(f"❌ WA Send Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/send/facebook")
async def send_facebook_message(req: SendRequest):
    try:
        url = f"https://graph.facebook.com/{WA_API_VERSION}/me/messages"
        params = {"access_token": FB_TOKEN}
        payload = {"recipient": {"id": req.phone}, "messaging_type": "RESPONSE", "message": {"text": req.text}}

        async with httpx.AsyncClient() as client:
            res = await client.post(url, params=params, json=payload)
            if res.status_code != 200: raise Exception(f"FB API Error: {res.text}")

        meta_data = res.json()
        meta_message_id = meta_data.get("message_id")

        try: await save_facebook_message(req.phone, "Agent", req.text, message_id=meta_message_id, from_me=True, sender_id=req.agent_id)
        except Exception as save_err: print(f"⚠️ FB saved after send failed: {save_err}")

        return {"success": True, "message": "تم الإرسال"}
    except Exception as e:
        print(f"❌ FB Send Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ══════════════════════════════════════════════════════════
# 6. Reply to Comment
# ══════════════════════════════════════════════════════════
@app.post("/reply-comment")
async def reply_to_comment(request: Request):
    try:
        body = await request.json()
        comment_id = body.get("comment_id")
        text = body.get("text")
        agent_id = body.get("agent_id")
        if not comment_id or not text: raise HTTPException(status_code=400, detail="comment_id and text are required")

        url = f"https://graph.facebook.com/{WA_API_VERSION}/{comment_id}/comments"
        params = {"message": text, "access_token": FB_TOKEN}

        async with httpx.AsyncClient() as client:
            res = await client.post(url, params=params)
            if res.status_code != 200: raise Exception(f"FB Reply Error: {res.text}")

        update_payload = {"is_replied": True, "replied_at": datetime.now(timezone.utc).isoformat()}
        if agent_id: update_payload["replied_by"] = agent_id

        supabase.table("social_comments").update(update_payload).eq("comment_id", comment_id).execute()
        return {"success": True, "message": "تم الرد"}
    except HTTPException: raise
    except Exception as e:
        print(f"❌ Reply Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ══════════════════════════════════════════════════════════
# 7. Fetch Posts
# ══════════════════════════════════════════════════════════
@app.get("/posts")
async def get_posts(limit: int = 20):
    if not FB_PAGE_ID or not FB_TOKEN: return {"data": []}
    url = f"https://graph.facebook.com/{WA_API_VERSION}/{FB_PAGE_ID}/posts"
    params = {"fields": "id,message,full_picture,created_time,permalink_url", "limit": limit, "access_token": FB_TOKEN}
    try:
        async with httpx.AsyncClient() as client:
            res = await client.get(url, params=params)
            if res.status_code != 200: return {"data": []}
            return res.json()
    except: return {"data": []}


# ══════════════════════════════════════════════════════════
# 8. Admin: تصليح الصفوف القديمة اللي org_id بتاعها NULL
# ══════════════════════════════════════════════════════════
@app.post("/admin/fix-null-org-ids")
async def fix_null_org_ids():
    try:
        fb_org = await get_org_id_for_facebook()
        wa_org = await get_org_id_for_whatsapp()
        result = {"fb_org_id": fb_org, "wa_org_id": wa_org, "fb_conversations_fixed": 0, "fb_messages_fixed": 0, "wa_conversations_fixed": 0, "wa_messages_fixed": 0}

        if fb_org:
            r1 = supabase.table("facebook_conversations").update({"org_id": fb_org}).is_("org_id", "null").execute()
            result["fb_conversations_fixed"] = len(r1.data)
            r2 = supabase.table("facebook_messages").update({"org_id": fb_org}).is_("org_id", "null").execute()
            result["fb_messages_fixed"] = len(r2.data)

        if wa_org:
            r3 = supabase.table("whatsapp_conversations").update({"org_id": wa_org}).is_("org_id", "null").execute()
            result["wa_conversations_fixed"] = len(r3.data)
            r4 = supabase.table("whatsapp_messages").update({"org_id": wa_org}).is_("org_id", "null").execute()
            result["wa_messages_fixed"] = len(r4.data)

        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ══════════════════════════════════════════════════════════
# 9. Health Check
# ══════════════════════════════════════════════════════════
@app.get("/health")
def health():
    return {"status": "ok", "env_check": {"FB_PAGE_ID": bool(FB_PAGE_ID), "FB_TOKEN": bool(FB_TOKEN)}}

@app.get("/")
def root():
    return {"message": "Server is running! 🚀"}