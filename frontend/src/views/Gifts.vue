<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-800">积分兑换</h1>
        <div class="flex items-center text-green-600 font-medium">
          <el-icon class="mr-2"><Coin /></el-icon>
          当前积分：{{ user?.points || 0 }}
        </div>
      </div>
      
      <el-tabs v-model="activeTab" class="mb-6">
        <el-tab-pane label="礼品中心" name="gifts" />
        <el-tab-pane label="兑换记录" name="exchanges" />
      </el-tabs>
      
      <div v-if="activeTab === 'gifts'">
        <div v-if="loading" class="text-center py-16">
          <el-icon class="animate-spin text-4xl text-gray-400"><Loading /></el-icon>
        </div>
        
        <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          <el-card v-for="gift in gifts" :key="gift.id" class="hover:shadow-lg transition-shadow">
            <img :src="gift.image" :alt="gift.name" class="w-full h-48 object-cover rounded-lg mb-4" />
            <h3 class="font-medium text-lg mb-2">{{ gift.name }}</h3>
            <p class="text-sm text-gray-500 mb-4 line-clamp-2">{{ gift.description }}</p>
            <div class="flex items-center justify-between">
              <span class="text-green-600 font-bold text-lg">
                <el-icon class="mr-1"><Coin /></el-icon>
                {{ gift.points_required }}
              </span>
              <el-button 
                type="primary" 
                size="small"
                :disabled="user?.points < gift.points_required"
                @click="handleExchange(gift)"
              >
                {{ user?.points < gift.points_required ? '积分不足' : '立即兑换' }}
              </el-button>
            </div>
          </el-card>
        </div>
      </div>
      
      <div v-else>
        <div v-if="exchangesLoading" class="text-center py-16">
          <el-icon class="animate-spin text-4xl text-gray-400"><Loading /></el-icon>
        </div>
        
        <div v-else>
          <el-table :data="exchanges" stripe>
            <el-table-column prop="name" label="礼品名称" />
            <el-table-column prop="description" label="描述" />
            <el-table-column prop="points" label="消耗积分">
              <template #default="{ row }">
                <span class="text-green-600">{{ row.points }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="status" label="状态">
              <template #default="{ row }">
                <el-tag v-if="row.status === 'pending'" type="warning">待发货</el-tag>
                <el-tag v-else-if="row.status === 'shipped'" type="primary">已发货</el-tag>
                <el-tag v-else type="success">已完成</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="created_at" label="兑换时间">
              <template #default="{ row }">
                {{ new Date(row.created_at).toLocaleString() }}
              </template>
            </el-table-column>
          </el-table>
          
          <div v-if="exchanges.length === 0" class="text-center py-16 text-gray-400">
            暂无兑换记录
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useUserStore } from '@/stores/user'
import api from '@/utils/api'
import { ElMessage, ElMessageBox } from 'element-plus'

const userStore = useUserStore()
const user = computed(() => userStore.user)

const gifts = ref([])
const exchanges = ref([])
const loading = ref(true)
const exchangesLoading = ref(true)
const activeTab = ref('gifts')

const fetchGifts = async () => {
  loading.value = true
  try {
    const res = await api.get('/gifts')
    gifts.value = res.data.gifts
  } finally {
    loading.value = false
  }
}

const fetchExchanges = async () => {
  exchangesLoading.value = true
  try {
    const res = await api.get('/my/exchanges')
    exchanges.value = res.data.exchanges
  } finally {
    exchangesLoading.value = false
  }
}

const handleExchange = async (gift) => {
  try {
    await ElMessageBox.confirm(
      `确定花费 ${gift.points_required} 积分兑换「${gift.name}」吗？`,
      '确认兑换',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'info'
      }
    )
    
    await api.post(`/gifts/${gift.id}/exchange`)
    ElMessage.success('兑换成功')
    userStore.fetchUserInfo()
    fetchExchanges()
  } catch (e) {
    if (e !== 'cancel') {
      ElMessage.error(e.response?.data?.message || '兑换失败')
    }
  }
}

onMounted(() => {
  fetchGifts()
  fetchExchanges()
})
</script>
