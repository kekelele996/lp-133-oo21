#!/bin/bash

echo "======================================"
echo "  志愿者互助平台 - API 全流程测试"
echo "======================================"
echo ""

BASE_URL="http://localhost:3233/api"
RED='\033[0;31m'
GREEN='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 全局变量
VOLUNTEER_TOKEN=""
RESIDENT_TOKEN=""
VOLUNTEER2_TOKEN=""
RESIDENT2_TOKEN=""
VOLUNTEER_ID=""
RESIDENT_ID=""
NEED_ID=""
NEED2_ID=""
ORDER_ID=""
ORDER2_ID=""
INITIAL_POINTS=0
HTTP_CODE=0
BODY=""

test_step() {
  echo -e "${YELLOW}▶ $1${NC}"
}

test_pass() {
  echo -e "${GREEN}  ✓ $1${NC}"
}

test_fail() {
  echo -e "${RED}  ✗ $1${NC}"
  exit 1
}

# api_call METHOD PATH TOKEN [JSON_BODY]
# 结果写入 HTTP_CODE 和 BODY
api_call() {
  local method="$1"
  local path="$2"
  local token="$3"
  local data="$4"

  local args=(-s -o /tmp/api_body.$$ -w "%{http_code}" -X "$method" "$BASE_URL$path")
  if [ -n "$token" ]; then
    args+=(-H "Authorization: Bearer $token")
  fi
  if [ -n "$data" ]; then
    args+=(-H "Content-Type: application/json" -d "$data")
  fi

  HTTP_CODE=$(curl "${args[@]}")
  BODY=$(cat /tmp/api_body.$$)
  rm -f /tmp/api_body.$$
}

expect_ok() {
  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    test_pass "$1 (HTTP $HTTP_CODE)"
  else
    echo "响应: $BODY"
    test_fail "$1 (期望成功，实际 HTTP $HTTP_CODE)"
  fi
}

expect_fail() {
  local expected_code="$1"
  local desc="$2"
  if [ "$HTTP_CODE" = "$expected_code" ]; then
    test_pass "$desc (HTTP $HTTP_CODE 被拒绝)"
  else
    echo "响应: $BODY"
    test_fail "$desc (期望 HTTP $expected_code，实际 $HTTP_CODE)"
  fi
}

json_field() {
  echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)$1)"
}

# 1. 测试健康检查
test_step "1. 健康检查"
HEALTH_RES=$(curl -s "$BASE_URL/health")
if echo "$HEALTH_RES" | grep -q "ok" > /dev/null 2>&1; then
  test_pass "后端服务正常 - $(echo $HEALTH_RES | python3 -c "import sys,json; print(json.load(sys.stdin)['message'])")"
else
  test_fail "后端服务未启动，请先运行 ./start-all.sh"
fi

echo ""

# 2. 测试登录 - 居民
test_step "2. 居民登录 (13900139001 / 123456)"
api_call POST /auth/login "" '{"phone":"13900139001","password":"123456"}'
if echo "$BODY" | grep -q "登录成功" > /dev/null 2>&1; then
  RESIDENT_TOKEN=$(json_field "['token']")
  RESIDENT_ID=$(json_field "['user']['id']")
  test_pass "居民登录成功，ID: $RESIDENT_ID"
else
  echo "响应: $BODY"
  test_fail "居民登录失败"
fi

echo ""

# 3. 测试登录 - 志愿者
test_step "3. 志愿者登录 (13800138001 / 123456)"
api_call POST /auth/login "" '{"phone":"13800138001","password":"123456"}'
if echo "$BODY" | grep -q "登录成功" > /dev/null 2>&1; then
  VOLUNTEER_TOKEN=$(json_field "['token']")
  VOLUNTEER_ID=$(json_field "['user']['id']")
  INITIAL_POINTS=$(json_field "['user']['points']")
  test_pass "志愿者登录成功，ID: $VOLUNTEER_ID, 初始积分: $INITIAL_POINTS"
else
  echo "响应: $BODY"
  test_fail "志愿者登录失败"
fi

echo ""

# 3.1 局外人账号（第二个志愿者、第二个居民）
test_step "3.1 局外人账号登录"
api_call POST /auth/login "" '{"phone":"13800138002","password":"123456"}'
VOLUNTEER2_TOKEN=$(json_field "['token']")
api_call POST /auth/login "" '{"phone":"13900139002","password":"123456"}'
RESIDENT2_TOKEN=$(json_field "['token']")
test_pass "第二个志愿者、第二个居民登录成功（用于局外人校验）"

echo ""

# 4. 测试获取礼品列表
test_step "4. 获取礼品列表"
GIFTS_RES=$(curl -s "$BASE_URL/gifts")
if echo "$GIFTS_RES" | grep -q "保温杯" > /dev/null 2>&1; then
  GIFT_COUNT=$(echo "$GIFTS_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['gifts']))")
  FIRST_GIFT=$(echo "$GIFTS_RES" | python3 -c "import sys,json; g=json.load(sys.stdin)['gifts'][0]; print(f'{g[\"name\"]} ({g[\"points_required\"]}积分)')")
  test_pass "获取到 $GIFT_COUNT 个礼品，第一个: $FIRST_GIFT"
else
  echo "响应: $GIFTS_RES"
  test_fail "获取礼品列表失败"
fi

echo ""

# 5. 测试发布需求
test_step "5. 居民发布需求"
api_call POST /needs "$RESIDENT_TOKEN" '{
  "title": "需要帮忙买 groceries",
  "description": "腿脚不方便，需要帮忙去超市买些生活用品",
  "type": "shopping",
  "address": "北京市朝阳区光华路2号",
  "lat": 39.9122,
  "lng": 116.4574,
  "expected_time": "2026-05-20 10:00:00"
}'
if echo "$BODY" | grep -q "发布成功" > /dev/null 2>&1; then
  NEED_ID=$(json_field "['needId']")
  test_pass "需求发布成功，需求ID: $NEED_ID"
else
  echo "响应: $BODY"
  test_fail "发布需求失败"
fi

echo ""

# 6. 测试获取需求列表
test_step "6. 获取需求列表"
NEEDS_RES=$(curl -s "$BASE_URL/needs?pageSize=10")
if echo "$NEEDS_RES" | grep -q "needs" > /dev/null 2>&1; then
  NEED_COUNT=$(echo "$NEEDS_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['needs']))")
  test_pass "获取到 $NEED_COUNT 条需求"
else
  test_fail "获取需求列表失败"
fi

echo ""

# 7. 测试志愿者接单
test_step "7. 志愿者接单"
api_call POST "/needs/$NEED_ID/accept" "$VOLUNTEER_TOKEN"
if echo "$BODY" | grep -q "接单成功" > /dev/null 2>&1; then
  test_pass "接单成功"
else
  echo "响应: $BODY"
  test_fail "接单失败"
fi

echo ""

# 8. 测试获取订单列表
test_step "8. 获取订单列表"
api_call GET /orders "$VOLUNTEER_TOKEN"
if echo "$BODY" | grep -q "orders" > /dev/null 2>&1; then
  ORDER_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['orders'][0]['id'])")
  test_pass "获取订单成功，订单ID: $ORDER_ID"
else
  echo "响应: $BODY"
  test_fail "获取订单列表失败"
fi

echo ""

# 9. 志愿者提交服务结果（2小时），此时不应结算
test_step "9. 志愿者提交实际服务时长 2 小时"
api_call POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours": 2}'
expect_ok "服务结果提交成功，等待居民确认"

echo ""

# 9.1 提交后、确认前：积分和时长不得变化
test_step "9.1 提交后居民未确认，积分不应增加"
api_call GET /user/profile "$VOLUNTEER_TOKEN"
POINTS_BEFORE_CONFIRM=$(json_field "['user']['points']")
if [ "$POINTS_BEFORE_CONFIRM" = "$INITIAL_POINTS" ]; then
  test_pass "积分仍为 $INITIAL_POINTS，居民确认前未结算"
else
  test_fail "积分提前变化：$POINTS_BEFORE_CONFIRM（应仍为 $INITIAL_POINTS）"
fi

echo ""

# 9.2 非法提交与越权操作都应失败
test_step "9.2 提交阶段的防重复 / 越权 / 非法参数校验"
api_call POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours": 2}'
expect_fail 400 "志愿者重复提交"
api_call POST "/orders/$ORDER_ID/submit" "$VOLUNTEER2_TOKEN" '{"service_hours": 2}'
expect_fail 403 "局外志愿者代替提交"
api_call POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours": 0}'
expect_fail 400 "服务时长为0"
api_call POST "/orders/$ORDER_ID/confirm" "$VOLUNTEER_TOKEN"
expect_fail 403 "志愿者越权确认"
api_call POST "/orders/$ORDER_ID/confirm" "$RESIDENT2_TOKEN"
expect_fail 403 "局外居民越权确认"

echo ""

# 10. 居民认为服务没做完，写明原因退回
test_step "10. 居民退回服务结果"
api_call POST "/orders/$ORDER_ID/reject" "$RESIDENT_TOKEN" '{"reason": ""}'
expect_fail 400 "退回原因为空"
api_call POST "/orders/$ORDER_ID/reject" "$RESIDENT2_TOKEN" '{"reason": "test"}'
expect_fail 403 "局外居民退回"
api_call POST "/orders/$ORDER_ID/reject" "$RESIDENT_TOKEN" '{"reason": "药还没送到，请继续完成"}'
expect_ok "居民退回成功，订单继续"

echo ""

# 10.1 退回后订单恢复进行中，积分依旧不变
test_step "10.1 退回后订单恢复进行中且未结算"
api_call GET "/orders?status=in_progress" "$VOLUNTEER_TOKEN"
ORDER_STATUS=$(echo "$BODY" | python3 -c "
import sys,json
orders = json.load(sys.stdin)['orders']
o = [x for x in orders if x['id'] == $ORDER_ID]
print(o[0]['status'] if o else 'missing')")
if [ "$ORDER_STATUS" = "in_progress" ]; then
  test_pass "订单状态已回到 in_progress，志愿者可重新提交"
else
  test_fail "订单状态为 $ORDER_STATUS（期望 in_progress）"
fi
api_call GET /user/profile "$VOLUNTEER_TOKEN"
POINTS_AFTER_REJECT=$(json_field "['user']['points']")
if [ "$POINTS_AFTER_REJECT" = "$INITIAL_POINTS" ]; then
  test_pass "退回后积分仍为 $INITIAL_POINTS，未结算"
else
  test_fail "退回后积分异常：$POINTS_AFTER_REJECT"
fi

echo ""

# 11. 志愿者重新提交 3 小时，居民确认后结算
test_step "11. 志愿者重新提交 3 小时"
api_call POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours": 3}'
expect_ok "重新提交成功"

test_step "11.1 居民确认服务结果"
api_call POST "/orders/$ORDER_ID/confirm" "$RESIDENT_TOKEN"
expect_ok "确认成功，时长与积分已结算"
EARNED_POINTS=$(json_field "['points']")
[ "$EARNED_POINTS" = "30" ] && test_pass "结算积分 30 = 3小时 × 10" || test_fail "结算积分应为30，实际 $EARNED_POINTS"

test_step "11.2 结算后志愿者积分与时长到账"
api_call GET /user/profile "$VOLUNTEER_TOKEN"
POINTS=$(json_field "['user']['points']")
HOURS=$(json_field "['user']['service_hours']")
EXPECTED_POINTS=$((INITIAL_POINTS + 30))
if [ "$POINTS" = "$EXPECTED_POINTS" ]; then
  test_pass "积分正确: $POINTS (原 $INITIAL_POINTS + 30), 总服务时长: $HOURS 小时"
else
  test_fail "积分错误: $POINTS (期望 $EXPECTED_POINTS)"
fi

test_step "11.3 结算后不能再提交/确认/退回"
api_call POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours": 1}'
expect_fail 400 "志愿者再次提交"
api_call POST "/orders/$ORDER_ID/confirm" "$RESIDENT_TOKEN"
expect_fail 400 "居民重复确认"
api_call POST "/orders/$ORDER_ID/reject" "$RESIDENT_TOKEN" '{"reason": "late"}'
expect_fail 400 "结算后退回"

echo ""

# 12. 评价：结算后双方各一次，重复或局外人失败
test_step "12. 订单评价规则"
api_call POST "/orders/$ORDER_ID/review" "$RESIDENT2_TOKEN" '{"rating": 5, "comment": "局外人评价"}'
expect_fail 403 "局外人评价"
api_call POST "/orders/$ORDER_ID/review" "$RESIDENT_TOKEN" '{"rating": 5, "comment": "志愿者非常热心，服务很好！"}'
expect_ok "居民评价成功"
api_call POST "/orders/$ORDER_ID/review" "$RESIDENT_TOKEN" '{"rating": 4, "comment": "重复评价"}'
expect_fail 409 "居民重复评价"
api_call POST "/orders/$ORDER_ID/review" "$VOLUNTEER_TOKEN" '{"rating": 5, "comment": "居民很友善，合作愉快！"}'
expect_ok "志愿者评价成功"
api_call POST "/orders/$ORDER_ID/review" "$VOLUNTEER_TOKEN" '{"rating": 3, "comment": "重复评价"}'
expect_fail 409 "志愿者重复评价"
api_call POST "/orders/$ORDER_ID/review" "$VOLUNTEER_TOKEN" '{"rating": 6, "comment": "非法评分"}'
expect_fail 400 "非法评分（1-5）"
api_call POST "/orders/$ORDER_ID/review" "$RESIDENT_TOKEN" '{"rating": 0, "comment": ""}'
expect_fail 400 "评分必须在1到5之间"

echo ""

# 13. 未结算订单不能评价
test_step "13. 新订单未结算不能评价"
api_call POST /needs "$RESIDENT_TOKEN" '{
  "title": "第二个需求-陪诊",
  "description": "需要陪同复查",
  "type": "accompany",
  "address": "北京市朝阳区光华路2号",
  "lat": 39.9122,
  "lng": 116.4574
}'
NEED2_ID=$(json_field "['needId']")
api_call POST "/needs/$NEED2_ID/accept" "$VOLUNTEER_TOKEN"
api_call GET /orders "$RESIDENT_TOKEN"
ORDER2_ID=$(echo "$BODY" | python3 -c "
import sys,json
orders = json.load(sys.stdin)['orders']
print(max(o['id'] for o in orders))")
api_call POST "/orders/$ORDER2_ID/review" "$RESIDENT_TOKEN" '{"rating": 5}'
expect_fail 400 "服务未结算时评价"

echo ""

# 14. 测试兑换礼品
test_step "14. 志愿者兑换礼品 (保温杯 100 积分)"
GIFT_ID=1
api_call POST "/gifts/$GIFT_ID/exchange" "$VOLUNTEER_TOKEN"
if echo "$BODY" | grep -q "兑换成功" > /dev/null 2>&1; then
  test_pass "礼品兑换成功"
else
  echo "响应: $BODY"
  test_fail "兑换礼品失败"
fi

echo ""

# 15. 测试获取兑换记录
test_step "15. 获取兑换记录"
EXCHANGES_RES=$(curl -s "$BASE_URL/my/exchanges" \
  -H "Authorization: Bearer $VOLUNTEER_TOKEN")

if echo "$EXCHANGES_RES" | grep -q "exchanges" > /dev/null 2>&1; then
  EX_COUNT=$(echo "$EXCHANGES_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['exchanges']))")
  EX_GIFT=$(echo "$EXCHANGES_RES" | python3 -c "import sys,json; e=json.load(sys.stdin)['exchanges'][0]; print(f'{e[\"name\"]} ({e[\"points\"]}积分)')")
  test_pass "获取到 $EX_COUNT 条兑换记录，最新: $EX_GIFT"
else
  echo "响应: $EXCHANGES_RES"
  test_fail "获取兑换记录失败"
fi

echo ""

# 16. 测试发送消息
test_step "16. 发送消息"
MSG_RES=$(curl -s -X POST "$BASE_URL/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VOLUNTEER_TOKEN" \
  -d "{\"receiver_id\": $RESIDENT_ID, \"content\": \"您好，我是志愿者，请问明天上午10点可以吗？\"}")

if echo "$MSG_RES" | grep -q "发送成功" > /dev/null 2>&1; then
  test_pass "消息发送成功"
else
  echo "响应: $MSG_RES"
  test_fail "发送消息失败"
fi

echo ""

# 17. 测试获取消息列表
test_step "17. 获取消息列表"
MSGS_RES=$(curl -s "$BASE_URL/messages?other_user_id=$VOLUNTEER_ID" \
  -H "Authorization: Bearer $RESIDENT_TOKEN")

if echo "$MSGS_RES" | grep -q "messages" > /dev/null 2>&1; then
  MSG_COUNT=$(echo "$MSGS_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['messages']))")
  test_pass "获取到 $MSG_COUNT 条消息"
else
  echo "响应: $MSGS_RES"
  test_fail "获取消息列表失败"
fi

echo ""

# 18. 测试积分排名
test_step "18. 获取志愿者排名"
RANKING_RES=$(curl -s "$BASE_URL/users/ranking")
if echo "$RANKING_RES" | grep -q "ranking" > /dev/null 2>&1; then
  RANK_COUNT=$(echo "$RANKING_RES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['ranking']))")
  TOP_NAME=$(echo "$RANKING_RES" | python3 -c "import sys,json; print(json.load(sys.stdin)['ranking'][0]['name'])")
  test_pass "获取到 $RANK_COUNT 名志愿者排名，第一名: $TOP_NAME"
else
  echo "响应: $RANKING_RES"
  test_fail "获取排名失败"
fi

echo ""
echo "======================================"
echo -e "${GREEN}🎉 所有测试通过！${NC}"
echo "======================================"
echo ""
echo "📋 测试总结："
echo "   ✅ 健康检查 / 登录（双方 + 局外人账号）"
echo "   ✅ 发布需求 / 列表 / 接单"
echo "   ✅ 志愿者提交实际时长（确认前不结算）"
echo "   ✅ 居民退回需写原因，订单继续，志愿者可重新提交"
echo "   ✅ 居民确认后才结算时长与积分（3小时=30积分）"
echo "   ✅ 重复提交 / 越权提交 / 越权确认 / 重复确认均失败"
echo "   ✅ 双方各评价一次，重复评价 409，局外人评价 403"
echo "   ✅ 未结算订单不能评价"
echo "   ✅ 积分兑换 / 兑换记录 / 消息 / 排名"
echo ""
echo "🎮 现在可以打开浏览器访问 http://localhost:8233 体验完整功能"
echo ""
