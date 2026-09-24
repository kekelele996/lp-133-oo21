#!/bin/bash

echo "======================================"
echo "  志愿者互助平台 - 快速验证"
echo "======================================"
echo ""

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📋 项目结构检查..."
echo ""

# 检查必需文件
files=(
  "docker-compose.yml"
  "backend/server.js"
  "backend/db.js"
  "backend/init-db.js"
  "backend/.env"
  "backend/package.json"
  "frontend/package.json"
  "frontend/vite.config.js"
  "test-api.sh"
  "start-all.sh"
  "stop-all.sh"
)

all_ok=true
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo -e "${GREEN}✅ $file${NC}"
  else
    echo -e "${RED}❌ $file 不存在${NC}"
    all_ok=false
  fi
done

echo ""
if [ "$all_ok" = true ]; then
  echo -e "${GREEN}✅ 所有必需文件已就绪${NC}"
else
  echo -e "${RED}❌ 缺少必需文件，请检查${NC}"
  exit 1
fi

echo ""
echo "🔍 端口配置检查..."
echo ""

# 检查后端端口
echo "后端端口: $(grep 'PORT=' backend/.env | cut -d'=' -f2)"
echo "数据库端口: $(grep 'DB_PORT=' backend/.env | cut -d'=' -f2)"
echo "前端端口: $(grep 'port' frontend/vite.config.js | grep -o '[0-9]\{4\}')"

echo ""
echo "📦 后端依赖检查..."
if [ -d "backend/node_modules" ]; then
  echo -e "${GREEN}✅ 后端依赖已安装${NC}"
else
  echo -e "${YELLOW}⚠️  后端依赖未安装${NC}"
fi

echo ""
echo "📦 前端依赖检查..."
if [ -d "frontend/node_modules" ]; then
  echo -e "${GREEN}✅ 前端依赖已安装${NC}"
else
  echo -e "${YELLOW}⚠️  前端依赖未安装${NC}"
fi

echo ""
echo "🐳 Docker 检查..."
if command -v docker &> /dev/null; then
  echo -e "${GREEN}✅ Docker 已安装${NC}"
  if docker ps --filter "name=volunteer-mysql" --format '{{.Names}}' | grep -q "volunteer-mysql" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 数据库容器正在运行${NC}"
  else
    echo -e "${YELLOW}⚠️  数据库容器未运行${NC}"
  fi
else
  echo -e "${RED}❌ Docker 未安装${NC}"
fi

echo ""
echo "🔌 后端服务检查..."
if curl -s -f http://localhost:3233/api/health > /dev/null 2>&1; then
  HEALTH=$(curl -s http://localhost:3233/api/health)
  echo -e "${GREEN}✅ 后端服务正常: $HEALTH${NC}"
else
  echo -e "${YELLOW}⚠️  后端服务未运行${NC}"
fi

echo ""
echo "======================================"
echo "  快速启动指南"
echo "======================================"
echo ""
echo "第一次启动："
echo "  ./start-all.sh"
echo "  cd frontend && npm run dev"
echo ""
echo "重启服务："
echo "  ./stop-all.sh"
echo "  ./start-all.sh"
echo ""
echo "运行测试："
echo "  ./test-api.sh"
echo ""
echo -e "${YELLOW}💡 提示：所有脚本都已设置可执行权限${NC}"
echo ""
