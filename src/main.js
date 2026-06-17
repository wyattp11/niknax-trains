import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { inject as injectAnalytics } from '@vercel/analytics'
import { injectSpeedInsights } from '@vercel/speed-insights'
import router from './router/index.js'
import App from './App.vue'
import './assets/main.css'

injectAnalytics()
injectSpeedInsights()

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')
