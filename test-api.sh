#!/bin/bash

echo "======================================"
echo "  志愿者互助平台 - API 全流程测试"
echo " (提交-确认结算-退回重做-评价权限)"
echo "======================================"
echo ""

BASE_URL="http://localhost:3233/api"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 全局变量
VOLUNTEER_TOKEN=""
VOLUNTEER2_TOKEN=""
RESIDENT_TOKEN=""
RESIDENT2_TOKEN=""
VOLUNTEER_ID=""
RESIDENT_ID=""
NEED_ID=""
ORDER_ID=""
NEED2_ID=""
ORDER2_ID=""
INITIAL_POINTS=0
INITIAL_HOURS=0

test_step() {
  echo -e "${YELLOW}▶ $1${NC}"
}

test_pass() {
  echo -e "${GREEN}  ✓ $1${NC}"
}

test_fail() {
  echo -e "${RED}  ✗ $1${NC}"
  echo -e "${RED}    响应: $2${NC}"
  exit 1
}

# 请求并断言 HTTP 状态码
# 用法: assert_status <方法> <路径> <token> <数据json> <期望状态码> <说明>
assert_status() {
  local method="$1" path="$2" token="$3" data="$4" expect="$5" desc="$6"
  local args=(-s -o /tmp/api_body -w "%{http_code}" -X "$method")
  args+=(-H "Content-Type: application/json")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$data" ] && args+=(-d "$data")
  local code
  code=$(curl "${args[@]}" "$BASE_URL$path")
  local body
  body=$(cat /tmp/api_body)
  if [ "$code" = "$expect" ]; then
    test_pass "$desc (HTTP $code)"
  else
    test_fail "$desc，预期 HTTP $expect，实际 HTTP $code" "$body"
  fi
  LAST_BODY="$body"
}

json_get() {
  echo "$1" | python3 -c "import sys,json; print(json.load(sys.stdin)$2)"
}

json_has() {
  echo "$1" | grep -q "$2"
}

# 1. 测试健康检查
test_step "1. 健康检查"
HEALTH_RES=$(curl -s "$BASE_URL/health")
if echo "$HEALTH_RES" | grep -q "ok" > /dev/null 2>&1; then
  test_pass "后端服务正常 - $(echo $HEALTH_RES | python3 -c "import sys,json; print(json.load(sys.stdin)['message'])")"
else
  test_fail "后端服务未启动，请先运行 ./start-all.sh" "$HEALTH_RES"
fi

echo ""

# 2. 测试登录 - 居民
test_step "2. 居民登录 (13900139001 / 123456)"
LOGIN_RES=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13900139001","password":"123456"}')

if json_has "$LOGIN_RES" "登录成功"; then
  RESIDENT_TOKEN=$(json_get "$LOGIN_RES" "['token']")
  RESIDENT_ID=$(json_get "$LOGIN_RES" "['user']['id']")
  test_pass "居民登录成功，ID: $RESIDENT_ID"
else
  test_fail "居民登录失败" "$LOGIN_RES"
fi

echo ""

# 3. 测试登录 - 志愿者
test_step "3. 志愿者登录 (13800138001 / 123456)"
LOGIN_RES=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138001","password":"123456"}')

if json_has "$LOGIN_RES" "登录成功"; then
  VOLUNTEER_TOKEN=$(json_get "$LOGIN_RES" "['token']")
  VOLUNTEER_ID=$(json_get "$LOGIN_RES" "['user']['id']")
  INITIAL_POINTS=$(json_get "$LOGIN_RES" "['user']['points']")
  INITIAL_HOURS=$(json_get "$LOGIN_RES" "['user']['service_hours']")
  test_pass "志愿者登录成功，ID: $VOLUNTEER_ID, 初始积分: $INITIAL_POINTS, 时长: $INITIAL_HOURS"
else
  test_fail "志愿者登录失败" "$LOGIN_RES"
fi

# 3.1 局外人账号（另一名居民 + 另一名志愿者）
LOGIN_RES=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13900139002","password":"123456"}')
RESIDENT2_TOKEN=$(json_get "$LOGIN_RES" "['token']")
LOGIN_RES=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138002","password":"123456"}')
VOLUNTEER2_TOKEN=$(json_get "$LOGIN_RES" "['token']")
test_pass "局外人账号登录成功"

echo ""

# 4. 测试获取礼品列表
test_step "4. 获取礼品列表"
GIFTS_RES=$(curl -s "$BASE_URL/gifts")
if json_has "$GIFTS_RES" "保温杯"; then
  GIFT_COUNT=$(json_get "$GIFTS_RES" "['gifts'].__len__()")
  test_pass "获取到 $GIFT_COUNT 个礼品"
else
  test_fail "获取礼品列表失败" "$GIFTS_RES"
fi

echo ""

# 5. 测试发布需求
test_step "5. 居民发布需求"
PUBLISH_RES=$(curl -s -X POST "$BASE_URL/needs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $RESIDENT_TOKEN" \
  -d '{
    "title": "需要帮忙买 groceries",
    "description": "腿脚不方便，需要帮忙去超市买些生活用品",
    "type": "shopping",
    "address": "北京市朝阳区光华路2号",
    "lat": 39.9122,
    "lng": 116.4574,
    "expected_time": "2026-05-20 10:00:00"
  }')

if json_has "$PUBLISH_RES" "发布成功"; then
  NEED_ID=$(json_get "$PUBLISH_RES" "['needId']")
  test_pass "需求发布成功，需求ID: $NEED_ID"
else
  test_fail "发布需求失败" "$PUBLISH_RES"
fi

# 第二个需求，用于评价权限测试
PUBLISH_RES=$(curl -s -X POST "$BASE_URL/needs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $RESIDENT_TOKEN" \
  -d '{"title": "第二个测试需求", "type": "other"}')
NEED2_ID=$(json_get "$PUBLISH_RES" "['needId']")
test_pass "第二个需求发布成功，需求ID: $NEED2_ID"

echo ""

# 6. 志愿者接单
test_step "6. 志愿者接单"
assert_status POST "/needs/$NEED_ID/accept" "$VOLUNTEER_TOKEN" "" 200 "志愿者接第一个需求"
assert_status POST "/needs/$NEED2_ID/accept" "$VOLUNTEER_TOKEN" "" 200 "志愿者接第二个需求"

ORDERS_RES=$(curl -s "$BASE_URL/orders" -H "Authorization: Bearer $VOLUNTEER_TOKEN")
ORDER_ID=$(echo "$ORDERS_RES" | python3 -c "
import sys,json
orders=json.load(sys.stdin)['orders']
print(next(o['id'] for o in orders if o['need_id']==$NEED_ID))")
ORDER2_ID=$(echo "$ORDERS_RES" | python3 -c "
import sys,json
orders=json.load(sys.stdin)['orders']
print(next(o['id'] for o in orders if o['need_id']==$NEED2_ID))")
test_pass "订单创建成功: $ORDER_ID, $ORDER2_ID"

echo ""

# 7. 提交服务结果前的权限/状态校验
test_step "7. 提交服务结果 - 权限与状态校验"
assert_status POST "/orders/$ORDER_ID/submit" "$RESIDENT_TOKEN" '{"service_hours":1}' 403 "居民不能代替志愿者提交"
assert_status POST "/orders/$ORDER_ID/submit" "$RESIDENT2_TOKEN" '{"service_hours":1}' 403 "局外人提交被拒绝"
assert_status POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours":0}' 400 "时长非法被拒绝"
assert_status POST "/orders/$ORDER_ID/confirm" "$VOLUNTEER_TOKEN" "" 403 "志愿者不能自行确认结算"

echo ""

# 8. 志愿者提交实际时长（第一次，时长 3 小时）
test_step "8. 志愿者提交实际时长 3 小时"
assert_status POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours":3}' 200 "提交成功，等待居民确认"
assert_status POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours":3}' 400 "待确认状态重复提交被拒绝"

# 提交后不应产生时长/积分
PROFILE_RES=$(curl -s "$BASE_URL/user/profile" -H "Authorization: Bearer $VOLUNTEER_TOKEN")
POINTS_NOW=$(json_get "$PROFILE_RES" "['user']['points']")
HOURS_NOW=$(json_get "$PROFILE_RES" "['user']['service_hours']")
if [ "$POINTS_NOW" = "$INITIAL_POINTS" ] && [ "$HOURS_NOW" = "$INITIAL_HOURS" ]; then
  test_pass "居民确认前不记入时长和积分 (积分 $POINTS_NOW, 时长 $HOURS_NOW)"
else
  test_fail "确认前不应记账 (积分 $POINTS_NOW/$INITIAL_POINTS, 时长 $HOURS_NOW/$INITIAL_HOURS)" "$PROFILE_RES"
fi

echo ""

# 9. 待确认状态的操作限制
test_step "9. 待确认状态操作限制"
assert_status POST "/orders/$ORDER_ID/confirm" "$RESIDENT2_TOKEN" "" 403 "局外人确认被拒绝"
assert_status POST "/orders/$ORDER_ID/reject" "$RESIDENT2_TOKEN" '{"reason":"x"}' 403 "局外人退回被拒绝"
assert_status POST "/orders/$ORDER_ID/reject" "$VOLUNTEER_TOKEN" '{"reason":"x"}' 403 "志愿者不能退回"
assert_status POST "/orders/$ORDER_ID/reject" "$RESIDENT_TOKEN" '{"reason":""}' 400 "退回必须写明原因"
assert_status POST "/orders/$ORDER_ID/review" "$RESIDENT_TOKEN" '{"rating":5}' 400 "结算前评价被拒绝"

echo ""

# 10. 居民退回（写明原因），订单继续
test_step "10. 居民退回：服务没做完"
assert_status POST "/orders/$ORDER_ID/reject" "$RESIDENT_TOKEN" \
  '{"reason":"药只买到一半，还差一种，请帮忙补齐"}' 200 "退回成功，订单继续"

ORDERS_RES=$(curl -s "$BASE_URL/orders?status=in_progress" -H "Authorization: Bearer $VOLUNTEER_TOKEN")
if echo "$ORDERS_RES" | python3 -c "
import sys,json
orders=json.load(sys.stdin)['orders']
o=next(x for x in orders if x['id']==$ORDER_ID)
assert o['reject_reason'], '退回原因未保存'
sys.exit(0)"; then
  test_pass "订单回到进行中，退回原因已保存"
else
  test_fail "退回后订单状态或原因不正确" "$ORDERS_RES"
fi

# 退回时仍未记账
PROFILE_RES=$(curl -s "$BASE_URL/user/profile" -H "Authorization: Bearer $VOLUNTEER_TOKEN")
POINTS_NOW=$(json_get "$PROFILE_RES" "['user']['points']")
if [ "$POINTS_NOW" = "$INITIAL_POINTS" ]; then
  test_pass "退回后仍未记入积分"
else
  test_fail "退回后不应记入积分 ($POINTS_NOW/$INITIAL_POINTS)" "$PROFILE_RES"
fi

echo ""

# 11. 志愿者重新提交（实际时长 2 小时）
test_step "11. 志愿者重新提交实际时长 2 小时"
assert_status POST "/orders/$ORDER_ID/submit" "$VOLUNTEER_TOKEN" '{"service_hours":2}' 200 "重新提交成功"

echo ""

# 12. 居民确认，结算
test_step "12. 居民确认结算"
assert_status POST "/orders/$ORDER_ID/confirm" "$RESIDENT_TOKEN" "" 200 "确认成功"
assert_status POST "/orders/$ORDER_ID/confirm" "$RESIDENT_TOKEN" "" 400 "重复确认被拒绝"

PROFILE_RES=$(curl -s "$BASE_URL/user/profile" -H "Authorization: Bearer $VOLUNTEER_TOKEN")
POINTS_NOW=$(json_get "$PROFILE_RES" "['user']['points']")
HOURS_NOW=$(json_get "$PROFILE_RES" "['user']['service_hours']")
EXPECTED_POINTS=$((INITIAL_POINTS + 20))
EXPECTED_HOURS=$(python3 -c "print($INITIAL_HOURS + 2)")
if [ "$POINTS_NOW" = "$EXPECTED_POINTS" ] && [ "$HOURS_NOW" = "$EXPECTED_HOURS" ]; then
  test_pass "结算正确: 时长 +2 (=$HOURS_NOW), 积分 +20 (=$POINTS_NOW)"
else
  test_fail "结算数值不对: 积分 $POINTS_NOW/$EXPECTED_POINTS, 时长 $HOURS_NOW/$EXPECTED_HOURS" "$PROFILE_RES"
fi

NEED_RES=$(curl -s "$BASE_URL/needs/$NEED_ID")
NEED_STATUS=$(json_get "$NEED_RES" "['need']['status']")
if [ "$NEED_STATUS" = "completed" ]; then
  test_pass "关联需求已标记完成"
else
  test_fail "需求状态应为 completed，实际 $NEED_STATUS" "$NEED_RES"
fi

echo ""

# 13. 结算后双方各评价一次
test_step "13. 双方评价 + 重复/局外人评价失败"
assert_status POST "/orders/$ORDER_ID/review" "$RESIDENT2_TOKEN" '{"rating":5}' 403 "局外人评价被拒绝"
assert_status POST "/orders/$ORDER_ID/review" "$VOLUNTEER2_TOKEN" '{"rating":5}' 403 "非本单志愿者评价被拒绝"
assert_status POST "/orders/$ORDER_ID/review" "$RESIDENT_TOKEN" '{"rating":5,"comment":"志愿者非常热心，服务很好！"}' 200 "居民评价成功"
assert_status POST "/orders/$ORDER_ID/review" "$RESIDENT_TOKEN" '{"rating":4}' 409 "居民重复评价被拒绝"
assert_status POST "/orders/$ORDER_ID/review" "$VOLUNTEER_TOKEN" '{"rating":5,"comment":"居民很友善，合作愉快！"}' 200 "志愿者评价成功"
assert_status POST "/orders/$ORDER_ID/review" "$VOLUNTEER_TOKEN" '{"rating":3}' 409 "志愿者重复评价被拒绝"
assert_status POST "/orders/$ORDER_ID/review" "$VOLUNTEER_TOKEN" '{"rating":9}' 400 "非法评分被拒绝"

ORDERS_RES=$(curl -s "$BASE_URL/orders?status=completed" -H "Authorization: Bearer $RESIDENT_TOKEN")
if echo "$ORDERS_RES" | python3 -c "
import sys,json
orders=json.load(sys.stdin)['orders']
o=next(x for x in orders if x['id']==$ORDER_ID)
assert o['reviewed']==1, 'reviewed 标记不正确'
sys.exit(0)"; then
  test_pass "订单列表正确返回已评价标记"
else
  test_fail "reviewed 标记不正确" "$ORDERS_RES"
fi

# 未结算订单不能评价
assert_status POST "/orders/$ORDER2_ID/review" "$RESIDENT_TOKEN" '{"rating":5}' 400 "未结算订单评价被拒绝"

echo ""

# 14. 测试兑换礼品
test_step "14. 志愿者兑换礼品 (保温杯 100 积分)"
GIFT_ID=1
EXCHANGE_RES=$(curl -s -X POST "$BASE_URL/gifts/$GIFT_ID/exchange" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VOLUNTEER_TOKEN")

if json_has "$EXCHANGE_RES" "兑换成功"; then
  test_pass "礼品兑换成功"
else
  test_fail "兑换礼品失败" "$EXCHANGE_RES"
fi

echo ""

# 15. 测试获取兑换记录
test_step "15. 获取兑换记录"
EXCHANGES_RES=$(curl -s "$BASE_URL/my/exchanges" \
  -H "Authorization: Bearer $VOLUNTEER_TOKEN")

if json_has "$EXCHANGES_RES" "exchanges"; then
  EX_COUNT=$(json_get "$EXCHANGES_RES" "['exchanges'].__len__()")
  test_pass "获取到 $EX_COUNT 条兑换记录"
else
  test_fail "获取兑换记录失败" "$EXCHANGES_RES"
fi

echo ""

# 16. 测试发送消息
test_step "16. 发送消息"
MSG_RES=$(curl -s -X POST "$BASE_URL/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VOLUNTEER_TOKEN" \
  -d "{\"receiver_id\": $RESIDENT_ID, \"content\": \"您好，我是志愿者，请问明天上午10点可以吗？\"}")

if json_has "$MSG_RES" "发送成功"; then
  test_pass "消息发送成功"
else
  test_fail "发送消息失败" "$MSG_RES"
fi

echo ""

# 17. 测试获取消息列表
test_step "17. 获取消息列表"
MSGS_RES=$(curl -s "$BASE_URL/messages?other_user_id=$VOLUNTEER_ID" \
  -H "Authorization: Bearer $RESIDENT_TOKEN")

if json_has "$MSGS_RES" "messages"; then
  MSG_COUNT=$(json_get "$MSGS_RES" "['messages'].__len__()")
  test_pass "获取到 $MSG_COUNT 条消息"
else
  test_fail "获取消息列表失败" "$MSGS_RES"
fi

echo ""

# 18. 测试积分排名
test_step "18. 获取志愿者排名"
RANKING_RES=$(curl -s "$BASE_URL/users/ranking")
if json_has "$RANKING_RES" "ranking"; then
  RANK_COUNT=$(json_get "$RANKING_RES" "['ranking'].__len__()")
  TOP_NAME=$(json_get "$RANKING_RES" "['ranking'][0]['name']")
  test_pass "获取到 $RANK_COUNT 名志愿者排名，第一名: $TOP_NAME"
else
  test_fail "获取排名失败" "$RANKING_RES"
fi

echo ""
echo "======================================"
echo -e "${GREEN}🎉 所有测试通过！${NC}"
echo "======================================"
echo ""
echo "📋 测试总结："
echo "   ✅ 用户登录（居民 + 志愿者 + 局外人账号）"
echo "   ✅ 发布需求 / 接单"
echo "   ✅ 志愿者提交实际时长（居民确认前不记账）"
echo "   ✅ 居民写明原因退回，订单继续，志愿者重新提交"
echo "   ✅ 居民确认后才记入时长(+2h)和积分(+20)"
echo "   ✅ 双方各评价一次，重复评价/局外人评价失败"
echo "   ✅ 积分兑换、消息、排名"
echo ""
echo "🎮 现在可以打开浏览器访问 http://localhost:8233 体验完整功能"
echo ""
