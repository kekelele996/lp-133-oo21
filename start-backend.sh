#!/bin/bash

echo "======================================"
echo "  志愿者互助平台 - 启动后端服务"
echo "======================================"
echo ""

cd backend

if [ ! -d "node_modules" ]; then
  echo "📦 正在安装后端依赖..."
  npm install
fi

echo "🚀 启动后端服务，端口: 3233"
npm start
