<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-6">消息中心</h1>
      
      <el-card class="h-[calc(100vh-180px)]">
        <div class="flex h-full">
          <div class="w-80 border-r pr-4">
            <div class="mb-4 font-medium text-gray-700">会话列表</div>
            <div class="space-y-2">
              <div v-for="conv in conversations" :key="conv.other_user_id"
                   class="p-3 rounded-lg cursor-pointer hover:bg-gray-50 transition-colors"
                   :class="{ 'bg-green-50': selectedUserId === conv.other_user_id }"
                   @click="selectConversation(conv.other_user_id)">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <el-avatar class="mr-3 bg-blue-500" :size="40">
                      {{ conv.other_user_name?.charAt(0) }}
                    </el-avatar>
                    <div>
                      <div class="font-medium">{{ conv.other_user_name }}</div>
                      <div class="text-sm text-gray-500 truncate max-w-[160px]">{{ conv.last_message }}</div>
                    </div>
                  </div>
                </div>
                <div class="text-xs text-gray-400 mt-1 text-right">
                  {{ formatTime(conv.last_time) }}
                </div>
              </div>
              <div v-if="conversations.length === 0" class="text-center py-8 text-gray-400">
                暂无会话
              </div>
            </div>
          </div>
          
          <div class="flex-1 flex flex-col pl-4">
            <div v-if="selectedUserId" class="flex-1 flex flex-col">
              <div class="border-b pb-3 mb-4">
                <div class="font-medium">{{ selectedUserName }}</div>
              </div>
              
              <div class="flex-1 overflow-y-auto space-y-4" ref="messagesContainer">
                <div v-for="msg in messages" :key="msg.id"
                     class="flex"
                     :class="{ 'justify-end': msg.sender_id === user?.id }">
                  <div v-if="msg.sender_id !== user?.id" class="mr-3">
                    <el-avatar class="bg-blue-500" :size="36">{{ msg.sender_name?.charAt(0) }}</el-avatar>
                  </div>
                  <div class="max-w-[60%]">
                    <div class="rounded-2xl px-4 py-2"
                         :class="msg.sender_id === user?.id ? 'bg-green-500 text-white' : 'bg-white border'">
                      {{ msg.content }}
                    </div>
                    <div class="text-xs text-gray-400 mt-1"
                         :class="{ 'text-right': msg.sender_id === user?.id }">
                      {{ formatTime(msg.created_at) }}
                    </div>
                  </div>
                  <div v-if="msg.sender_id === user?.id" class="ml-3">
                    <el-avatar class="bg-green-500" :size="36">{{ user?.name?.charAt(0) }}</el-avatar>
                  </div>
                </div>
                <div v-if="messages.length === 0" class="text-center py-16 text-gray-400">
                  暂无消息，发送第一条消息吧
                </div>
              </div>
              
              <div class="border-t pt-4 mt-4">
                <div class="flex gap-3">
                  <el-input v-model="newMessage" placeholder="输入消息..." @keyup.enter="sendMessage" />
                  <el-button type="primary" :loading="sending" @click="sendMessage">发送</el-button>
                </div>
              </div>
            </div>
            
            <div v-else class="flex-1 flex items-center justify-center text-gray-400">
              选择一个会话开始聊天
            </div>
          </div>
        </div>
      </el-card>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { useUserStore } from '@/stores/user'
import api from '@/utils/api'
import { ElMessage } from 'element-plus'

const route = useRoute()
const userStore = useUserStore()
const user = computed(() => userStore.user)

const conversations = ref([])
const messages = ref([])
const selectedUserId = ref(null)
const selectedUserName = ref('')
const newMessage = ref('')
const sending = ref(false)
const messagesContainer = ref(null)

const formatTime = (time) => {
  const date = new Date(time)
  const now = new Date()
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
  }
  return date.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' })
}

const fetchConversations = async () => {
  try {
    const res = await api.get('/messages')
    conversations.value = res.data.conversations || []
  } catch (e) {
    console.error('获取会话列表失败', e)
  }
}

const fetchMessages = async (userId) => {
  try {
    const res = await api.get('/messages', { params: { other_user_id: userId } })
    messages.value = res.data.messages || []
    const conv = conversations.value.find(c => c.other_user_id === userId)
    selectedUserName.value = conv?.other_user_name || '用户'
    nextTick(() => {
      if (messagesContainer.value) {
        messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
      }
    })
  } catch (e) {
    console.error('获取消息失败', e)
  }
}

const selectConversation = (userId) => {
  selectedUserId.value = userId
  fetchMessages(userId)
}

const sendMessage = async () => {
  if (!newMessage.value.trim() || !selectedUserId.value) return
  
  try {
    sending.value = true
    await api.post('/messages', {
      receiver_id: selectedUserId.value,
      content: newMessage.value.trim()
    })
    newMessage.value = ''
    fetchMessages(selectedUserId.value)
    fetchConversations()
  } catch (e) {
    ElMessage.error('发送失败')
  } finally {
    sending.value = false
  }
}

onMounted(async () => {
  await fetchConversations()
  if (route.query.userId) {
    selectConversation(parseInt(route.query.userId))
  }
})
</script>
