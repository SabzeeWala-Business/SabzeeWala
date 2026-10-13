import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const MSG91_WIDGET_ID = '366a6c72486d383432333133'
const MSG91_AUTH_TOKEN = '581008TyjZUr05p26acd2169P1'

function otpDevPlugin() {
  return {
    name: 'otp-dev-plugin',
    configureServer(server) {
      server.middlewares.use('/api/otp', async (req, res) => {
        if (req.method === 'OPTIONS') {
          res.setHeader('Access-Control-Allow-Origin', '*')
          res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
          res.end()
          return
        }

        let body = ''
        req.on('data', chunk => { body += chunk })
        req.on('end', async () => {
          res.setHeader('Content-Type', 'application/json')
          res.setHeader('Access-Control-Allow-Origin', '*')

          try {
            const parsed = JSON.parse(body || '{}')
            const { action, phone, otp, reqId } = parsed

            if (action === 'send') {
              const upstream = await fetch('https://control.msg91.com/api/v5/widget/sendOtpMobile', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
                body: JSON.stringify({ widgetId: MSG91_WIDGET_ID, tokenAuth: MSG91_AUTH_TOKEN, identifier: phone }),
              })
              const data = await upstream.json().catch(() => ({}))
              const type = (data.type || data.status || '').toLowerCase()
              const msg = String(data.message || data.error || '')

              if (type === 'error' || /fail|error|limit|wait|block/i.test(msg)) {
                res.statusCode = 400
                res.end(JSON.stringify({ success: false, error: msg || 'Failed to send OTP' }))
                return
              }

              const verificationId = data.reqId || data.requestID || data.requestId || data.message
              res.end(JSON.stringify({ success: true, reqId: String(verificationId), details: data }))
              return
            }

            if (action === 'verify') {
              const upstream = await fetch('https://control.msg91.com/api/v5/widget/verifyOtp', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
                body: JSON.stringify({ widgetId: MSG91_WIDGET_ID, tokenAuth: MSG91_AUTH_TOKEN, reqId: reqId || '', otp: String(otp) }),
              })
              const data = await upstream.json().catch(() => ({}))
              const type = (data.type || data.status || '').toLowerCase()
              const msg = (data.message || '').toLowerCase()

              if (type === 'success' || msg.includes('verified') || msg.includes('otp verified')) {
                res.end(JSON.stringify({ success: true }))
                return
              }

              res.statusCode = 400
              res.end(JSON.stringify({ success: false, error: data.message || 'Invalid OTP code' }))
              return
            }

            res.statusCode = 400
            res.end(JSON.stringify({ success: false, error: 'Invalid action' }))
          } catch (err) {
            res.statusCode = 500
            res.end(JSON.stringify({ success: false, error: err.message }))
          }
        })
      })
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), otpDevPlugin()],
  server: {
    host: true,
    port: 5173,
    proxy: {
      '/msg91': {
        target: 'https://control.msg91.com',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/msg91/, ''),
      },
    },
  },
})
