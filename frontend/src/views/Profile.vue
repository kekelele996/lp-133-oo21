<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-6">个人中心</h1>
      
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <el-card class="lg:col-span-1">
          <div class="text-center py-6">
            <el-avatar :size="100" class="mb-4 bg-green-500">
              {{ user?.name?.charAt(0) }}
            </el-avatar>
            <h2 class="text-xl font-bold text-gray-800">{{ user?.name }}</h2>
            <p class="text-gray-500 mt-1">
              {{ user?.role === 'volunteer' ? '志愿者' : '居民' }}
            </p>
            <div class="flex justify-center gap-8 mt-6">
              <div class="text-center">
                <div class="text-2xl font-bold text-green-600">{{ user?.points || 0 }}</div>
                <div class="text-sm text-gray-500">积分</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-blue-600">{{ user?.service_hours || 0 }}</div>
                <div class="text-sm text-gray-500">服务时长</div>
              </div>
            </div>
          </div>
          
          <div class="mt-6 space-y-3">
            <div class="flex items-center text-gray-600">
              <el-icon class="mr-3 w-5"><Phone /></el-icon>
              <span>{{ user?.phone }}</span>
            </div>
            <div class="flex items-center text-gray-600" v-if="user?.skills">
              <el-icon class="mr-3 w-5"><Service /></el-icon>
              <span>{{ user?.skills }}</span>
            </div>
            <div class="flex items-center text-gray-600">
              <el-icon class="mr-3 w-5"><Location /></el-icon>
              <span>{{ user?.address || '未设置地址' }}</span>
            </div>
          </div>
          
          <el-button type="primary" class="w-full mt-6" @click="editDialogVisible = true">
            编辑资料
          </el-button>
        </el-card>
        
        <el-card class="lg:col-span-2">
          <el-tabs v-model="activeTab">
            <el-tab-pane label="服务记录" name="services">
              <div v-if="ordersLoading" class="text-center py-16">
                <el-icon class="animate-spin text-4xl text-gray-400"><Loading /></el-icon>
              </div>
              
              <el-table v-else :data="orders" stripe>
                <el-table-column prop="title" label="服务项目" />
                <el-table-column prop="type" label="类型">
                  <template #default="{ row }">
                    {{ getTypeName(row.type) }}
                  </template>
                </el-table-column>
                <el-table-column label="对方">
                  <template #default="{ row }">
                    {{ user?.role === 'volunteer' ? row.user_name : row.volunteer_name }}
                  </template>
                </el-table-column>
                <el-table-column prop="address" label="地址" show-overflow-tooltip />
                <el-table-column prop="service_hours" label="时长" />
                <el-table-column prop="status" label="状态">
                  <template #default="{ row }">
                    <el-tag v-if="row.status === 'in_progress'" type="warning">进行中</el-tag>
                    <el-tag v-else type="success">已完成</el-tag>
                  </template>
                </el-table-column>
                <el-table-column prop="created_at" label="时间" width="180">
                  <template #default="{ row }">
                    {{ new Date(row.created_at).toLocaleDateString() }}
                  </template>
                </el-table-column>
              </el-table>
              
              <div v-if="orders.length === 0" class="text-center py-16 text-gray-400">
                暂无服务记录
              </div>
            </el-tab-pane>
            
            <el-tab-pane label="积分记录" name="points">
              <div v-if="exchangesLoading" class="text-center py-16">
                <el-icon class="animate-spin text-4xl text-gray-400"><Loading /></el-icon>
              </div>
              
              <el-table v-else :data="exchanges" stripe>
                <el-table-column prop="name" label="礼品名称" />
                <el-table-column prop="points" label="消耗积分">
                  <template #default="{ row }">
                    <span class="text-red-500">-{{ row.points }}</span>
                  </template>
                </el-table-column>
                <el-table-column prop="status" label="状态">
                  <template #default="{ row }">
                    <el-tag v-if="row.status === 'pending'" type="warning">待发货</el-tag>
                    <el-tag v-else-if="row.status === 'shipped'" type="primary">已发货</el-tag>
                    <el-tag v-else type="success">已完成</el-tag>
                  </template>
                </el-table-column>
                <el-table-column prop="created_at" label="兑换时间" width="180">
                  <template #default="{ row }">
                    {{ new Date(row.created_at).toLocaleDateString() }}
                  </template>
                </el-table-column>
              </el-table>
              
              <div v-if="exchanges.length === 0" class="text-center py-16 text-gray-400">
                暂无兑换记录
              </div>
            </el-tab-pane>
          </el-tabs>
        </el-card>
      </div>
    </div>
    
    <el-dialog v-model="editDialogVisible" title="编辑资料" width="500px">
      <el-form :model="editForm" label-width="80px">
        <el-form-item label="姓名">
          <el-input v-model="editForm.name" />
        </el-form-item>
        <el-form-item label="擅长领域" v-if="user?.role === 'volunteer'">
          <el-select v-model="editForm.skills" multiple class="w-full" placeholder="选择擅长领域">
            <el-option label="陪聊陪诊" value="陪聊" />
            <el-option label="代买代办" value="代买" />
            <el-option label="家电维修" value="家电维修" />
            <el-option label="家政服务" value="家政服务" />
            <el-option label="其他帮助" value="其他" />
          </el-select>
        </el-form-item>
        <el-form-item label="地址">
          <el-input v-model="editForm.address" type="textarea" :rows="2" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveProfile">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { useUserStore } from '@/stores/user'
import api from '@/utils/api'
import { ElMessage } from 'element-plus'

const userStore = useUserStore()
const user = computed(() => userStore.user)

const orders = ref([])
const exchanges = ref([])
const ordersLoading = ref(true)
const exchangesLoading = ref(true)
const activeTab = ref('services')
const editDialogVisible = ref(false)
const saving = ref(false)

const editForm = reactive({
  name: '',
  skills: [],
  address: '',
  lat: 39.9042,
  lng: 116.4074
})

const typeMap = {
  accompany: '陪聊陪诊',
  shopping: '代买代办',
  repair: '家电维修',
  housework: '家政服务',
  other: '其他帮助'
}

const getTypeName = (type) => typeMap[type] || type

const fetchOrders = async () => {
  ordersLoading.value = true
  try {
    const res = await api.get('/orders')
    orders.value = res.data.orders
  } finally {
    ordersLoading.value = false
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

const openEditDialog = () => {
  editForm.name = user.value?.name || ''
  editForm.skills = user.value?.skills ? user.value.skills.split(',') : []
  editForm.address = user.value?.address || ''
  editDialogVisible.value = true
}

const saveProfile = async () => {
  try {
    saving.value = true
    const data = {
      ...editForm,
      skills: Array.isArray(editForm.skills) ? editForm.skills.join(',') : editForm.skills
    }
    await userStore.updateUser(data)
    ElMessage.success('保存成功')
    editDialogVisible.value = false
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '保存失败')
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  fetchOrders()
  fetchExchanges()
})
</script>
