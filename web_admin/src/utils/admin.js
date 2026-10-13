/** Shared helpers for Sabzee admin (existing Supabase tables only) */
import { supabase } from '../supabase';

export function money(n) {
  return `₹${Number(n || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
}

export function orderTotal(order) {
  if (order?.total != null && Number(order.total) > 0) return Number(order.total);
  const items = order?.order_items || [];
  const sum = items.reduce((s, i) => s + Number(i.price || 0) * Number(i.quantity || 0), 0);
  return sum + Number(order?.delivery_fee || 0);
}

export function phoneOf(p) {
  return p?.phone || p?.mobile || '—';
}

export function statusPill(status) {
  const s = String(status || '').toLowerCase();
  if (['active', 'delivered', 'paid', 'online', 'approved', 'received'].includes(s)) return 'ok';
  if (['placed', 'pending', 'accepted', 'packed', 'ready', 'shipped'].includes(s)) return 'warn';
  if (['blocked', 'rejected', 'cancelled', 'canceled', 'out of stock', 'inactive'].includes(s)) return 'danger';
  return 'muted';
}

export function startOfDay(d = new Date()) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

export function startOfMonth(d = new Date()) {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

export async function safeSelect(table, queryFn) {
  try {
    const q = queryFn ? queryFn(supabase.from(table)) : supabase.from(table).select('*');
    const { data, error } = await q;
    if (error) return { data: [], error, missing: /does not exist|PGRST|42P01|schema cache/i.test(error.message) };
    return { data: data || [], error: null, missing: false };
  } catch (e) {
    return { data: [], error: e, missing: true };
  }
}

export function downloadCsv(filename, rows) {
  const csv = rows.map((r) => r.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export const ORDER_TABS = [
  { id: 'all', label: 'All' },
  { id: 'placed', label: 'Pending' },
  { id: 'accepted', label: 'Accepted' },
  { id: 'packed', label: 'Packed' },
  { id: 'ready', label: 'Ready' },
  { id: 'shipped', label: 'Out for Delivery' },
  { id: 'delivered', label: 'Delivered' },
  { id: 'cancelled', label: 'Cancelled' },
  { id: 'rejected', label: 'Rejected' },
  { id: 'returned', label: 'Returned' },
];
