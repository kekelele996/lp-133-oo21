#!/bin/bash

echo "======================================"
echo "  志愿者互助平台 - 停止服务"
echo "======================================"
echo ""

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$PROJECT_DIR"

# 停止后端服务
echo "🛑 停止后端服务..."
pkill -f "node server.js" 2>/dev/null || true

# 停止前端服务
echo "🛑 停止前端服务..."
pkill -f "vite" 2>/dev/null || true

# 停止 Docker 容器
echo "🛑 停止数据库容器..."
docker compose down 2>/dev/null || true

# 清理 nohup 文件
rm -f backend/nohup.out frontend/nohup.out 2>/dev/null

echo ""
echo "✅ 所有服务已停止"
