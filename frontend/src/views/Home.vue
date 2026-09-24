<template>
  <div class="min-h-screen bg-gradient-to-br from-green-50 to-blue-50">
    <div class="container mx-auto px-4 py-8">
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold text-gray-800 mb-4">欢迎来到志愿者互助平台</h1>
        <p class="text-xl text-gray-600">传递温暖，共建美好社区</p>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
        <div class="bg-white rounded-xl shadow-lg p-6 text-center hover:shadow-xl transition-shadow">
          <div class="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <el-icon class="text-3xl text-blue-600"><Reading /></el-icon>
          </div>
          <h3 class="text-lg font-semibold mb-2">需求广场</h3>
          <p class="text-gray-500 text-sm">浏览并接受附近居民的求助需求</p>
        </div>
        
        <div class="bg-white rounded-xl shadow-lg p-6 text-center hover:shadow-xl transition-shadow">
          <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <el-icon class="text-3xl text-green-600"><Edit /></el-icon>
          </div>
          <h3 class="text-lg font-semibold mb-2">发布需求</h3>
          <p class="text-gray-500 text-sm">发布您需要的帮助，等待志愿者接单</p>
        </div>
        
        <div class="bg-white rounded-xl shadow-lg p-6 text-center hover:shadow-xl transition-shadow">
          <div class="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <el-icon class="text-3xl text-yellow-600"><Trophy /></el-icon>
          </div>
          <h3 class="text-lg font-semibold mb-2">积分兑换</h3>
          <p class="text-gray-500 text-sm">服务时长换积分，兑换精美礼品</p>
        </div>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <el-card class="shadow-lg">
          <template #header>
            <div class="flex items-center justify-between">
              <span class="font-semibold text-lg">最新需求</span>
              <router-link to="/needs" class="text-green-600 hover:underline text-sm">查看全部</router-link>
            </div>
          </template>
          <div v-if="loading" class="text-center py-8">
            <el-icon class="animate-spin text-3xl text-gray-400"><Loading /></el-icon>
          </div>
          <div v-else>
            <div v-for="need in needs.slice(0, 5)" :key="need.id" 
                 class="flex items-center justify-between py-3 border-b last:border-0 cursor-pointer hover:bg-gray-50 px-2 rounded"
                 @click="$router.push(`/needs/${need.id}`)">
              <div class="flex-1">
                <div class="font-medium text-gray-800">{{ need.title }}</div>
                <div class="text-sm text-gray-500 mt-1">{{ need.address }}</div>
              </div>
              <el-tag :type="getTypeColor(need.type)" size="small">
                {{ getTypeName(need.type) }}
              </el-tag>
            </div>
            <div v-if="needs.length === 0" class="text-center py-8 text-gray-400">
              暂无需求
            </div>
          </div>
        </el-card>
        
        <el-card class="shadow-lg">
          <template #header>
            <div class="flex items-center justify-between">
              <span class="font-semibold text-lg">志愿者排行</span>
              <router-link to="/ranking" class="text-green-600 hover:underline text-sm">查看全部</router-link>
            </div>
          </template>
          <div v-if="rankingLoading" class="text-center py-8">
            <el-icon class="animate-spin text-3xl text-gray-400"><Loading /></el-icon>
          </div>
          <div v-else>
            <div v-for="(item, index) in ranking.slice(0, 5)" :key="item.id"
                 class="flex items-center py-3 border-b last:border-0">
              <div class="w-8 h-8 rounded-full flex items-center justify-center mr-4"
                   :class="index === 0 ? 'bg-yellow-100 text-yellow-600' : index === 1 ? 'bg-gray-100 text-gray-600' : index === 2 ? 'bg-orange-100 text-orange-600' : 'bg-gray-50 text-gray-500'">
                {{ index + 1 }}
              </div>
              <div class="flex-1">
                <div class="font-medium text-gray-800">{{ item.name }}</div>
                <div class="text-sm text-gray-500">{{ item.service_hours }} 小时服务</div>
              </div>
              <div class="text-green-600 font-semibold">{{ item.points }} 积分</div>
            </div>
          </div>
        </el-card>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/utils/api'

const needs = ref([])
const ranking = ref([])
const loading = ref(true)
const rankingLoading = ref(true)

const typeMap = {
  accompany: { name: '陪聊陪诊', color: 'blue' },
  shopping: { name: '代买代办', color: 'green' },
  repair: { name: '家电维修', color: 'orange' },
  housework: { name: '家政服务', color: 'purple' },
  other: { name: '其他帮助', color: 'gray' }
}

const getTypeName = (type) => typeMap[type]?.name || type
const getTypeColor = (type) => typeMap[type]?.color || 'info'

const fetchNeeds = async () => {
  try {
    const res = await api.get('/needs?pageSize=5')
    needs.value = res.data.needs
  } finally {
    loading.value = false
  }
}

const fetchRanking = async () => {
  try {
    const res = await api.get('/users/ranking')
    ranking.value = res.data.ranking
  } finally {
    rankingLoading.value = false
  }
}

onMounted(() => {
  fetchNeeds()
  fetchRanking()
})
</script>
