/** Shared admin config — mirrors Flutter + Express backend */
export const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL || 'https://mhqyaqvnlurqamojelae.supabase.co';
export const SUPABASE_ANON_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ocXlhcXZubHVycWFtb2plbGFlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTg4NTIwNiwiZXhwIjoyMTA3NDYxMjA2fQ.Nmb5WhS0INMzJtzJHUDVRF0rFulzD8qAEJ9Ngt8SzMI';
export const STORAGE_BUCKET = 'SabzeeWala';

/** Express MSG91 OTP API (same backend the mobile app uses) */
export const AUTH_API_URL =
  import.meta.env.VITE_AUTH_API_URL ||
  import.meta.env.VITE_API_URL ||
  'https://sabzeewala.onrender.com';

/** Backend API URL for Push Notifications and Server Endpoints */
export const NOTIFICATION_API_URL =
  (typeof window !== 'undefined' && localStorage.getItem('sabzee_backend_url')) ||
  import.meta.env.VITE_API_URL ||
  import.meta.env.VITE_AUTH_API_URL ||
  'https://sabzeewala.onrender.com';

export function formatPhoneE164(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (digits.startsWith('91') && digits.length === 12) return digits;
  if (digits.length === 10) return `91${digits}`;
  return digits;
}

export function normalizePaymentMethod(method) {
  if (!method) return '—';
  const m = String(method).toUpperCase();
  if (m === 'COD' || m.includes('COD')) return 'COD';
  if (m === 'UPI' || m.includes('UPI')) return 'UPI';
  if (m === 'CARD' || m.includes('CARD') || m.includes('DEBIT') || m.includes('CREDIT')) return 'CARD';
  return 'ONLINE';
}

export function orderGrandTotal(order) {
  const items = order?.order_items || [];
  const itemsTotal = items.reduce(
    (sum, item) => sum + Number(item.price || 0) * Number(item.quantity || 0),
    0
  );
  if (order?.total != null && Number(order.total) > 0) {
    return Number(order.total);
  }
  return itemsTotal + Number(order?.delivery_fee || 0);
}
