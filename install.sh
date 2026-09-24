#!/bin/bash

echo "======================================"
echo "  志愿者互助平台 - 启动脚本"
echo "======================================"
echo ""

echo "📦 正在安装后端依赖..."
cd backend
npm install
echo "✅ 后端依赖安装完成"
echo ""

echo "📦 正在安装前端依赖..."
cd ../frontend
npm install
echo "✅ 前端依赖安装完成"
echo ""

echo "======================================"
echo "  依赖安装完成！"
echo ""
echo "  请按以下步骤启动："
echo "  1. 启动 MySQL 数据库，端口 5733"
echo "  2. 执行 database/init.sql 初始化数据"
echo "  3. 启动后端：cd backend && npm start"
echo "  4. 启动前端：cd frontend && npm run dev"
echo ""
echo "  访问地址：http://localhost:8233"
echo "  后端地址：http://localhost:3233"
echo "======================================"
