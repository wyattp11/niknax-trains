import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth.js'

const routes = [
  // ── Public ──────────────────────────────────────────────
  {
    path: '/',
    component: () => import('../views/public/Home.vue'),
  },
  {
    path: '/train/:id',
    component: () => import('../views/public/TrainView.vue'),
  },

  // ── Admin ───────────────────────────────────────────────
  {
    path: '/admin',
    component: () => import('../views/admin/AdminLogin.vue'),
  },
  {
    path: '/admin/dashboard',
    component: () => import('../views/admin/Dashboard.vue'),
    meta: { requiresAdmin: true },
  },
  {
    path: '/admin/trains/new',
    component: () => import('../views/admin/CreateTrain.vue'),
    meta: { requiresAdmin: true },
  },
  {
    path: '/admin/trains/:id',
    component: () => import('../views/admin/TrainDetail.vue'),
    meta: { requiresAdmin: true },
  },
  {
    path: '/admin/members',
    component: () => import('../views/admin/Members.vue'),
    meta: { requiresAdmin: true },
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach((to) => {
  if (to.meta.requiresAdmin) {
    const auth = useAuthStore()
    if (!auth.isAdmin) return '/admin'
  }
})

export default router
