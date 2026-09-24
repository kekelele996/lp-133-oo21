<template>
  <div class="min-h-screen bg-gradient-to-br from-green-50 to-blue-50 flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl shadow-xl w-full max-w-md p-8">
      <div class="text-center mb-8">
        <div class="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <el-icon class="text-4xl text-green-600"><Promotion /></el-icon>
        </div>
        <h1 class="text-2xl font-bold text-gray-800">志愿者互助平台</h1>
        <p class="text-gray-500 mt-2">温暖他人，快乐自己</p>
      </div>
      
      <el-form :model="form" :rules="rules" ref="formRef" @submit.prevent="handleLogin">
        <el-form-item prop="phone">
          <el-input v-model="form.phone" placeholder="请输入手机号" size="large">
            <template #prefix>
              <el-icon><Phone /></el-icon>
            </template>
          </el-input>
        </el-form-item>
        
        <el-form-item prop="password">
          <el-input v-model="form.password" type="password" placeholder="请输入密码" size="large" show-password>
            <template #prefix>
              <el-icon><Lock /></el-icon>
            </template>
          </el-input>
        </el-form-item>
        
        <el-button type="primary" size="large" class="w-full" :loading="loading" @click="handleLogin">
          登录
        </el-button>
      </el-form>
      
      <div class="mt-6 text-center">
        <span class="text-gray-500">还没有账号？</span>
        <router-link to="/register" class="text-green-600 hover:underline ml-1">立即注册</router-link>
      </div>
      
      <div class="mt-8 p-4 bg-gray-50 rounded-lg">
        <p class="text-sm text-gray-600 mb-2">演示账号：</p>
        <p class="text-xs text-gray-500">志愿者：13800138001 / 123456</p>
        <p class="text-xs text-gray-500">居  民：13900139001 / 123456</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { ElMessage } from 'element-plus'

const router = useRouter()
const userStore = useUserStore()
const formRef = ref()
const loading = ref(false)

const form = reactive({
  phone: '',
  password: ''
})

const rules = {
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '请输入正确的手机号', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少6位', trigger: 'blur' }
  ]
}

const handleLogin = async () => {
  try {
    await formRef.value.validate()
    loading.value = true
    await userStore.login(form.phone, form.password)
    ElMessage.success('登录成功')
    router.push('/needs')
  } catch (e) {
    if (!e.response) {
      ElMessage.error('网络错误，请检查后端服务是否启动')
    }
  } finally {
    loading.value = false
  }
}
</script>
