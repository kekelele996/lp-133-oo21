<template>
  <div class="min-h-screen bg-gradient-to-br from-green-50 to-blue-50 flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl shadow-xl w-full max-w-md p-8">
      <div class="text-center mb-8">
        <div class="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <el-icon class="text-4xl text-green-600"><UserPlus /></el-icon>
        </div>
        <h1 class="text-2xl font-bold text-gray-800">注册账号</h1>
        <p class="text-gray-500 mt-2">加入志愿者互助平台</p>
      </div>
      
      <el-form :model="form" :rules="rules" ref="formRef" @submit.prevent="handleRegister">
        <el-form-item prop="name">
          <el-input v-model="form.name" placeholder="请输入姓名" size="large">
            <template #prefix>
              <el-icon><User /></el-icon>
            </template>
          </el-input>
        </el-form-item>
        
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
        
        <el-form-item prop="role">
          <el-radio-group v-model="form.role" class="w-full">
            <el-radio-button value="volunteer" class="flex-1 text-center">
              <el-icon class="mr-1"><Service /></el-icon>
              我是志愿者
            </el-radio-button>
            <el-radio-button value="resident" class="flex-1 text-center">
              <el-icon class="mr-1"><HomeFilled /></el-icon>
              我是居民
            </el-radio-button>
          </el-radio-group>
        </el-form-item>
        
        <el-form-item v-if="form.role === 'volunteer'" prop="skills">
          <el-select v-model="form.skills" multiple placeholder="请选择擅长领域" size="large" class="w-full">
            <el-option label="陪聊陪诊" value="陪聊" />
            <el-option label="代买代办" value="代买" />
            <el-option label="家电维修" value="家电维修" />
            <el-option label="家政服务" value="家政服务" />
            <el-option label="其他帮助" value="其他" />
          </el-select>
        </el-form-item>
        
        <el-form-item prop="address">
          <el-input v-model="form.address" type="textarea" :rows="2" placeholder="请输入地址" size="large" />
        </el-form-item>
        
        <el-button type="primary" size="large" class="w-full" :loading="loading" @click="handleRegister">
          注册
        </el-button>
      </el-form>
      
      <div class="mt-6 text-center">
        <span class="text-gray-500">已有账号？</span>
        <router-link to="/login" class="text-green-600 hover:underline ml-1">立即登录</router-link>
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
  name: '',
  phone: '',
  password: '',
  role: 'volunteer',
  skills: [],
  address: '',
  lat: 39.9042,
  lng: 116.4074
})

const rules = {
  name: [{ required: true, message: '请输入姓名', trigger: 'blur' }],
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '请输入正确的手机号', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少6位', trigger: 'blur' }
  ],
  role: [{ required: true, message: '请选择身份', trigger: 'change' }]
}

const handleRegister = async () => {
  try {
    await formRef.value.validate()
    loading.value = true
    const data = { ...form, skills: form.skills.join(',') }
    await userStore.register(data)
    ElMessage.success('注册成功')
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
