<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6">
      <div v-if="loading" class="text-center py-16">
        <el-icon class="animate-spin text-4xl text-gray-400"><Loading /></el-icon>
      </div>
      
      <template v-else>
        <el-card v-if="need">
          <template #header>
            <div class="flex items-center justify-between">
              <div class="flex items-center">
                <el-button type="text" @click="$router.back()" class="mr-4">
                  <el-icon><ArrowLeft /></el-icon>
                </el-button>
                <h1 class="text-xl font-bold">{{ need.title }}</h1>
                <el-tag :type="getTypeColor(need.type)" class="ml-4">
                  {{ getTypeName(need.type) }}
                </el-tag>
              </div>
              <el-tag v-if="need.status === 'pending'" type="success">待接单</el-tag>
              <el-tag v-else-if="need.status === 'accepted'" type="warning">已接单</el-tag>
              <el-tag v-else-if="need.status === 'completed'" type="info">已完成</el-tag>
            </div>
          </template>
          
          <div class="mb-6">
            <div class="prose max-w-none">
              <p class="text-gray-700 mb-4">{{ need.description }}</p>
            </div>
            
            <div class="grid grid-cols-2 gap-4 mt-6">
              <div class="flex items-center text-gray-600">
                <el-icon class="mr-2 text-gray-400"><Location /></el-icon>
                <span>{{ need.address }}</span>
              </div>
              <div class="flex items-center text-gray-600">
                <el-icon class="mr-2 text-gray-400"><User /></el-icon>
                <span>{{ need.user_name }}</span>
              </div>
              <div class="flex items-center text-gray-600">
                <el-icon class="mr-2 text-gray-400"><Phone /></el-icon>
                <span>{{ need.user_phone }}</span>
              </div>
              <div v-if="need.expected_time" class="flex items-center text-gray-600">
                <el-icon class="mr-2 text-gray-400"><Clock /></el-icon>
                <span>{{ new Date(need.expected_time).toLocaleString() }}</span>
              </div>
            </div>
          </div>
          
          <div class="flex justify-end gap-3" v-if="user?.role === 'volunteer' && need.status === 'pending'">
            <el-button type="primary" size="large" :loading="accepting" @click="handleAccept">
              我要接单
            </el-button>
          </div>
          <div v-else-if="user?.id === need.user_id && need.status === 'pending'" class="text-right">
            <el-tag type="info">等待志愿者接单</el-tag>
          </div>
        </el-card>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import api from '@/utils/api'
import { ElMessage, ElMessageBox } from 'element-plus'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()
const user = computed(() => userStore.user)

const need = ref(null)
const loading = ref(true)
const accepting = ref(false)

const typeMap = {
  accompany: { name: '陪聊陪诊', color: 'blue' },
  shopping: { name: '代买代办', color: 'green' },
  repair: { name: '家电维修', color: 'orange' },
  housework: { name: '家政服务', color: 'purple' },
  other: { name: '其他帮助', color: 'gray' }
}

const getTypeName = (type) => typeMap[type]?.name || type
const getTypeColor = (type) => typeMap[type]?.color || 'info'

const fetchNeed = async () => {
  loading.value = true
  try {
    const res = await api.get(`/needs/${route.params.id}`)
    need.value = res.data.need
  } finally {
    loading.value = false
  }
}

const handleAccept = async () => {
  try {
    await ElMessageBox.confirm('确定要接这个需求吗？', '确认接单', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'info'
    })
    
    accepting.value = true
    await api.post(`/needs/${route.params.id}/accept`)
    ElMessage.success('接单成功')
    router.push('/orders')
  } catch (e) {
    if (e !== 'cancel') {
      ElMessage.error(e.response?.data?.message || '接单失败')
    }
  } finally {
    accepting.value = false
  }
}

onMounted(() => {
  fetchNeed()
})
</script>
