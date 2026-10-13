const express = require('express');
const cors = require('cors');
const axios = require('axios');
const jwt = require('jsonwebtoken');
const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Supabase Client
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://mhqyaqvnlurqamojelae.supabase.co';
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_ANON_KEY ||
  '';
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Initialize Firebase Admin SDK for FCM
let firebaseAdmin = null;
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
let serviceAccount = null;

if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } catch (err) {
    try {
      const decoded = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString('utf8');
      serviceAccount = JSON.parse(decoded);
    } catch (bErr) {
      console.error('[FCM] Failed to parse FIREBASE_SERVICE_ACCOUNT env var:', err.message);
    }
  }
} else if (fs.existsSync(serviceAccountPath)) {
  try {
    serviceAccount = require(serviceAccountPath);
  } catch (err) {
    console.error('[FCM] Failed to load serviceAccountKey.json:', err.message);
  }
}

if (serviceAccount) {
  try {
    const certCredential =
      admin.credential && typeof admin.credential.cert === 'function'
        ? admin.credential.cert(serviceAccount)
        : require('firebase-admin/app').cert(serviceAccount);

    firebaseAdmin = admin.initializeApp({
      credential: certCredential,
    });
    console.log(`[FCM] Firebase Admin initialized for project: ${serviceAccount.project_id}`);
  } catch (err) {
    console.error('[FCM] Firebase Admin initialization error:', err.message);
  }
} else {
  console.warn('[FCM] serviceAccountKey.json or FIREBASE_SERVICE_ACCOUNT not found. Push notifications will be unavailable.');
}

const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'sabzee_super_secret_key_12345';

// Same credentials as Flutter: lib/screens/login_screen.dart
const MSG91_WIDGET_ID = process.env.MSG91_WIDGET_ID;
const MSG91_WIDGET_AUTH_KEY =
  process.env.MSG91_WIDGET_AUTH_KEY || process.env.MSG91_AUTH_KEY;

const WIDGET_BASE = 'https://control.msg91.com/api/v5/widget';

function normalizePhone(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (digits.length === 10) return `91${digits}`;
  return digits;
}

async function issueSession(phone) {
  const digits = normalizePhone(phone);
  const last10 = digits.slice(-10);
  const sessionUser = { phone: digits, role: 'customer' };

  // Emergency master admins fallback
  const masterPhones = ['9876543210', '9718805484', '7050057572', '9599989241'];
  if (masterPhones.includes(last10) || masterPhones.includes(digits)) {
    sessionUser.role = 'admin';
  } else {
    // Dynamic check in Supabase admin_users table
    try {
      const { data: adminRow } = await supabase
        .from('admin_users')
        .select('role, status')
        .ilike('mobile', `%${last10}%`)
        .eq('status', 'active')
        .maybeSingle();

      if (adminRow) {
        sessionUser.role = adminRow.role || 'admin';
      }
    } catch (e) {
      console.warn('Backend admin_users check error:', e.message);
    }
  }

  const token = jwt.sign(sessionUser, JWT_SECRET, { expiresIn: '30d' });
  return { token, user: sessionUser };
}

function extractReqId(payload) {
  if (!payload) return null;
  if (typeof payload === 'string') {
    if (/authenticationfailure|error|fail/i.test(payload)) return null;
    return payload;
  }
  const candidate =
    payload.reqId ||
    payload.requestID ||
    payload.requestId ||
    (payload.type === 'success' ? payload.message : null) ||
    null;
  if (candidate && /authenticationfailure|error|fail/i.test(String(candidate))) {
    return null;
  }
  return candidate;
}

function isMsg91Success(data) {
  if (!data) return false;
  const type = String(data.type || data.status || '').toLowerCase();
  const message = String(data.message || '').toLowerCase();
  if (message.includes('authenticationfailure') || type === 'error') return false;
  return (
    type === 'success' ||
    message.includes('otp verified') ||
    message.includes('verified successfully')
  );
}

function widgetPayload(extra = {}) {
  return {
    widgetId: MSG91_WIDGET_ID,
    tokenAuth: MSG91_WIDGET_AUTH_KEY,
    ...extra,
  };
}

function ensureWidgetConfig(res) {
  if (!MSG91_WIDGET_ID || !MSG91_WIDGET_AUTH_KEY) {
    res.status(500).json({
      error:
        'MSG91 widget is not configured. Set MSG91_WIDGET_ID and MSG91_WIDGET_AUTH_KEY in backend/.env',
    });
    return false;
  }
  return true;
}

// -------------------------------------------------------------
// OTP — same MSG91 Widget HTTP API used by @msg91comm/sendotp-sdk
// POST /sendOtpMobile  body: { widgetId, tokenAuth, identifier }
// POST /verifyOtp      body: { widgetId, tokenAuth, reqId, otp }
// -------------------------------------------------------------

app.post('/api/auth/send-otp', async (req, res) => {
  if (!ensureWidgetConfig(res)) return;

  const phone = normalizePhone(req.body.phone);
  if (!phone) {
    return res.status(400).json({ error: 'Phone number is required' });
  }

  try {
    const response = await axios.post(
      `${WIDGET_BASE}/sendOtpMobile`,
      widgetPayload({ identifier: phone }),
      {
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
      }
    );

    const data = response.data || {};
    const reqId = extractReqId(data);

    console.log('MSG91 sendOtpMobile response:', JSON.stringify(data));

    if (reqId || isMsg91Success(data)) {
      return res.json({
        success: true,
        message: 'OTP sent successfully via MSG91 Widget.',
        reqId: reqId || data.message || null,
        raw: data,
      });
    }

    return res.status(400).json({
      error: data.message || data.error || 'Failed to send OTP via MSG91.',
      details: data,
    });
  } catch (error) {
    console.error('MSG91 Send Error:', error.response?.data || error.message);
    return res.status(500).json({
      error:
        error.response?.data?.message ||
        error.response?.data?.error ||
        'Internal server error during SMS dispatch.',
      details: error.response?.data || null,
    });
  }
});

app.post('/api/auth/verify-otp', async (req, res) => {
  if (!ensureWidgetConfig(res)) return;

  const phone = normalizePhone(req.body.phone);
  const { otp, reqId } = req.body;

  if (!phone || !otp) {
    return res.status(400).json({ error: 'Phone number and OTP code are required.' });
  }
  if (!reqId) {
    return res.status(400).json({
      error: 'Missing reqId. Please request a new OTP.',
    });
  }

  try {
    const response = await axios.post(
      `${WIDGET_BASE}/verifyOtp`,
      widgetPayload({ reqId, otp: String(otp) }),
      {
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
      }
    );

    const data = response.data || {};
    console.log('MSG91 verifyOtp response:', JSON.stringify(data));

    if (isMsg91Success(data) || data.message || data['access-token'] || data.access_token) {
      const session = await issueSession(phone);
      return res.json({
        success: true,
        message: 'OTP Verified successfully.',
        accessToken: data.message || data['access-token'] || data.access_token || null,
        ...session,
      });
    }

    return res.status(400).json({
      error: data.message || data.error || 'OTP Verification failed.',
      details: data,
    });
  } catch (error) {
    console.error('MSG91 Verify Error:', error.response?.data || error.message);
    return res.status(500).json({
      error:
        error.response?.data?.message ||
        error.response?.data?.error ||
        'Internal server error during OTP verification.',
      details: error.response?.data || null,
    });
  }
});

app.post('/api/auth/verify-widget-token', async (req, res) => {
  const { accessToken } = req.body;
  if (!accessToken) {
    return res.status(400).json({ error: 'Access token from client widget is required.' });
  }
  if (!ensureWidgetConfig(res)) return;

  try {
    const response = await axios.post(
      `${WIDGET_BASE}/verifyAccessToken`,
      {
        authkey: MSG91_WIDGET_AUTH_KEY,
        'access-token': accessToken,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
      }
    );

    if (
      response.data &&
      (response.data.type === 'success' ||
        response.data.status === 'success' ||
        response.data.mobile)
    ) {
      const phone = response.data.mobile || 'unknown_number';
      const session = await issueSession(phone);
      return res.json({
        success: true,
        message: 'Access Token verified successfully.',
        ...session,
      });
    }

    return res.status(400).json({
      error: response.data?.message || 'Access token verification failed on MSG91.',
    });
  } catch (error) {
    console.error('MSG91 Widget Verify Error:', error.response?.data || error.message);
    return res.status(500).json({
      error: 'Internal server error during Widget verification.',
    });
  }
});

const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({ error: 'Access Denied: No Authorization header provided.' });
  }
  const token = authHeader.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: 'Access Denied: Token format is invalid.' });
  }
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(403).json({ error: 'Access Denied: Session Token is invalid or expired.' });
  }
};

// ============================================================================
// FIREBASE CLOUD MESSAGING (FCM) NOTIFICATION ENDPOINTS
// ============================================================================

// 1. Get FCM Status and registered device count
app.get('/api/notifications/status', async (_req, res) => {
  try {
    const { count, error } = await supabase
      .from('users')
      .select('id', { count: 'exact', head: true })
      .not('fcm_token', 'is', null);

    return res.json({
      ok: true,
      firebaseReady: Boolean(firebaseAdmin),
      projectId: firebaseAdmin ? 'sabzee-wala' : null,
      registeredDeviceCount: count || 0,
      supabaseError: error ? error.message : null,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// 2. Broadcast push notification to ALL registered customer devices
app.post('/api/notifications/broadcast', async (req, res) => {
  if (!firebaseAdmin) {
    return res.status(500).json({ error: 'Firebase Admin is not configured. Check serviceAccountKey.json.' });
  }

  const { title, body, screen, data } = req.body;
  if (!title || !body) {
    return res.status(400).json({ error: 'Title and body are required for broadcast notification.' });
  }

  try {
    const { data: users, error } = await supabase
      .from('users')
      .select('id, fcm_token')
      .not('fcm_token', 'is', null);

    if (error) throw error;

    const tokens = (users || [])
      .map((u) => u.fcm_token)
      .filter((t) => typeof t === 'string' && t.trim().length > 10);

    const uniqueTokens = [...new Set(tokens)];

    if (uniqueTokens.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'No registered customer devices found with active FCM tokens.',
      });
    }

    const payload = {
      tokens: uniqueTokens,
      notification: {
        title,
        body,
      },
      data: {
        screen: screen || 'home',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        ...(data || {}),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'sabzee_orders_channel',
          sound: 'default',
          priority: 'max',
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(payload);
    console.log(`[FCM Broadcast] Sent: ${response.successCount} succeeded, ${response.failureCount} failed out of ${uniqueTokens.length} devices.`);

    try {
      await supabase.from('notifications').insert({
        title,
        body,
        type: 'broadcast',
        status: 'sent',
        recipients_count: response.successCount,
      });
    } catch (_) {}

    return res.json({
      success: true,
      totalTargeted: uniqueTokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  } catch (err) {
    console.error('[FCM Broadcast Error]:', err);
    return res.status(500).json({ error: err.message || 'Failed to dispatch broadcast notification.' });
  }
});

// 3. Send targeted notification to a single customer by Phone / User ID
app.post('/api/notifications/send-to-user', async (req, res) => {
  if (!firebaseAdmin) {
    return res.status(500).json({ error: 'Firebase Admin is not configured. Check serviceAccountKey.json.' });
  }

  const { userId, phone, title, body, screen, data } = req.body;
  const target = normalizePhone(phone || userId);

  if (!target || !title || !body) {
    return res.status(400).json({ error: 'Customer identifier (phone/userId), title, and body are required.' });
  }

  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('id, fcm_token, full_name')
      .or(`id.eq.${target},mobile.eq.${target}`)
      .maybeSingle();

    if (error) throw error;

    if (!user || !user.fcm_token) {
      return res.status(404).json({
        success: false,
        message: `Customer (${target}) has not registered an FCM token yet. They must log in on the app at least once.`,
      });
    }

    const message = {
      token: user.fcm_token,
      notification: {
        title,
        body,
      },
      data: {
        screen: screen || 'home',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        ...(data || {}),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'sabzee_orders_channel',
          sound: 'default',
        },
      },
    };

    const messageId = await admin.messaging().send(message);
    console.log(`[FCM Direct] Notification sent to ${target} (${messageId})`);

    try {
      await supabase.from('notifications').insert({
        title,
        body,
        type: 'direct',
        status: 'sent',
        user_id: target,
      });
    } catch (_) {}

    return res.json({
      success: true,
      messageId,
      customerName: user.full_name,
    });
  } catch (err) {
    console.error('[FCM Direct Error]:', err);
    return res.status(500).json({ error: err.message || 'Failed to send direct notification.' });
  }
});

// 4. Send Order Status notification when order state changes in Admin Panel
app.post('/api/notifications/order-status', async (req, res) => {
  if (!firebaseAdmin) {
    return res.status(500).json({ error: 'Firebase Admin is not configured. Check serviceAccountKey.json.' });
  }

  const { orderId, userId, newStatus, riderName, riderPhone } = req.body;
  if (!orderId || !newStatus) {
    return res.status(400).json({ error: 'orderId and newStatus are required.' });
  }

  const shortId = String(orderId).slice(0, 8);
  const statusConfig = {
    confirmed: {
      title: 'Order Confirmed! 🥕',
      body: `Your Sabzee order #${shortId} has been confirmed. Fresh veggies are being packed right now!`,
    },
    out_for_delivery: {
      title: 'Out for Delivery! 🛵',
      body: `Your order #${shortId} is on its way with ${riderName || 'our delivery partner'}${riderPhone ? ` (${riderPhone})` : ''}. Stay ready!`,
    },
    delivered: {
      title: 'Order Delivered! 🥗',
      body: `Your fresh items for order #${shortId} have been delivered safely. Thank you for shopping with SabzeeWala!`,
    },
    cancelled: {
      title: 'Order Cancelled ❌',
      body: `Your order #${shortId} was cancelled. If paid online, your refund is processed to your wallet.`,
    },
  };

  const alert = statusConfig[String(newStatus).toLowerCase()];
  if (!alert) {
    return res.json({ success: true, message: `No push notification configured for status: ${newStatus}` });
  }

  try {
    let fcmToken = null;
    let targetUser = userId;

    if (!targetUser) {
      const { data: order } = await supabase
        .from('orders')
        .select('user_id')
        .eq('id', orderId)
        .maybeSingle();
      targetUser = order?.user_id;
    }

    if (targetUser) {
      const normalized = normalizePhone(targetUser);
      const { data: user } = await supabase
        .from('users')
        .select('fcm_token')
        .or(`id.eq.${normalized},mobile.eq.${normalized}`)
        .maybeSingle();
      fcmToken = user?.fcm_token;
    }

    if (!fcmToken) {
      console.log(`[FCM Order Alert] No active FCM token found for customer: ${targetUser}`);
      return res.json({
        success: false,
        message: 'Order updated, but customer has no active device token registered.',
      });
    }

    const message = {
      token: fcmToken,
      notification: {
        title: alert.title,
        body: alert.body,
      },
      data: {
        screen: 'orders',
        orderId: String(orderId),
        status: String(newStatus),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'sabzee_orders_channel',
          sound: 'default',
        },
      },
    };

    const messageId = await admin.messaging().send(message);
    console.log(`[FCM Order Alert] Sent status '${newStatus}' for order #${shortId} to ${targetUser}`);

    return res.json({ success: true, messageId, status: newStatus });
  } catch (err) {
    console.error('[FCM Order Alert Error]:', err);
    return res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// Cashfree Payment Gateway Integration
// -------------------------------------------------------------
const CASHFREE_APP_ID = process.env.CASHFREE_APP_ID;
const CASHFREE_SECRET_KEY = process.env.CASHFREE_SECRET_KEY;
const CASHFREE_ENV = (process.env.CASHFREE_ENV || 'SANDBOX').toUpperCase();
const CASHFREE_API_VERSION = process.env.CASHFREE_API_VERSION || '2023-08-01';

const CASHFREE_BASE_URL =
  CASHFREE_ENV === 'PRODUCTION'
    ? 'https://api.cashfree.com/pg'
    : 'https://sandbox.cashfree.com/pg';

/**
 * POST /api/cashfree/create-order
 * Request body: { orderId, orderAmount, customerId, customerPhone, customerName, customerEmail }
 * Returns: { success: true, paymentSessionId, orderId, cfOrderId, environment }
 */
app.post('/api/cashfree/create-order', async (req, res) => {
  try {
    const { orderId, orderAmount, customerId, customerPhone, customerName, customerEmail } = req.body;

    if (!orderId || !orderAmount || !customerPhone) {
      return res.status(400).json({
        error: 'Missing required fields: orderId, orderAmount, and customerPhone are required.',
      });
    }

    if (!CASHFREE_APP_ID || !CASHFREE_SECRET_KEY) {
      return res.status(500).json({
        error: 'Cashfree credentials (CASHFREE_APP_ID, CASHFREE_SECRET_KEY) are not configured in backend/.env',
      });
    }

    const cleanPhone = normalizePhone(customerPhone).slice(-10);
    const amountVal = Number(parseFloat(orderAmount).toFixed(2));

    const payload = {
      order_id: String(orderId),
      order_amount: amountVal,
      order_currency: 'INR',
      customer_details: {
        customer_id: String(customerId || cleanPhone || `CUST_${Date.now()}`),
        customer_phone: cleanPhone,
        customer_name: customerName || 'Customer',
        customer_email: customerEmail || 'customer@sabzeewala.com',
      },
      order_meta: {
        return_url: `https://sabzeewala.com/payment-status?order_id=${orderId}`,
      },
    };

    console.log(`[Cashfree] Creating order in ${CASHFREE_ENV} mode:`, payload);

    const response = await axios.post(`${CASHFREE_BASE_URL}/orders`, payload, {
      headers: {
        'x-client-id': CASHFREE_APP_ID,
        'x-client-secret': CASHFREE_SECRET_KEY,
        'x-api-version': CASHFREE_API_VERSION,
        'Content-Type': 'application/json',
      },
    });

    const data = response.data || {};
    console.log(`[Cashfree] Order created successfully: ${data.order_id}, session: ${data.payment_session_id}`);

    return res.json({
      success: true,
      paymentSessionId: data.payment_session_id,
      orderId: data.order_id,
      cfOrderId: data.cf_order_id,
      environment: CASHFREE_ENV,
    });
  } catch (error) {
    const errData = error.response?.data || {};
    console.error('[Cashfree Create Order Error]:', errData || error.message);
    return res.status(error.response?.status || 500).json({
      error: errData.message || error.message || 'Failed to create Cashfree order',
      details: errData,
    });
  }
});

/**
 * GET /api/cashfree/order-status/:orderId
 * Fetches order payment status directly from Cashfree
 */
/**
 * Safely credit a user's wallet in Supabase and record transaction (Idempotent)
 */
async function creditUserWallet({ userId, amount, orderId, description }) {
  if (!userId || !amount || Number(amount) <= 0) {
    throw new Error('Invalid userId or amount');
  }

  const cleanPhone = String(userId).replace(/\D/g, '');
  const last10 = cleanPhone.slice(-10);

  // 1. Check idempotency: If this orderId was already credited, skip duplicate
  if (orderId) {
    const { data: existingTx } = await supabase
      .from('wallet_transactions')
      .select('id, amount')
      .ilike('description', `%${orderId}%`)
      .maybeSingle();

    if (existingTx) {
      console.log(`[Wallet] Order ${orderId} already credited (Tx: ${existingTx.id}). Skipping duplicate credit.`);
      const { data: u } = await supabase
        .from('users')
        .select('wallet_balance')
        .or(`id.eq.${userId},mobile.eq.${userId},id.eq.${cleanPhone},mobile.eq.${cleanPhone},id.eq.${last10},mobile.eq.${last10}`)
        .maybeSingle();
      return {
        alreadyProcessed: true,
        newBalance: Number(u?.wallet_balance || 0),
        amountCredited: Number(existingTx.amount || amount),
      };
    }
  }

  // 2. Fetch current user from Supabase
  const { data: user, error: userErr } = await supabase
    .from('users')
    .select('id, wallet_balance, fcm_token, full_name, mobile')
    .or(`id.eq.${userId},mobile.eq.${userId},id.eq.${cleanPhone},mobile.eq.${cleanPhone},id.eq.${last10},mobile.eq.${last10}`)
    .maybeSingle();

  if (userErr) {
    console.warn('[Wallet] User lookup warning:', userErr.message);
  }

  const targetId = user?.id || (cleanPhone.length >= 10 ? cleanPhone : userId);
  const currentBalance = Number(user?.wallet_balance || 0);
  const nextBalance = Number((currentBalance + Number(amount)).toFixed(2));

  // 3. Update users table with new balance
  const { error: updateErr } = await supabase
    .from('users')
    .update({ wallet_balance: nextBalance })
    .eq('id', targetId);

  if (updateErr) {
    console.error('[Wallet] Update balance error:', updateErr.message);
    throw new Error(`Failed to update user wallet balance: ${updateErr.message}`);
  }

  // 4. Insert log into wallet_transactions
  const txDesc = description || `Added cash to wallet via Cashfree (${orderId || 'direct'})`;
  const { data: txRow, error: txErr } = await supabase
    .from('wallet_transactions')
    .insert({
      user_id: targetId,
      amount: Number(amount),
      type: 'deposit',
      description: txDesc,
      status: 'completed',
    })
    .select()
    .maybeSingle();

  if (txErr) {
    console.error('[Wallet] Insert transaction record error:', txErr.message);
  }

  // 5. Send real-time Push Notification via FCM if token is present
  if (firebaseAdmin && user?.fcm_token) {
    try {
      await admin.messaging().send({
        token: user.fcm_token,
        notification: {
          title: 'Wallet Recharged! 💰',
          body: `₹${Number(amount).toFixed(0)} has been successfully credited to your Sabzee Wallet.`,
        },
        data: {
          screen: 'wallet',
          orderId: String(orderId || ''),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'sabzee_orders_channel',
            sound: 'default',
          },
        },
      });
      console.log(`[Wallet] Push notification sent to ${targetId}`);
    } catch (fcmErr) {
      console.warn('[Wallet] FCM notification warning:', fcmErr.message);
    }
  }

  return {
    alreadyProcessed: false,
    newBalance: nextBalance,
    amountCredited: Number(amount),
    transaction: txRow,
  };
}

/**
 * POST /api/wallet/create-order
 * Initiates a Cashfree payment order specifically for Wallet Top-up
 */
app.post('/api/wallet/create-order', async (req, res) => {
  try {
    const { userId, amount, customerPhone, customerName, customerEmail } = req.body;

    if (!amount || Number(amount) < 1) {
      return res.status(400).json({ error: 'Deposit amount must be at least ₹1.' });
    }

    const phone = customerPhone || userId;
    if (!phone) {
      return res.status(400).json({ error: 'Customer phone or userId is required.' });
    }

    if (!CASHFREE_APP_ID || !CASHFREE_SECRET_KEY) {
      return res.status(500).json({
        error: 'Cashfree credentials (CASHFREE_APP_ID, CASHFREE_SECRET_KEY) are not configured in backend/.env',
      });
    }

    const cleanPhone = normalizePhone(phone).slice(-10);
    const amountVal = Number(parseFloat(amount).toFixed(2));
    const orderId = `WLT_${Date.now()}_${Math.floor(100 + Math.random() * 900)}`;

    const orderMeta = {
      return_url: `https://sabzeewala.com/payment-status?order_id=${orderId}`,
    };
    const webhookBase = process.env.WEBHOOK_BASE_URL || (req.protocol === 'https' ? `${req.protocol}://${req.get('host')}` : null);
    if (webhookBase && webhookBase.startsWith('https://')) {
      orderMeta.notify_url = `${webhookBase}/api/cashfree/webhook`;
    }

    const payload = {
      order_id: orderId,
      order_amount: amountVal,
      order_currency: 'INR',
      customer_details: {
        customer_id: `CUST_${cleanPhone}`,
        customer_phone: cleanPhone,
        customer_name: customerName || 'Sabzee Customer',
        customer_email: customerEmail || 'customer@sabzeewala.com',
      },
      order_meta: orderMeta,
      order_tags: {
        type: 'wallet_topup',
        user_id: String(userId || phone),
      },
    };

    console.log(`[Wallet] Creating top-up order in ${CASHFREE_ENV} mode:`, payload);

    const response = await axios.post(`${CASHFREE_BASE_URL}/orders`, payload, {
      headers: {
        'x-client-id': CASHFREE_APP_ID,
        'x-client-secret': CASHFREE_SECRET_KEY,
        'x-api-version': CASHFREE_API_VERSION,
        'Content-Type': 'application/json',
      },
    });

    const data = response.data || {};
    console.log(`[Wallet] Top-up order created: ${data.order_id}, session: ${data.payment_session_id}`);

    return res.json({
      success: true,
      orderId: data.order_id || orderId,
      paymentSessionId: data.payment_session_id,
      amount: amountVal,
      environment: CASHFREE_ENV,
    });
  } catch (error) {
    const errData = error.response?.data || {};
    console.error('[Wallet Create Order Error]:', errData || error.message);
    return res.status(error.response?.status || 500).json({
      error: errData.message || error.message || 'Failed to create wallet top-up order',
      details: errData,
    });
  }
});

/**
 * POST /api/wallet/verify-order
 * Verifies with Cashfree whether a top-up was PAID and securely credits wallet balance in Supabase
 */
app.post('/api/wallet/verify-order', async (req, res) => {
  try {
    const { orderId, userId } = req.body;

    if (!orderId) {
      return res.status(400).json({ error: 'orderId is required' });
    }

    if (!CASHFREE_APP_ID || !CASHFREE_SECRET_KEY) {
      return res.status(500).json({ error: 'Cashfree credentials not configured' });
    }

    const response = await axios.get(`${CASHFREE_BASE_URL}/orders/${orderId}`, {
      headers: {
        'x-client-id': CASHFREE_APP_ID,
        'x-client-secret': CASHFREE_SECRET_KEY,
        'x-api-version': CASHFREE_API_VERSION,
      },
    });

    const data = response.data || {};
    const isPaid = data.order_status === 'PAID';

    if (!isPaid) {
      return res.status(400).json({
        success: false,
        orderStatus: data.order_status,
        message: `Payment status is ${data.order_status}. Wallet will only be credited for PAID transactions.`,
      });
    }

    const orderAmount = Number(data.order_amount || 0);
    const targetUser = userId || data.order_tags?.user_id || data.customer_details?.customer_phone;

    if (!targetUser) {
      return res.status(400).json({ error: 'Unable to identify user for this order.' });
    }

    const result = await creditUserWallet({
      userId: targetUser,
      amount: orderAmount,
      orderId: orderId,
      description: `Added cash to wallet via Cashfree (Order #${orderId.slice(-8)})`,
    });

    return res.json({
      success: true,
      orderStatus: data.order_status,
      amountAdded: orderAmount,
      newBalance: result.newBalance,
      alreadyProcessed: result.alreadyProcessed,
      message: 'Wallet credited successfully',
    });
  } catch (error) {
    const errData = error.response?.data || {};
    console.error('[Wallet Verify Order Error]:', errData || error.message);
    return res.status(error.response?.status || 500).json({
      error: errData.message || error.message || 'Failed to verify wallet order',
      details: errData,
    });
  }
});

/**
 * GET /api/wallet/balance/:userId
 * Returns latest balance & recent transaction logs for a user
 */
app.get('/api/wallet/balance/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const cleanPhone = String(userId).replace(/\D/g, '');
    const last10 = cleanPhone.slice(-10);

    const { data: user } = await supabase
      .from('users')
      .select('id, wallet_balance')
      .or(`id.eq.${userId},mobile.eq.${userId},id.eq.${cleanPhone},mobile.eq.${cleanPhone},id.eq.${last10},mobile.eq.${last10}`)
      .maybeSingle();

    const currentId = user?.id || userId;
    const { data: txRows } = await supabase
      .from('wallet_transactions')
      .select('*')
      .or(`user_id.eq.${currentId},user_id.eq.${cleanPhone},user_id.eq.${last10}`)
      .order('created_at', { ascending: false })
      .limit(30);

    return res.json({
      success: true,
      balance: Number(user?.wallet_balance || 0),
      transactions: txRows || [],
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/cashfree/order-status/:orderId
 * Fetches order payment status directly from Cashfree
 */
app.get('/api/cashfree/order-status/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;
    if (!orderId) {
      return res.status(400).json({ error: 'Order ID is required' });
    }

    const response = await axios.get(`${CASHFREE_BASE_URL}/orders/${orderId}`, {
      headers: {
        'x-client-id': CASHFREE_APP_ID,
        'x-client-secret': CASHFREE_SECRET_KEY,
        'x-api-version': CASHFREE_API_VERSION,
      },
    });

    const data = response.data || {};
    const isPaid = data.order_status === 'PAID';

    // If paid, update Supabase order or wallet
    if (isPaid) {
      if (orderId.startsWith('WLT_') || orderId.startsWith('WALLET_')) {
        const targetUser = data.order_tags?.user_id || data.customer_details?.customer_phone;
        if (targetUser) {
          try {
            await creditUserWallet({
              userId: targetUser,
              amount: Number(data.order_amount || 0),
              orderId,
              description: `Added cash to wallet via Cashfree (Order #${orderId.slice(-8)})`,
            });
          } catch (wErr) {
            console.warn('[Wallet Status Sync Warning]:', wErr.message);
          }
        }
      } else {
        try {
          await supabase
            .from('orders')
            .update({ payment_status: 'paid' })
            .eq('id', orderId);
        } catch (dbErr) {
          console.warn('[Cashfree Status Sync Warning]:', dbErr.message);
        }
      }
    }

    return res.json({
      success: true,
      orderStatus: data.order_status,
      isPaid,
      data,
    });
  } catch (error) {
    const errData = error.response?.data || {};
    console.error('[Cashfree Status Error]:', errData || error.message);
    return res.status(error.response?.status || 500).json({
      error: errData.message || error.message || 'Failed to verify Cashfree order',
      details: errData,
    });
  }
});

/**
 * POST /api/cashfree/webhook
 * Cashfree Server-to-Server Webhook handler
 */
app.post('/api/cashfree/webhook', async (req, res) => {
  try {
    const event = req.body || {};
    console.log('[Cashfree Webhook]:', JSON.stringify(event));

    // Handle payment success event
    const isSuccess =
      event.type === 'PAYMENT_SUCCESS_WEBHOOK' ||
      event.data?.payment?.payment_status === 'SUCCESS';

    if (isSuccess) {
      const orderId = event.data?.order?.order_id;
      if (orderId) {
        if (orderId.startsWith('WLT_') || orderId.startsWith('WALLET_')) {
          const orderAmount = Number(event.data?.order?.order_amount || event.data?.payment?.payment_amount || 0);
          const targetUser = event.data?.order?.order_tags?.user_id ||
                             event.data?.customer_details?.customer_phone;
          if (targetUser && orderAmount > 0) {
            try {
              await creditUserWallet({
                userId: targetUser,
                amount: orderAmount,
                orderId,
                description: `Added cash to wallet via Cashfree Webhook (Order #${orderId.slice(-8)})`,
              });
              console.log(`[Cashfree Webhook] Credited ₹${orderAmount} to wallet for user ${targetUser}`);
            } catch (wErr) {
              console.error('[Cashfree Webhook Wallet Error]:', wErr.message);
            }
          }
        } else {
          await supabase
            .from('orders')
            .update({ payment_status: 'paid' })
            .eq('id', orderId);
          console.log(`[Cashfree Webhook] Order #${orderId} marked as paid in Supabase.`);
        }
      }
    }

    return res.json({ received: true });
  } catch (err) {
    console.error('[Cashfree Webhook Error]:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

app.get('/', (_req, res) => {
  res.json({
    status: 'online',
    service: 'Sabzee Backend API',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/health', (_req, res) => {
  res.json({
    ok: true,
    msg91WidgetConfigured: Boolean(MSG91_WIDGET_ID && MSG91_WIDGET_AUTH_KEY),
    widgetId: MSG91_WIDGET_ID ? `${MSG91_WIDGET_ID.slice(0, 6)}…` : null,
    endpoint: `${WIDGET_BASE}/sendOtpMobile`,
  });
});

app.listen(PORT, () => {
  console.log(`Sabzee Auth Backend is running on port ${PORT}`);
  console.log(
    `MSG91 Widget: ${MSG91_WIDGET_ID ? 'configured' : 'MISSING'} → ${WIDGET_BASE}/sendOtpMobile`
  );
});
