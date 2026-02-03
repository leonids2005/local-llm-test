#!/bin/bash
# Connect to Ollama via IAP tunnel and configure Claude Code

INSTANCE="llm-server-dev"
ZONE="us-central1-c"  # Default zone for GPU spot instances
PORT="11434"

echo "🔒 Creating secure IAP tunnel to Ollama..."
echo ""

# Check if tunnel already exists
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Port $PORT is already in use. Tunnel may already be running."
    echo "   To kill existing tunnel: pkill -f '$PORT:localhost:$PORT'"
    exit 1
fi

# Create tunnel
gcloud compute start-iap-tunnel $INSTANCE $PORT \
  --local-host-port=localhost:$PORT \
  --zone=$ZONE &

TUNNEL_PID=$!
sleep 2

# Verify tunnel is running
if ps -p $TUNNEL_PID > /dev/null; then
    echo "✅ Tunnel created successfully (PID: $TUNNEL_PID)"
    echo "🌐 Ollama API: http://localhost:$PORT"
    echo ""
    echo "📋 Quick start:"
    echo "   export ANTHROPIC_AUTH_TOKEN=ollama"
    echo "   export ANTHROPIC_BASE_URL=http://localhost:$PORT"
    echo "   claude --model qwen2.5-coder:7b"
    echo ""
    echo "⏹️  To stop tunnel: kill $TUNNEL_PID or pkill -f '$PORT:localhost:$PORT'"
    echo ""

    # Keep tunnel open
    wait $TUNNEL_PID
else
    echo "❌ Failed to create tunnel"
    exit 1
fi
