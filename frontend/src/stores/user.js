import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/utils/api'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('token') || '')
  const user = ref(JSON.parse(localStorage.getItem('user') || 'null'))

  const isLoggedIn = computed(() => !!token.value)

  const setUser = (userData) => {
    user.value = userData
    localStorage.setItem('user', JSON.stringify(userData))
  }

  const setToken = (tokenValue) => {
    token.value = tokenValue
    localStorage.setItem('token', tokenValue)
  }

  const login = async (phone, password) => {
    const res = await api.post('/auth/login', { phone, password })
    setToken(res.data.token)
    setUser(res.data.user)
    return res.data
  }

  const register = async (userData) => {
    const res = await api.post('/auth/register', userData)
    setToken(res.data.token)
    setUser(res.data.user)
    return res.data
  }

  const logout = () => {
    token.value = ''
    user.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('user')
  }

  const checkAuth = () => {
    if (token.value && !user.value) {
      logout()
    }
  }

  const updateUser = async (userData) => {
    await api.put('/user/profile', userData)
    setUser({ ...user.value, ...userData })
  }

  const fetchUserInfo = async () => {
    try {
      const res = await api.get('/user/profile')
      setUser(res.data.user)
    } catch (e) {
      console.error('获取用户信息失败', e)
    }
  }

  return {
    token,
    user,
    isLoggedIn,
    login,
    register,
    logout,
    checkAuth,
    updateUser,
    fetchUserInfo,
    setUser
  }
})
