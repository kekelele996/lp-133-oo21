<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-6">我的订单</h1>

      <el-card class="mb-6">
        <el-tabs v-model="activeTab" @tab-change="fetchOrders">
          <el-tab-pane label="进行中" name="in_progress" />
          <el-tab-pane v-if="user?.role === 'resident'" label="待确认" name="submitted" />
          <el-tab-pane label="已完成" name="completed" />
          <el-tab-pane label="全部" name="" />
        </el-tabs>
      </el-card>

      <div v-if="loading" class="text-center py-16">
        <el-icon class="animate-spin text-4xl text-gray-400"><Loading /></el-icon>
      </div>

      <div v-else-if="orders.length === 0" class="text-center py-16">
        <el-icon class="text-6xl text-gray-300"><Document /></el-icon>
        <p class="mt-4 text-gray-500">暂无订单</p>
      </div>

      <div v-else class="space-y-4">
        <el-card v-for="order in orders" :key="order.id" class="hover:shadow-md">
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="flex items-center mb-2">
                <h3 class="font-medium text-lg mr-3">{{ order.title }}</h3>
                <el-tag :type="getTypeColor(order.type)" size="small">
                  {{ getTypeName(order.type) }}
                </el-tag>
                <el-tag v-if="order.status === 'in_progress'" type="warning" class="ml-2" size="small">进行中</el-tag>
                <el-tag v-else-if="order.status === 'submitted'" type="primary" class="ml-2" size="small">待居民确认</el-tag>
                <el-tag v-else-if="order.status === 'completed'" type="success" class="ml-2" size="small">已完成</el-tag>
              </div>

              <div class="text-gray-600 text-sm mb-3">
                <p v-if="user?.role === 'volunteer'">
                  <el-icon class="mr-1"><User /></el-icon>
                  服务对象：{{ order.user_name }}
                </p>
                <p v-else>
                  <el-icon class="mr-1"><Service /></el-icon>
                  志愿者：{{ order.volunteer_name }}
                </p>
                <p class="mt-1">
                  <el-icon class="mr-1"><Location /></el-icon>
                  {{ order.address }}
                </p>
                <p v-if="Number(order.service_hours) > 0" class="mt-1">
                  <el-icon class="mr-1"><Clock /></el-icon>
                  实际服务时长：{{ order.service_hours }} 小时
                  <span v-if="order.status === 'submitted'" class="text-gray-400">（待居民确认）</span>
                </p>
                <el-alert
                  v-if="order.reject_reason"
                  class="mt-2"
                  type="error"
                  :closable="false"
                  show-icon
                  title="服务结果被退回"
                  :description="order.reject_reason"
                />
              </div>

              <div class="text-xs text-gray-400">
                下单时间：{{ new Date(order.created_at).toLocaleString() }}
              </div>
            </div>

            <div class="flex flex-col gap-2">
              <!-- 志愿者：服务中填写实际时长并提交 -->
              <el-button
                v-if="user?.role === 'volunteer' && order.status === 'in_progress'"
                type="primary"
                size="small"
                @click="openSubmitDialog(order)"
              >
                提交服务结果
              </el-button>
              <el-button
                v-if="user?.role === 'volunteer' && order.status === 'submitted'"
                type="primary"
                size="small"
                disabled
              >
                等待居民确认
              </el-button>
              <!-- 居民：查看结果后确认或退回 -->
              <template v-if="user?.role === 'resident' && order.status === 'submitted'">
                <el-button type="success" size="small" @click="handleConfirm(order)">
                  确认完成
                </el-button>
                <el-button type="danger" size="small" @click="openRejectDialog(order)">
                  退回
                </el-button>
              </template>
              <el-button
                v-if="order.status === 'completed' && !hasReviewed(order)"
                type="success"
                size="small"
                @click="showReviewDialog(order)"
              >
                去评价
              </el-button>
              <el-button
                type="text"
                size="small"
                @click="handleMessage(order)"
              >
                <el-icon class="mr-1"><ChatDotRound /></el-icon>
                发消息
              </el-button>
            </div>
          </div>
        </el-card>
      </div>
    </div>

    <!-- 志愿者提交实际服务时长 -->
    <el-dialog v-model="submitDialogVisible" title="提交服务结果" width="460px">
      <el-form label-width="100px">
        <el-form-item label="实际服务时长">
          <el-input-number
            v-model="submitForm.service_hours"
            :min="0.5"
            :max="99"
            :step="0.5"
            :precision="2"
          />
          <span class="ml-2 text-gray-500 text-sm">小时</span>
        </el-form-item>
        <p class="text-xs text-gray-400 pl-2">提交后由居民确认，确认后才会计入时长和积分。</p>
      </el-form>
      <template #footer>
        <el-button @click="submitDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitService">提交</el-button>
      </template>
    </el-dialog>

    <!-- 居民填写退回原因 -->
    <el-dialog v-model="rejectDialogVisible" title="退回服务结果" width="460px">
      <el-form label-width="80px">
        <el-form-item label="退回原因">
          <el-input
            v-model="rejectForm.reason"
            type="textarea"
            :rows="4"
            maxlength="500"
            show-word-limit
            placeholder="请说明服务没做完的地方，志愿者将继续服务后重新提交"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="rejectDialogVisible = false">取消</el-button>
        <el-button type="danger" :loading="submitting" @click="submitReject">确认退回</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="reviewDialogVisible" title="服务评价" width="500px">
      <el-form :model="reviewForm" label-width="80px">
        <el-form-item label="评分">
          <el-rate v-model="reviewForm.rating" :max="5" show-score />
        </el-form-item>
        <el-form-item label="评价内容">
          <el-input v-model="reviewForm.comment" type="textarea" :rows="3" placeholder="请输入评价内容" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="reviewDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="submittingReview" @click="submitReview">提交评价</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import api from '@/utils/api'
import { ElMessage, ElMessageBox } from 'element-plus'

const router = useRouter()
const userStore = useUserStore()
const user = computed(() => userStore.user)

const orders = ref([])
const loading = ref(false)
const activeTab = ref('in_progress')

const submitDialogVisible = ref(false)
const rejectDialogVisible = ref(false)
const reviewDialogVisible = ref(false)
const submitting = ref(false)
const submittingReview = ref(false)

const currentOrder = ref(null)
const submitForm = ref({ service_hours: 1 })
const rejectForm = ref({ reason: '' })
const reviewForm = ref({ rating: 5, comment: '' })

const typeMap = {
  accompany: { name: '陪聊陪诊', color: 'blue' },
  shopping: { name: '代买代办', color: 'green' },
  repair: { name: '家电维修', color: 'orange' },
  housework: { name: '家政服务', color: 'purple' },
  other: { name: '其他帮助', color: 'gray' }
}

const getTypeName = (type) => typeMap[type]?.name || type
const getTypeColor = (type) => typeMap[type]?.color || 'info'

const hasReviewed = (order) => Number(order.my_review_count) > 0

const fetchOrders = async () => {
  loading.value = true
  try {
    const params = activeTab.value ? { status: activeTab.value } : {}
    const res = await api.get('/orders', { params })
    orders.value = res.data.orders
  } finally {
    loading.value = false
  }
}

// 志愿者填写实际时长并提交
const openSubmitDialog = (order) => {
  currentOrder.value = order
  submitForm.value = { service_hours: Number(order.service_hours) > 0 ? Number(order.service_hours) : 1 }
  submitDialogVisible.value = true
}

const submitService = async () => {
  try {
    submitting.value = true
    await api.post(`/orders/${currentOrder.value.id}/submit`, {
      service_hours: submitForm.value.service_hours
    })
    ElMessage.success('服务结果已提交，等待居民确认')
    submitDialogVisible.value = false
    fetchOrders()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '提交失败')
  } finally {
    submitting.value = false
  }
}

// 居民确认：确认后结算时长和积分
const handleConfirm = async (order) => {
  try {
    await ElMessageBox.confirm(
      `志愿者提交的实际服务时长为 ${order.service_hours} 小时，确认服务已完成吗？确认后将为志愿者结算时长和积分。`,
      '确认服务结果',
      {
        confirmButtonText: '确认完成',
        cancelButtonText: '取消',
        type: 'success'
      }
    )

    await api.post(`/orders/${order.id}/confirm`)
    ElMessage.success('已确认，服务时长和积分已结算')
    fetchOrders()
    userStore.fetchUserInfo()
  } catch (e) {
    if (e !== 'cancel') {
      ElMessage.error(e.response?.data?.message || '操作失败')
    }
  }
}

// 居民写明原因退回，订单继续
const openRejectDialog = (order) => {
  currentOrder.value = order
  rejectForm.value = { reason: '' }
  rejectDialogVisible.value = true
}

const submitReject = async () => {
  if (!rejectForm.value.reason.trim()) {
    ElMessage.warning('请填写退回原因')
    return
  }
  try {
    submitting.value = true
    await api.post(`/orders/${currentOrder.value.id}/reject`, {
      reason: rejectForm.value.reason
    })
    ElMessage.success('已退回，志愿者可继续服务后重新提交')
    rejectDialogVisible.value = false
    fetchOrders()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '退回失败')
  } finally {
    submitting.value = false
  }
}

const showReviewDialog = (order) => {
  currentOrder.value = order
  reviewForm.value = { rating: 5, comment: '' }
  reviewDialogVisible.value = true
}

const submitReview = async () => {
  try {
    submittingReview.value = true
    await api.post(`/orders/${currentOrder.value.id}/review`, reviewForm.value)
    ElMessage.success('评价成功')
    reviewDialogVisible.value = false
    fetchOrders()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '评价失败')
  } finally {
    submittingReview.value = false
  }
}

const handleMessage = (order) => {
  const otherUserId = user.value.role === 'volunteer' ? order.user_id : order.volunteer_id
  router.push({
    path: '/messages',
    query: { userId: otherUserId }
  })
}

onMounted(() => {
  fetchOrders()
})
</script>
