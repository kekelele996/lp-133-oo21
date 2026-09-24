<template>
  <div id="app" class="min-h-screen bg-gray-50">
    <el-container>
      <el-header v-if="isLoggedIn" class="bg-white shadow-sm">
        <div class="container mx-auto px-4 h-14 flex items-center justify-between">
          <div class="flex items-center space-x-6">
            <router-link to="/" class="text-xl font-bold text-green-600 flex items-center">
              <el-icon class="mr-2"><Promotion /></el-icon>
              志愿者互助平台
            </router-link>
            <el-menu mode="horizontal" :default-active="activeMenu" class="border-none" @select="handleMenuSelect">
              <el-menu-item index="/needs">
                <el-icon><Reading /></el-icon>
                需求广场
              </el-menu-item>
              <el-menu-item index="/publish" v-if="user?.role === 'resident'">
                <el-icon><Edit /></el-icon>
                发布需求
              </el-menu-item>
              <el-menu-item index="/orders">
                <el-icon><List /></el-icon>
                我的订单
              </el-menu-item>
              <el-menu-item index="/messages">
                <el-icon><ChatDotRound /></el-icon>
                消息中心
              </el-menu-item>
              <el-menu-item index="/ranking">
                <el-icon><Trophy /></el-icon>
                积分排名
              </el-menu-item>
              <el-menu-item index="/gifts">
                <el-icon><Present /></el-icon>
                积分兑换
              </el-menu-item>
            </el-menu>
          </div>
          <div class="flex items-center space-x-4">
            <span class="text-gray-600">
              <el-icon><Coin /></el-icon>
              {{ user?.points || 0 }} 积分
            </span>
            <el-dropdown @command="handleCommand">
              <span class="el-dropdown-link cursor-pointer flex items-center">
                <el-avatar :size="32" class="mr-2 bg-green-500">
                  {{ user?.name?.charAt(0) }}
                </el-avatar>
                {{ user?.name }}
                <el-icon class="el-icon--right"><arrow-down /></el-icon>
              </span>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="profile">个人中心</el-dropdown-item>
                  <el-dropdown-item command="logout" divided>退出登录</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </div>
        </div>
      </el-header>
      <el-main class="p-0">
        <router-view />
      </el-main>
    </el-container>
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { ElMessage } from 'element-plus'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()

const user = computed(() => userStore.user)
const isLoggedIn = computed(() => userStore.isLoggedIn)

const activeMenu = computed(() => route.path)

const handleMenuSelect = (index) => {
  router.push(index)
}

const handleCommand = (command) => {
  if (command === 'profile') {
    router.push('/profile')
  } else if (command === 'logout') {
    userStore.logout()
    ElMessage.success('已退出登录')
    router.push('/login')
  }
}

onMounted(() => {
  userStore.checkAuth()
})
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

.el-header {
  --el-header-padding: 0 !important;
}

.el-menu--horizontal {
  border-bottom: none !important;
}

.el-dropdown-link {
  cursor: pointer;
  color: #606266;
}
</style>
