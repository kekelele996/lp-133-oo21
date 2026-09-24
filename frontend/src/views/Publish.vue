<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-6">发布需求</h1>
      
      <el-card class="max-w-2xl mx-auto">
        <el-form :model="form" :rules="rules" ref="formRef" label-width="100px">
          <el-form-item label="需求标题" prop="title">
            <el-input v-model="form.title" placeholder="请输入需求标题" maxlength="50" show-word-limit />
          </el-form-item>
          
          <el-form-item label="需求类型" prop="type">
            <el-select v-model="form.type" placeholder="请选择需求类型" class="w-full">
              <el-option label="陪聊陪诊" value="accompany" />
              <el-option label="代买代办" value="shopping" />
              <el-option label="家电维修" value="repair" />
              <el-option label="家政服务" value="housework" />
              <el-option label="其他帮助" value="other" />
            </el-select>
          </el-form-item>
          
          <el-form-item label="需求描述" prop="description">
            <el-input v-model="form.description" type="textarea" :rows="4" placeholder="请详细描述您的需求" maxlength="500" show-word-limit />
          </el-form-item>
          
          <el-form-item label="服务地址" prop="address">
            <el-input v-model="form.address" placeholder="请输入服务地址" />
          </el-form-item>
          
          <el-form-item label="期望时间">
            <el-date-picker
              v-model="form.expected_time"
              type="datetime"
              placeholder="选择期望服务时间"
              format="YYYY-MM-DD HH:mm"
              value-format="YYYY-MM-DD HH:mm:ss"
              class="w-full"
            />
          </el-form-item>
          
          <el-form-item>
            <el-button type="primary" :loading="loading" @click="handleSubmit">发布需求</el-button>
            <el-button @click="$router.back()">取消</el-button>
          </el-form-item>
        </el-form>
      </el-card>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/utils/api'
import { ElMessage } from 'element-plus'

const router = useRouter()
const formRef = ref()
const loading = ref(false)

const form = reactive({
  title: '',
  description: '',
  type: '',
  address: '',
  expected_time: '',
  lat: 39.9042,
  lng: 116.4074
})

const rules = {
  title: [{ required: true, message: '请输入需求标题', trigger: 'blur' }],
  type: [{ required: true, message: '请选择需求类型', trigger: 'change' }],
  description: [{ required: true, message: '请输入需求描述', trigger: 'blur' }],
  address: [{ required: true, message: '请输入服务地址', trigger: 'blur' }]
}

const handleSubmit = async () => {
  try {
    await formRef.value.validate()
    loading.value = true
    await api.post('/needs', form)
    ElMessage.success('发布成功')
    router.push('/needs')
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '发布失败')
  } finally {
    loading.value = false
  }
}
</script>
