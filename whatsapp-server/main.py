import os
import httpx
from datetime import datetime, timezone
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Query
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel
from supabase import create_client, Client

load_dotenv()

app = FastAPI(title="SI Exporter WhatsApp Server")

# إعداد Supabase
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
)

WA_API_VERSION = os.getenv("WHATSAPP_API_VERSION", "v20.0")
WA_TOKEN = os.getenv("WHATSAPP_ACCESS_TOKEN")
WA_PHONE_ID = os.getenv("WHATSAPP_PHONE_NUMBER_ID")
VERIFY_TOKEN = os.getenv("META_VERIFY_TOKEN")

# ══════════════════════════════════════════════════════════
# 1. التحقق من الـ Webhook (GET)
# ══════════════════════════════════════════════════════════
@app.get("/webhook")
async def verify_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
    hub_verify_token: str = Query(None, alias="hub.verify_token")
):
    if hub_mode == "subscribe" and hub_verify_token == VERIFY_TOKEN:
        print("✅ Webhook verified successfully!")
        return PlainTextResponse(content=hub_challenge, status_code=200)
    print("❌ Webhook verification failed!")
    raise HTTPException(status_code=403, detail="Verification failed")

# ══════════════════════════════════════════════════════════
# 2. استقبال الرسائل وحفظها (POST)
# ══════════════════════════════════════════════════════════
@app.post("/webhook")
async def receive_webhook(request: Request):
    body = await request.json()
    
    # طباعة للتأكد إننا بنستقبل
    print("\n🔴🔴🔴 PAYLOAD RECEIVED 🔴🔴🔴")
    import json
    print(json.dumps(body, indent=2, ensure_ascii=False))
    print("🔴🔴🔴 END PAYLOAD 🔴🔴🔴\n")

    try:
        if body.get("object") == "whatsapp_business_account":
            await handle_whatsapp(body)
    except Exception as e:
        print(f"❌ CRITICAL ERROR: {str(e)}")
        return {"status": "error", "message": str(e)}

    return {"status": "ok"}

async def handle_whatsapp(payload: dict):
    for entry in payload.get("entry", []):
        for change in entry.get("changes", []):
            value = change.get("value", {})
            
            # لو الرسالة دي status (تم التسليم/القراءة) مش رسالة حقيقية، تجاهلها
            if "messages" not in value:
                continue
                
            contacts = value.get("contacts", [])
            messages = value.get("messages", [])
            
            for msg in messages:
                if msg.get("type") != "text":
                    continue
                
                sender_phone = msg.get("from")
                text = msg.get("text", {}).get("body", "")
                message_id = msg.get("id")
                
                # جلب اسم العميل لو موجود
                contact_name = sender_phone
                for contact in contacts:
                    if contact.get("wa_id") == sender_phone:
                        contact_name = contact.get("profile", {}).get("name", sender_phone)
                        break

                await save_message(
                    phone=sender_phone,
                    name=contact_name,
                    text=text,
                    message_id=message_id,
                    from_me=False
                )

async def save_message(phone: str, name: str, text: str, message_id: str = None, from_me: bool = False):
    try:
        # 1. البحث عن المحادثة أو إنشائها
        conv_res = supabase.table("whatsapp_conversations") \
            .select("id") \
            .eq("customer_phone", phone) \
            .execute()

        if conv_res.data:
            conversation_id = conv_res.data[0]["id"]
            supabase.table("whatsapp_conversations").update({
                "last_message_preview": text[:100],
                "last_message_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", conversation_id).execute()
        else:
            new_conv = supabase.table("whatsapp_conversations").insert({
                "customer_phone": phone,
                "customer_name": name,
                "last_message_preview": text[:100],
                "last_message_at": datetime.now(timezone.utc).isoformat(),
                "status": "open",
            }).execute()
            conversation_id = new_conv.data[0]["id"]

        # 2. حفظ الرسالة
        supabase.table("whatsapp_messages").insert({
            "conversation_id": conversation_id,
            "message_id": message_id,
            "from_me": from_me,
            "content": text,
            "message_type": "text",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }).execute()
        
        print(f"✅ تم حفظ رسالة {'صادرة' if from_me else 'واردة'} من/إلى {phone}")

    except Exception as e:
        print(f"❌ خطأ في الحفظ: {e}")


# ══════════════════════════════════════════════════════════
# 3. Endpoint للإرسال (للفلاتر)
# ══════════════════════════════════════════════════════════
class SendRequest(BaseModel):
    phone: str
    text: str
    agent_id: str | None = None

@app.post("/send")
async def send_message(req: SendRequest):
    try:
        url = f"https://graph.facebook.com/{WA_API_VERSION}/{WA_PHONE_ID}/messages"
        headers = {
            "Authorization": f"Bearer {WA_TOKEN}",
            "Content-Type": "application/json"
        }
        payload = {
            "messaging_product": "whatsapp",
            "to": req.phone,
            "type": "text",
            "text": {"body": req.text}
        }

        async with httpx.AsyncClient() as client:
            res = await client.post(url, headers=headers, json=payload)
            if res.status_code != 200:
                raise Exception(f"Meta API Error: {res.text}")

        # نحفظ الرسالة في الداتابيز
        await save_message(
            phone=req.phone,
            name="Agent",
            text=req.text,
            from_me=True
        )

        return {"success": True, "message": "تم الإرسال"}

    except Exception as e:
        print(f"❌ خطأ في الإرسال: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ══════════════════════════════════════════════════════════
# 4. Health check
# ══════════════════════════════════════════════════════════
@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"message": "WhatsApp Server is running! 🚀"}