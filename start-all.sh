#!/bin/bash

echo "======================================"
echo "  志愿者互助平台 - 一键启动脚本"
echo "======================================"
echo ""

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$PROJECT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_docker() {
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装，请先安装 Docker${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ Docker 已安装${NC}"
}

check_node() {
  if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js 未安装，请先安装 Node.js >= 14${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ Node.js 已安装: $(node --version)${NC}"
}

check_port() {
  if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

echo ""
echo "📋 环境检查..."
check_docker
check_node

echo ""
echo "🔍 端口检查..."
for port in 5733 3233 8233; do
  if ! check_port $port; then
    echo -e "${YELLOW}⚠️  端口 $port 已被占用，尝试清理...${NC}"
    lsof -ti :$port | xargs kill -9 2>/dev/null || true
    sleep 1
  fi
  if check_port $port; then
    echo -e "${GREEN}✅ 端口 $port 可用${NC}"
  else
    echo -e "${YELLOW}⚠️  端口 $port 仍被占用，请手动检查${NC}"
  fi
done

echo ""
echo "🐳 启动 MySQL 数据库 (端口: 5733)..."
cd "$PROJECT_DIR"

# 清理旧容器
docker compose down -v > /dev/null 2>&1 || true

# 启动 MySQL
docker compose up -d mysql

echo ""
echo "⏳ 等待数据库启动..."
for i in {1..30}; do
  if docker exec volunteer-mysql mysqladmin ping -h localhost -uroot -p123456 --silent 2>/dev/null; then
    echo -e "${GREEN}✅ 数据库启动成功${NC}"
    break
  fi
  if [ $i -eq 30 ]; then
    echo -e "${RED}❌ 数据库启动超时，请查看日志: docker logs volunteer-mysql${NC}"
    exit 1
  fi
  printf "."
  sleep 2
done
echo ""

echo ""
echo "📦 安装后端依赖..."
cd "$PROJECT_DIR/backend"
if [ ! -d "node_modules" ]; then
  npm install --silent 2>&1 | tail -3
fi
echo -e "${GREEN}✅ 后端依赖就绪${NC}"

echo ""
echo "📦 初始化数据库数据..."
node init-db.js
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ 数据库初始化失败${NC}"
  exit 1
fi

echo ""
echo "📦 安装前端依赖..."
cd "$PROJECT_DIR/frontend"
if [ ! -d "node_modules" ]; then
  npm install --silent 2>&1 | tail -3
fi
echo -e "${GREEN}✅ 前端依赖就绪${NC}"

echo ""
echo "🚀 启动后端服务 (端口: 3233)..."
cd "$PROJECT_DIR/backend"
rm -f nohup.out

# 先检查是否有残留进程
pkill -f "node server.js" 2>/dev/null || true
sleep 1

nohup npm start > nohup.out 2>&1 &
BACKEND_PID=$!
echo "后端服务 PID: $BACKEND_PID"

# 等待后端启动 - 更健壮的检查
echo ""
echo "⏳ 等待后端服务启动..."
for i in {1..30}; do
  if curl -s -f http://localhost:3233/api/health > /dev/null 2>&1; then
    HEALTH_CHECK=$(curl -s http://localhost:3233/api/health)
    if echo "$HEALTH_CHECK" | grep -q "ok" > /dev/null 2>&1; then
      echo -e "${GREEN}✅ 后端服务启动成功${NC}"
      break
    fi
  fi
  if [ $i -eq 30 ]; then
    echo -e "${RED}❌ 后端服务启动超时${NC}"
    echo "📋 后端日志:"
    cat nohup.out
    exit 1
  fi
  printf "."
  sleep 1
done
echo ""

echo ""
echo "🎉 启动完成！"
echo ""
echo "📱 前端启动命令: cd frontend && npm run dev"
echo "🌐 前端地址: http://localhost:8233"
echo "🔌 后端地址: http://localhost:3233"
echo "🗄️  数据库端口: 5733"
echo ""
echo "📋 常用命令:"
echo "   查看后端日志: tail -f backend/nohup.out"
echo "   运行API测试: ./test-api.sh"
echo "   停止所有服务: ./stop-all.sh"
echo ""
echo -e "${YELLOW}💡 演示账号:${NC}"
echo "   志愿者: 13800138001 / 123456"
echo "   居  民: 13900139001 / 123456"
echo ""
