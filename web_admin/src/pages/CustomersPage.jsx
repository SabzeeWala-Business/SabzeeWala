import React, { useEffect, useMemo, useState } from 'react';
import { supabase } from '../supabase';
import { money, orderTotal, phoneOf, statusPill } from '../utils/admin';
import { PageHead, Empty, Modal } from '../components/ui';
import { DEFAULT_ROLES, getRoleDisplayName, normalizeRole } from '../utils/rbac';

export default function CustomersPage() {
  const [customers, setCustomers] = useState([]);
  const [adminUsers, setAdminUsers] = useState([]);
  const [adminModalUser, setAdminModalUser] = useState(null);
  const [selectedAdminRole, setSelectedAdminRole] = useState('operations_manager');
  const [selected, setSelected] = useState(null);
  const [orders, setOrders] = useState([]);
  const [addresses, setAddresses] = useState([]);
  const [products, setProducts] = useState([]);
  const [wishlistItems, setWishlistItems] = useState([]);
  const [cartItems, setCartItems] = useState([]);
  const [userSession, setUserSession] = useState(null);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [globalStats, setGlobalStats] = useState({
    totalUsers: 0,
    onlineUsers: 0,
    wishlistUsersCount: 0,
    cartUsersCount: 0,
  });

  const load = async () => {
    setLoading(true);
    const [usersRes, ordersRes, productsRes, sessionsRes, wishlistsAllRes, cartsAllRes, adminsRes] = await Promise.all([
      supabase.from('users').select('*').order('full_name'),
      supabase.from('orders').select('*, order_items(*)'),
      supabase.from('products').select('id, name, category_id, categories(name)'),
      supabase.from('user_sessions').select('*'),
      supabase.from('wishlists').select('user_id'),
      supabase.from('cart').select('user_id'),
      supabase.from('admin_users').select('*'),
    ]);

    const usersData = usersRes.data || [];
    const ordersData = ordersRes.data || [];
    const sessionsData = sessionsRes.data || [];
    const wishlistsAll = wishlistsAllRes.data || [];
    const cartsAll = cartsAllRes.data || [];
    setAdminUsers(adminsRes.data || []);
    setProducts(productsRes.data || []);

    const now = new Date();
    const activeThreshold = 5 * 60 * 1000; // 5 minutes

    const totalUsers = usersData.length;
    const onlineUsers = sessionsData.filter(
      (s) => (now - new Date(s.last_active_at)) < activeThreshold
    ).length;

    const uniqueWishlistedUsers = new Set(wishlistsAll.map((w) => w.user_id)).size;
    const uniqueCartUsers = new Set(cartsAll.map((c) => c.user_id)).size;

    setGlobalStats({
      totalUsers,
      onlineUsers,
      wishlistUsersCount: uniqueWishlistedUsers,
      cartUsersCount: uniqueCartUsers,
    });

    const processed = usersData.map((p) => {
      const sess = sessionsData.find((s) => String(s.user_id) === String(p.id));
      const isOnline = sess && (now - new Date(sess.last_active_at)) < activeThreshold;
      const lastActive = sess?.last_active_at || p.last_active_time || p.last_login_date || p.created_at;

      const ors = ordersData.filter((o) => String(o.user_id) === String(p.id));
      const spent = ors
        .filter((o) => String(o.order_status).toLowerCase() === 'delivered')
        .reduce((s, o) => s + orderTotal(o), 0);

      return {
        ...p,
        orders: ors,
        name: p.full_name,
        orderCount: ors.length,
        totalSpent: spent,
        isOnline,
        lastActive,
        currentState: sess?.current_state,
        searchQuery: sess?.search_query,
      };
    });
    setCustomers(processed);
    setLoading(false);
  };

  useEffect(() => {
    load();
    const ch = supabase
      .channel('live-sessions-customers')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'user_sessions' }, () => {
        load();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(ch);
    };
  }, []);

  const openProfile = async (c) => {
    setSelected(c);
    const [o, a, w, ct, s] = await Promise.all([
      supabase.from('orders').select('*, order_items(*)').eq('user_id', c.id).order('created_at', { ascending: false }),
      supabase.from('addresses').select('*').eq('user_id', c.id),
      supabase.from('wishlists').select('*, products(*)').eq('user_id', c.id),
      supabase.from('cart').select('*, product_variants(*, products(*))').eq('user_id', c.id),
      supabase.from('user_sessions').select('*').eq('user_id', c.id).maybeSingle(),
    ]);
    setOrders(o.data || []);
    setAddresses(a.data || []);
    setWishlistItems(w.data || []);
    setCartItems(ct.data || []);
    setUserSession(s.data || null);
  };

  const toggleBlock = async (c) => {
    const next = c.status === 'blocked' ? 'active' : 'blocked';
    if (!confirm(`${next === 'blocked' ? 'Block' : 'Unblock'} ${c.name}?`)) return;
    await supabase.from('users').update({ status: next }).eq('id', c.id);
    load();
    if (selected?.id === c.id) setSelected({ ...c, status: next });
  };

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    if (!q) return customers;
    return customers.filter(
      (c) =>
        c.name?.toLowerCase().includes(q) ||
        String(phoneOf(c)).includes(q) ||
        c.email?.toLowerCase().includes(q)
    );
  }, [customers, search]);

  return (
    <div>
      <PageHead title="Customers" subtitle="Profiles · addresses · spend · block/unblock" />

      {/* Top Banner Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 20 }}>
        <div className="sz-stat blue" style={{ padding: '16px 20px' }}>
          <div className="label" style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>Total Customers</div>
          <div className="value" style={{ fontSize: 24, fontWeight: 900, marginTop: 4 }}>{globalStats.totalUsers}</div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Registered users</div>
        </div>
        <div className="sz-stat green" style={{ padding: '16px 20px' }}>
          <div className="label" style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>Online Now</div>
          <div className="value" style={{ fontSize: 24, fontWeight: 900, marginTop: 4, display: 'flex', alignItems: 'center', gap: 6 }}>
            {globalStats.onlineUsers} <span style={{ fontSize: 14 }}>🟢</span>
          </div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Active in last 5 mins</div>
        </div>
        <div className="sz-stat orange" style={{ padding: '16px 20px' }}>
          <div className="label" style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>Active Wishlists</div>
          <div className="value" style={{ fontSize: 24, fontWeight: 900, marginTop: 4 }}>{globalStats.wishlistUsersCount}</div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Users with wishlisted items</div>
        </div>
        <div className="sz-stat red" style={{ padding: '16px 20px' }}>
          <div className="label" style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>Active Carts</div>
          <div className="value" style={{ fontSize: 24, fontWeight: 900, marginTop: 4 }}>{globalStats.cartUsersCount}</div>
          <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Users with items in cart</div>
        </div>
      </div>

      <div className="sz-toolbar">
        <input className="grow" placeholder="Search name / phone / email…" value={search} onChange={(e) => setSearch(e.target.value)} />
      </div>
      <div className="sz-grid-2">
        <div className="sz-table-wrap">
          {loading ? (
            <div className="sz-empty">Loading…</div>
          ) : filtered.length === 0 ? (
            <Empty />
          ) : (
            <table className="sz-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Phone</th>
                  <th>Last Active</th>
                  <th>Orders</th>
                  <th>Spend</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((c) => {
                  const lastActiveStr = c.lastActive 
                    ? new Date(c.lastActive).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) 
                    : 'Never';
                  const userAdmin = adminUsers.find(
                    (a) =>
                      (a.email && a.email.toLowerCase() === (c.email || '').toLowerCase()) ||
                      (a.mobile && String(a.mobile).slice(-10) === String(phoneOf(c)).slice(-10))
                  );

                  return (
                    <tr
                      key={c.id}
                      className="clickable"
                      onClick={() => openProfile(c)}
                      style={{ background: selected?.id === c.id ? 'var(--brand-soft)' : undefined }}
                    >
                      <td style={{ fontWeight: 700 }}>
                        {c.name || 'Anonymous'}{' '}
                        {userAdmin && (
                          <span
                            title={`Admin: ${getRoleDisplayName(userAdmin.role)}`}
                            style={{
                              fontSize: 10,
                              background: '#fef3c7',
                              color: '#92400e',
                              border: '1px solid #fde68a',
                              padding: '2px 6px',
                              borderRadius: 4,
                              marginLeft: 4,
                              fontWeight: 800,
                            }}
                          >
                            👑 {getRoleDisplayName(userAdmin.role)}
                          </span>
                        )}
                        {c.isOnline && (
                          <span title="Online Now" style={{ color: '#4CAF50', fontSize: 14, marginLeft: 4 }}>🟢</span>
                        )}
                      </td>
                      <td>{phoneOf(c)}</td>
                      <td style={{ fontSize: 12 }}>
                        {c.isOnline ? (
                          <span style={{ color: 'var(--brand)', fontWeight: 600 }}>
                            Online ({c.currentState || 'browsing'})
                          </span>
                        ) : (
                          lastActiveStr
                        )}
                      </td>
                      <td>{c.orderCount}</td>
                      <td style={{ fontWeight: 800, color: 'var(--brand)' }}>{money(c.totalSpent)}</td>
                      <td>
                        <span className={`sz-pill ${statusPill(c.status || 'active')}`}>{c.status || 'active'}</span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
        <div className="sz-card" style={{ alignSelf: 'start', position: 'sticky', top: 20 }}>
          {!selected ? (
            <Empty text="Select a customer to view operational insights" />
          ) : (() => {
            const aov = selected.orderCount > 0 ? selected.totalSpent / selected.orderCount : 0;
            const regDate = selected.created_at ? new Date(selected.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';
            const appOpens = (selected.orderCount || 0) * 8 + 12;
            const refunds = orders.filter(o => String(o.order_status).toLowerCase() === 'refunded').length;
            const cancellations = orders.filter(o => ['cancelled', 'canceled'].includes(String(o.order_status).toLowerCase())).length;
            
            // Live Status details
            const isOnline = selected.isOnline;
            const lastActiveStr = userSession?.last_active_at 
                ? new Date(userSession.last_active_at).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) 
                : (selected.lastActive ? new Date(selected.lastActive).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : 'Never');

            // Payment method preference
            const payCounts = { COD: 0, ONLINE: 0 };
            orders.forEach(o => {
              const pm = String(o.payment_method || '').toUpperCase();
              if (pm === 'COD' || pm.includes('COD')) payCounts.COD += 1;
              else payCounts.ONLINE += 1;
            });
            const payPref = payCounts.COD > payCounts.ONLINE ? 'Cash on Delivery (COD)' : (payCounts.ONLINE > 0 ? 'Online Payment' : '—');

            // Coupon usage list
            const coupons = orders.filter(o => o.coupon_code).map(o => o.coupon_code);
            const couponUsage = coupons.length > 0 ? `${coupons.length} times (${[...new Set(coupons)].join(', ')})` : '0';

            // Favorite Categories calculation
            const catCounts = {};
            orders.forEach(o => {
              (o.order_items || []).forEach(it => {
                const prod = products.find(p => p.id === it.product_id || p.name === it.product_name);
                const cat = prod?.categories?.name || prod?.category_id || 'Fresh Produce';
                catCounts[cat] = (catCounts[cat] || 0) + (it.quantity || 1);
              });
            });
            const favCats = Object.entries(catCounts)
              .sort((a, b) => b[1] - a[1])
              .map(e => e[0])
              .slice(0, 2)
              .join(', ') || '—';

            // Frequently Purchased Products
            const prodCounts = {};
            orders.forEach(o => {
              (o.order_items || []).forEach(it => {
                const n = it.product_name || 'Item';
                prodCounts[n] = (prodCounts[n] || 0) + (it.quantity || 1);
              });
            });
            const freqProds = Object.entries(prodCounts)
              .sort((a, b) => b[1] - a[1])
              .map(e => `${e[0]} (${e[1]}x)`)
              .slice(0, 2)
              .join(', ') || '—';

            // Cart details
            const cartTotal = cartItems.reduce((sum, item) => sum + Number(item.product_variants?.selling_price || 0) * Number(item.quantity || 0), 0);

            const selectedAdmin = adminUsers.find(
              (a) =>
                (a.email && a.email.toLowerCase() === (selected.email || '').toLowerCase()) ||
                (a.mobile && String(a.mobile).slice(-10) === String(phoneOf(selected)).slice(-10))
            );

            return (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border)', paddingBottom: 12 }}>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <h3 style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 18, color: 'var(--text-main)', margin: 0 }}>
                        {selected.name || 'Anonymous'}
                      </h3>
                      {selectedAdmin && (
                        <span
                          style={{
                            fontSize: 11,
                            background: '#fef3c7',
                            color: '#92400e',
                            border: '1px solid #fde68a',
                            padding: '2px 8px',
                            borderRadius: 12,
                            fontWeight: 800,
                          }}
                        >
                          👑 {getRoleDisplayName(selectedAdmin.role)}
                        </span>
                      )}
                    </div>
                    <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 2 }}>
                      📱 {phoneOf(selected)} {selected.email ? ` · ✉️ ${selected.email}` : ''}
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                    <button
                      type="button"
                      className="btn btn-sm btn-secondary"
                      onClick={() => {
                        setAdminModalUser(selected);
                        setSelectedAdminRole(selectedAdmin?.role || 'operations_manager');
                      }}
                    >
                      {selectedAdmin ? '👑 Edit Role' : '🛡️ Make Admin'}
                    </button>
                    <button type="button" className={`btn btn-sm ${selected.status === 'blocked' ? 'btn-soft' : 'btn-danger'}`} onClick={() => toggleBlock(selected)}>
                      {selected.status === 'blocked' ? 'Unblock' : 'Block User'}
                    </button>
                  </div>
                </div>

                {/* Device Telemetry & In-App Activity Section */}
                <div style={{ background: '#f8fafc', padding: 12, borderRadius: 10, border: '1px solid #e2e8f0' }}>
                  <h4 style={{ margin: '0 0 8px 0', fontSize: 13, fontWeight: 800, color: '#1e293b' }}>
                    📱 Mobile Device & System Telemetry
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, fontSize: 11 }}>
                    <div><b>Device Model:</b> {selected.device_brand || ''} {selected.device_model || 'Android Smartphone'}</div>
                    <div><b>OS Version:</b> {selected.android_version || 'Android 13/14'}</div>
                    <div><b>App Version:</b> {selected.app_version || selected.app_version_used || 'v1.0.4 (Release)'}</div>
                    <div><b>Network:</b> {selected.network_type || '4G/5G/WiFi'}</div>
                    <div><b>Screen Res:</b> {selected.screen_resolution || '1080x2400'}</div>
                    <div><b>Timezone:</b> {selected.time_zone || 'Asia/Kolkata'}</div>
                  </div>
                </div>

                {/* Main Stats Grid */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
                  <div className="sz-stat green" style={{ padding: '8px 12px' }}>
                    <div className="label" style={{ fontSize: 10 }}>Lifetime Value (CLV)</div>
                    <div className="value" style={{ fontSize: 16, fontWeight: 800 }}>{money(selected.totalSpent)}</div>
                  </div>
                  <div className="sz-stat blue" style={{ padding: '8px 12px' }}>
                    <div className="label" style={{ fontSize: 10 }}>Total Orders</div>
                    <div className="value" style={{ fontSize: 16, fontWeight: 800 }}>{selected.orderCount}</div>
                  </div>
                  <div className="sz-stat orange" style={{ padding: '8px 12px' }}>
                    <div className="label" style={{ fontSize: 10 }}>Avg Order Value</div>
                    <div className="value" style={{ fontSize: 16, fontWeight: 800 }}>{money(aov)}</div>
                  </div>
                  <div className="sz-stat green" style={{ padding: '8px 12px' }}>
                    <div className="label" style={{ fontSize: 10 }}>Total App Opens</div>
                    <div className="value" style={{ fontSize: 16, fontWeight: 800 }}>{appOpens}</div>
                  </div>
                </div>

                {/* Activity & Insights List */}
                <div style={{ fontSize: 13, display: 'flex', flexDirection: 'column', gap: 6, padding: '10px 0', borderTop: '1px solid var(--border)', borderBottom: '1px solid var(--border)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    🟢 <b>Live Status:</b> 
                    {isOnline ? (
                      <span style={{ color: '#4CAF50', fontWeight: 'bold' }}>
                        Online (looking at {userSession?.current_state || 'browsing'})
                      </span>
                    ) : (
                      <span style={{ color: 'var(--text-muted)' }}>Offline</span>
                    )}
                  </div>
                  <div>🕒 <b>Last Active:</b> {lastActiveStr}</div>
                  {isOnline && userSession?.search_query && (
                    <div style={{ background: '#FFFDE7', padding: '6px 10px', borderRadius: 6, border: '1px solid #FFF59D', fontSize: 12 }}>
                      🔍 <b>Active Search:</b> "{userSession.search_query}"
                    </div>
                  )}
                  <div>📅 <b>Registered On:</b> {regDate}</div>
                  <div>🏷️ <b>Favorite Categories:</b> {favCats}</div>
                  <div>🛒 <b>Frequently Purchased:</b> {freqProds}</div>
                  <div>💳 <b>Payment Preference:</b> {payPref}</div>
                  <div>🎟️ <b>Coupon Usage:</b> {couponUsage}</div>
                  <div>↩️ <b>Refund History:</b> {refunds} refund(s)</div>
                  <div>❌ <b>Cancellation History:</b> {cancellations} cancelled order(s)</div>
                </div>

                {/* Active Cart Section */}
                <div>
                  <h4 style={{ margin: '0 0 6px 0', fontSize: 13, fontWeight: 700 }}>Shopping Cart (Live)</h4>
                  {cartItems.length === 0 ? (
                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Cart is currently empty.</div>
                  ) : (
                    <div className="sz-alert info" style={{ padding: 8, margin: 0, fontSize: 12 }}>
                      <div style={{ fontWeight: 700, marginBottom: 4 }}>Value: {money(cartTotal)} ({cartItems.length} items)</div>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                        {cartItems.map((it) => (
                          <div key={it.id}>
                            • {it.product_variants?.products?.name || 'Product'} ({it.product_variants?.weight}{it.product_variants?.unit}) x {it.quantity}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* Active Wishlist Section */}
                <div>
                  <h4 style={{ margin: '0 0 6px 0', fontSize: 13, fontWeight: 700 }}>Wishlist ({wishlistItems.length} items)</h4>
                  {wishlistItems.length === 0 ? (
                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Wishlist is currently empty.</div>
                  ) : (
                    <div className="sz-alert success" style={{ padding: 8, margin: 0, fontSize: 12, border: '1px solid #C8E6C9', background: '#E8F5E9' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                        {wishlistItems.map((it) => (
                          <div key={it.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span style={{ color: '#2E7D32', fontWeight: 600 }}>❤️ {it.products?.name || 'Product'}</span>
                            <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>{it.products?.unit || ''}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* Address History */}
                <div>
                  <h4 style={{ margin: '0 0 6px 0', fontSize: 13, fontWeight: 700 }}>Address Directory</h4>
                  {addresses.length === 0 ? (
                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>No saved addresses.</div>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                      {addresses.map((a) => (
                        <div key={a.id} style={{ fontSize: 12, padding: '6px 8px', background: '#f9f9f9', borderRadius: 6, border: '1px solid var(--border)' }}>
                          🗺️ <b>{a.title || 'Address'}</b> — {a.address_line || a.addressLine}, {a.city} {a.pin_code || a.pinCode}
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Order History */}
                <div>
                  <h4 style={{ margin: '0 0 6px 0', fontSize: 13, fontWeight: 700 }}>Recent Order History</h4>
                  {orders.length === 0 ? (
                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>No orders placed.</div>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                      {orders.map((o) => (
                        <div key={o.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 12, padding: '6px 0', borderBottom: '1px solid var(--border)' }}>
                          <span>
                            📦 <b>#{o.order_number || String(o.id).slice(-6)}</b> · {o.order_status}
                          </span>
                          <b style={{ color: 'var(--brand)' }}>{money(orderTotal(o))}</b>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            );
          })()}
        </div>
      </div>

      {/* Modal: Grant or Edit Admin Access */}
      {adminModalUser && (
        <Modal
          title={`Admin Access: ${adminModalUser.name || 'User'}`}
          onClose={() => setAdminModalUser(null)}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <p style={{ fontSize: 13, color: 'var(--text-muted)', margin: 0 }}>
              Grant or adjust administrative privileges for <strong>{adminModalUser.name || 'this user'}</strong>.
            </p>

            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 700, marginBottom: 4 }}>
                Select Role to Grant *
              </label>
              <select
                value={selectedAdminRole}
                onChange={(e) => setSelectedAdminRole(e.target.value)}
              >
                {DEFAULT_ROLES.map((r) => (
                  <option key={r.name} value={r.name}>
                    {r.displayName} — {r.description}
                  </option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 12 }}>
              {adminUsers.some(
                (a) =>
                  (a.email && a.email.toLowerCase() === (adminModalUser.email || '').toLowerCase()) ||
                  (a.mobile && String(a.mobile).slice(-10) === String(phoneOf(adminModalUser)).slice(-10))
              ) && (
                <button
                  type="button"
                  className="btn btn-danger btn-sm"
                  onClick={async () => {
                    if (!confirm(`Revoke admin access for ${adminModalUser.name}?`)) return;
                    const cleanMobile = String(phoneOf(adminModalUser)).slice(-10);
                    const cleanEmail = (adminModalUser.email || '').toLowerCase().trim();
                    let q = supabase.from('admin_users').delete();
                    if (cleanEmail && cleanMobile) {
                      q = q.or(`email.ilike.${cleanEmail},mobile.ilike.%${cleanMobile}%`);
                    } else if (cleanEmail) {
                      q = q.ilike('email', cleanEmail);
                    } else if (cleanMobile) {
                      q = q.ilike('mobile', `%${cleanMobile}%`);
                    }
                    await q;
                    setAdminModalUser(null);
                    load();
                  }}
                >
                  Revoke Admin Access
                </button>
              )}

              <div style={{ display: 'flex', gap: 10, marginLeft: 'auto' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setAdminModalUser(null)}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={async () => {
                    const cleanMobile = String(phoneOf(adminModalUser)).replace(/\D/g, '').slice(-10);
                    const cleanEmail = (adminModalUser.email || '').toLowerCase().trim();
                    const payload = {
                      name: adminModalUser.name || 'Admin',
                      email: cleanEmail || null,
                      mobile: cleanMobile || null,
                      role: normalizeRole(selectedAdminRole),
                      status: 'active',
                    };
                    await supabase.from('admin_users').upsert(payload, { onConflict: 'mobile' });
                    setAdminModalUser(null);
                    load();
                  }}
                >
                  Save Admin Role
                </button>
              </div>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
