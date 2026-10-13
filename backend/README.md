# Sabzee Backend API Service

Express.js backend for Sabzee providing:
- MSG91 OTP Send & Verify APIs
- JWT Auth token issuance
- Firebase Cloud Messaging (FCM) push notifications
- Cashfree payment order generation & verification webhooks
- Supabase synchronization

---

## 🚀 Easy 1-Click Deployment (Render - Recommended)

Render provides free HTTPS web service hosting with automatic GitHub integration.

### Step 1: Push code to GitHub
Make sure your repo is pushed to GitHub.

### Step 2: Create Web Service on Render
1. Go to [render.com](https://render.com) and log in.
2. Click **New +** -> **Web Service**.
3. Connect your GitHub repository.
4. Set the following settings:
   - **Name:** `sabzee-backend`
   - **Root Directory:** `backend`
   - **Environment:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `node server.js`
   - **Instance Type:** `Free`

### Step 3: Configure Environment Variables
Under the **Environment** tab on Render, add these variables (values from your `backend/.env`):
- `PORT` = `5000` (Render overrides port automatically or uses 10000)
- `JWT_SECRET` = (your jwt secret)
- `SUPABASE_URL` = `https://mhqyaqvnlurqamojelae.supabase.co`
- `SUPABASE_ANON_KEY` = (your Supabase Service Role Key)
- `MSG91_WIDGET_ID` = `366a6c72486d383432333133`
- `MSG91_WIDGET_AUTH_KEY` = `581008TyjZUr05p26acd2169P1`
- `CASHFREE_APP_ID` = (your cashfree app id)
- `CASHFREE_SECRET_KEY` = (your cashfree secret key)
- `CASHFREE_ENV` = `PRODUCTION`
- `CASHFREE_API_VERSION` = `2023-08-01`
- `FIREBASE_SERVICE_ACCOUNT` = *(Paste the entire contents of your serviceAccountKey.json as a single line, or base64 encoded string)*

### Step 4: Deploy & Get Live URL
- Click **Create Web Service**.
- Render will install dependencies and start `server.js`.
- You will get a live URL like: `https://sabzee-backend.onrender.com`.

---

## 📲 Update Flutter App & Admin Panel

Once you have your live backend URL (e.g., `https://sabzee-backend.onrender.com`):

1. **Flutter App:**
   - Update `BACKEND_API_URL` in `.env`:
     ```env
     BACKEND_API_URL=https://sabzee-backend.onrender.com
     ```
2. **Web Admin Panel:**
   - Open Web Admin on Netlify -> Settings or enter backend URL in Notifications page.
   - Or set `VITE_API_URL=https://sabzee-backend.onrender.com` in Netlify environment variables.
