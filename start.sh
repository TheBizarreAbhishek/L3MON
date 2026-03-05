#!/usr/bin/env bash
# L3MON Start Script
cd "$(dirname "$0")/.files"

# Find node binary
if command -v node &>/dev/null; then
    NODE_BIN="node"
elif [ -f "/opt/homebrew/bin/node" ]; then
    NODE_BIN="/opt/homebrew/bin/node"
else
    echo "Error: node not found. Run install.sh first."
    exit 1
fi

echo ""
echo "  Starting L3MON..."
echo "  Web Panel   → http://localhost:22533"
echo "  Socket Port → 22222"
echo "  Press Ctrl+C to stop"
echo ""
$NODE_BIN index.js
