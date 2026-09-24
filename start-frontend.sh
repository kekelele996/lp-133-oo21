#!/bin/bash

echo "======================================"
echo "  志愿者互助平台 - 启动前端服务"
echo "======================================"
echo ""

cd frontend

if [ ! -d "node_modules" ]; then
  echo "📦 正在安装前端依赖..."
  npm install
fi

echo "🚀 启动前端服务，端口: 8233"
npm run dev
