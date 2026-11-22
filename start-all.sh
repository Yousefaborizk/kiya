#!/bin/bash
echo "🚀 Starting WhatsApp Gateway..."
cd whatsapp-gateway && node index.js &
WA_PID=$!

echo "🚀 Starting Facebook Gateway..."
cd ../facebook-gateway && node index.js &
FB_PID=$!

# عشان تضمن إن السيرفرات هتقفل مع بعض لما تدوس Ctrl+C
trap "kill $WA_PID $FB_PID" EXIT
wait