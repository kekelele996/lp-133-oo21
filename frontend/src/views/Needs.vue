<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-800">需求广场</h1>
        <el-button type="primary" v-if="user?.role === 'resident'" @click="$router.push('/publish')">
          <el-icon class="mr-1"><Plus /></el-icon>
          发布需求
        </el-button>
      </div>
      
      <el-card class="mb-6 shadow-sm">
        <div class="flex flex-wrap gap-4">
          <el-select v-model="filters.type" placeholder="选择类型" style="width: 160px" @change="fetchNeeds">
            <el-option label="全部类型" value="all" />
            <el-option label="陪聊陪诊" value="accompany" />
            <el-option label="代买代办" value="shopping" />
            <el-option label="家电维修" value="repair" />
            <el-option label="家政服务" value="housework" />
            <el-option label="其他帮助" value="other" />
          </el-select>
          
          <el-select v-model="filters.distance" placeholder="距离范围" style="width: 160px" @change="fetchNeeds">
            <el-option label="不限距离" value="" />
            <el-option label="1公里内" :value="1" />
            <el-option label="3公里内" :value="3" />
            <el-option label="5公里内" :value="5" />
            <el-option label="10公里内" :value="10" />
          </el-select>
        </div>
      </el-card>
      
      <div v-if="loading" class="text-center py-16">
        <el-icon class="animate-spin text-4xl text-gray-400"><Loading /></el-icon>
        <p class="mt-4 text-gray-500">加载中...</p>
      </div>
      
      <div v-else-if="needs.length === 0" class="text-center py-16">
        <el-icon class="text-6xl text-gray-300"><Document /></el-icon>
        <p class="mt-4 text-gray-500">暂无需求</p>
      </div>
      
      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <el-card v-for="need in needs" :key="need.id" 
                 class="cursor-pointer hover:shadow-lg transition-shadow"
                 @click="$router.push(`/needs/${need.id}`)">
          <template #header>
            <div class="flex items-center justify-between">
              <span class="font-medium">{{ need.title }}</span>
              <el-tag :type="getTypeColor(need.type)" size="small">
                {{ getTypeName(need.type) }}
              </el-tag>
            </div>
          </template>
          
          <p class="text-gray-600 text-sm mb-3 line-clamp-2">{{ need.description }}</p>
          
          <div class="flex items-center text-sm text-gray-500 mb-2">
            <el-icon class="mr-1"><Location /></el-icon>
            <span class="truncate">{{ need.address }}</span>
            <span v-if="need.distance" class="ml-2 text-green-600">
              {{ need.distance.toFixed(1) }}km
            </span>
          </div>
          
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-500">
              <el-icon class="mr-1"><User /></el-icon>
              {{ need.user_name }}
            </span>
            <span class="text-gray-400">{{ formatTime(need.created_at) }}</span>
          </div>
        </el-card>
      </div>
      
      <div class="flex justify-center mt-8" v-if="total > pageSize">
        <el-pagination
          v-model:current-page="filters.page"
          :page-size="pageSize"
          :total="total"
          layout="prev, pager, next"
          @current-change="fetchNeeds"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { useUserStore } from '@/stores/user'
import api from '@/utils/api'

const userStore = useUserStore()
const user = computed(() => userStore.user)

const needs = ref([])
const total = ref(0)
const loading = ref(false)
const pageSize = 9

const filters = reactive({
  type: 'all',
  distance: '',
  page: 1,
  lat: 39.9042,
  lng: 116.4074
})

const typeMap = {
  accompany: { name: '陪聊陪诊', color: 'blue' },
  shopping: { name: '代买代办', color: 'green' },
  repair: { name: '家电维修', color: 'orange' },
  housework: { name: '家政服务', color: 'purple' },
  other: { name: '其他帮助', color: 'gray' }
}

const getTypeName = (type) => typeMap[type]?.name || type
const getTypeColor = (type) => typeMap[type]?.color || 'info'

const formatTime = (time) => {
  const date = new Date(time)
  const now = new Date()
  const diff = now - date
  if (diff < 3600000) return Math.floor(diff / 60000) + '分钟前'
  if (diff < 86400000) return Math.floor(diff / 3600000) + '小时前'
  return date.toLocaleDateString()
}

const fetchNeeds = async () => {
  loading.value = true
  try {
    const params = {
      type: filters.type,
      page: filters.page,
      pageSize,
      lat: filters.lat,
      lng: filters.lng
    }
    if (filters.distance) params.distance = filters.distance
    
    const res = await api.get('/needs', { params })
    needs.value = res.data.needs
    total.value = res.data.total
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchNeeds()
})
</script>
