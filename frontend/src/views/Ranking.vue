<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-6">志愿者积分排行</h1>
      
      <el-card class="shadow-lg">
        <div v-if="loading" class="text-center py-16">
          <el-icon class="animate-spin text-4xl text-gray-400"><Loading /></el-icon>
        </div>
        
        <div v-else>
          <div v-for="(item, index) in ranking" :key="item.id"
               class="flex items-center py-4 border-b last:border-0 hover:bg-gray-50 px-4 rounded-lg transition-colors">
            <div class="w-12 h-12 rounded-full flex items-center justify-center mr-4 font-bold text-lg"
                 :class="{
                   'bg-yellow-100 text-yellow-600': index === 0,
                   'bg-gray-200 text-gray-600': index === 1,
                   'bg-orange-100 text-orange-600': index === 2,
                   'bg-gray-100 text-gray-500': index > 2
                 }">
              <el-icon v-if="index === 0" class="text-2xl"><Crown /></el-icon>
              <span v-else>{{ index + 1 }}</span>
            </div>
            
            <el-avatar class="mr-4" :size="48" :class="getAvatarBg(index)">
              {{ item.name.charAt(0) }}
            </el-avatar>
            
            <div class="flex-1">
              <div class="font-medium text-lg">{{ item.name }}</div>
              <div class="text-sm text-gray-500 mt-1">
                累计服务 {{ item.service_hours }} 小时
              </div>
            </div>
            
            <div class="text-right">
              <div class="text-2xl font-bold text-green-600">{{ item.points }}</div>
              <div class="text-sm text-gray-500">积分</div>
            </div>
          </div>
          
          <div v-if="ranking.length === 0" class="text-center py-16 text-gray-400">
            暂无排行数据
          </div>
        </div>
      </el-card>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/utils/api'

const ranking = ref([])
const loading = ref(true)

const getAvatarBg = (index) => {
  const colors = ['bg-yellow-500', 'bg-gray-500', 'bg-orange-500', 'bg-blue-500', 'bg-green-500']
  return colors[index] || colors[3]
}

const fetchRanking = async () => {
  loading.value = true
  try {
    const res = await api.get('/users/ranking')
    ranking.value = res.data.ranking
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchRanking()
})
</script>
