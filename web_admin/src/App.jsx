import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase, getOtpSession, clearOtpSession } from './supabase';
import AuthScreen from './components/AuthScreen';
import Dashboard from './pages/Dashboard';
import CategoriesPage from './pages/CategoriesPage';
import SubCategoriesPage from './pages/SubCategoriesPage';
import ProductsPage from './pages/ProductsPage';
import VariantsPage from './pages/VariantsPage';
import InventoryPage from './pages/InventoryPage';
import OrdersPage from './pages/OrdersPage';
import CustomersPage from './pages/CustomersPage';
import DeliveryPage from './pages/DeliveryPage';
import SettingsPage from './pages/SettingsPage';
import ProfilePage from './pages/ProfilePage';
import ReportsPage from './pages/ReportsPage';
import OutletsPage from './pages/OutletsPage';
import SuppliersPage from './pages/SuppliersPage';
import PurchaseOrdersPage from './pages/PurchaseOrdersPage';
import CouponsPage from './pages/CouponsPage';
import CustomerSupportPage from './pages/CustomerSupportPage';
import OptionalCrudPage from './pages/OptionalCrudPage';
import NotificationsPage from './pages/NotificationsPage';
import AdminAccessPage from './pages/AdminAccessPage';
import { hasPermission, getRoleBadge, normalizeRole } from './utils/rbac';

const NAV = [
  {
    label: 'Overview',
    items: [
      { id: 'dashboard', label: 'Dashboard', icon: '▣' },
      { id: 'orders', label: 'Orders', icon: '🛍️', badge: true },
      { id: 'notifications', label: 'Push Notifications', icon: '🔔' },
      { id: 'reports', label: 'Reports', icon: '📈' },
    ],
  },
  {
    label: 'Catalog',
    items: [
      { id: 'categories', label: 'Categories', icon: '🥬' },
      { id: 'subcategories', label: 'Sub Categories', icon: '📁' },
      { id: 'products', label: 'Products', icon: '🛒' },
      { id: 'variants', label: 'Variants', icon: '⚖️' },
      { id: 'inventory', label: 'Inventory', icon: '📦' },
    ],
  },
  {
    label: 'Supply',
    items: [
      { id: 'suppliers', label: 'Suppliers', icon: '🏭' },
      { id: 'purchase', label: 'Purchase Orders', icon: '🧾' },
      { id: 'outlets', label: 'Outlets', icon: '🏪' },
    ],
  },
  {
    label: 'People',
    items: [
      { id: 'customers', label: 'Customers', icon: '👥' },
      { id: 'delivery', label: 'Delivery Partners', icon: '🛵' },
      { id: 'roles', label: 'Admin Access & Roles', icon: '🔐' },
    ],
  },
  {
    label: 'Growth',
    items: [
      { id: 'coupons', label: 'Coupons', icon: '🏷️' },
      { id: 'notifications', label: 'Notifications', icon: '🔔' },
      { id: 'reviews', label: 'Reviews', icon: '⭐' },
      { id: 'support', label: 'Support', icon: '💬' },
      { id: 'refunds', label: 'Refunds', icon: '💸' },
      { id: 'returns', label: 'Returns', icon: '↩️' },
    ],
  },
  {
    label: 'System',
    items: [
      { id: 'settings', label: 'Settings', icon: '⚙️' },
      { id: 'profile', label: 'Profile', icon: '👤' },
    ],
  },
];

const TITLES = Object.fromEntries(NAV.flatMap((g) => g.items.map((i) => [i.id, i.label])));

export default function App() {
  const [session, setSession] = useState(null);
  const [adminProfile, setAdminProfile] = useState(null);
  const [accessError, setAccessError] = useState('');
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState('dashboard');
  const [pending, setPending] = useState(0);
  const [toast, setToast] = useState(null);
  const [mobileOpen, setMobileOpen] = useState(false);

  const refreshPending = useCallback(async () => {
    const { count } = await supabase
      .from('orders')
      .select('id', { count: 'exact', head: true })
      .eq('order_status', 'placed');
    setPending(count || 0);
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const otp = getOtpSession();
      if (otp?.user) {
        if (!cancelled) {
          setSession(otp);
          setLoading(false);
        }
        return;
      }
      const { data } = await supabase.auth.getSession();
      if (!cancelled) {
        setSession(data.session);
        setLoading(false);
      }
    })();
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => {
      if (getOtpSession()) return;
      setSession(s);
      setLoading(false);
    });
    return () => {
      cancelled = true;
      sub.subscription.unsubscribe();
    };
  }, []);

  // Fetch verified admin profile & permissions from admin_users & admin_roles
  useEffect(() => {
    if (!session) {
      setAdminProfile(null);
      return;
    }

    let active = true;
    (async () => {
      const email = (session.user?.email || '').toLowerCase().trim();
      const phone = String(session.user?.phone || session.user?.id || '').replace(/\D/g, '').slice(-10);

      const masterEmails = ['syedafsehehsani@gmail.com', 'saehsani.dev@gmail.com', 'sabzeewala@gmail.com'];
      const masterPhones = ['9718805484', '9876543210', '7050057572', '9599989241'];

      let adminRow = null;

      try {
        let q = supabase.from('admin_users').select('*');
        if (email && phone) {
          q = q.or(`email.ilike.${email},mobile.ilike.%${phone}%`);
        } else if (email) {
          q = q.ilike('email', email);
        } else if (phone) {
          q = q.ilike('mobile', `%${phone}%`);
        }
        const { data } = await q.limit(1);
        adminRow = data?.[0] || null;
      } catch (e) {
        console.warn('Error querying admin_users table:', e.message);
      }

      if (!adminRow && (masterEmails.includes(email) || masterPhones.includes(phone))) {
        adminRow = {
          name: session.user?.user_metadata?.name || 'Super Admin',
          email: email || null,
          mobile: phone || null,
          role: 'super_admin',
          status: 'active',
        };
      }

      if (!adminRow || (adminRow.status && adminRow.status !== 'active')) {
        if (active) {
          setAccessError('Access Denied: You do not have active administrative clearance for Sabzee Admin.');
          setTimeout(() => {
            clearOtpSession();
            supabase.auth.signOut().catch(() => {});
            setSession(null);
            setAccessError('');
          }, 3500);
        }
        return;
      }

      // Fetch granular role permissions
      const roleName = normalizeRole(adminRow.role);
      let permissions = '*';
      if (roleName !== 'super_admin' && roleName !== 'admin') {
        try {
          const { data: roleData } = await supabase
            .from('admin_roles')
            .select('permissions')
            .eq('name', roleName)
            .maybeSingle();
          permissions = roleData?.permissions || '';
        } catch {
          permissions = '';
        }
      }

      if (active) {
        setAdminProfile({
          ...adminRow,
          role: roleName,
          permissions,
        });
      }
    })();

    return () => {
      active = false;
    };
  }, [session]);

  useEffect(() => {
    if (!session) return;
    refreshPending();
    const ch = supabase
      .channel('shell-orders')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'orders' }, (payload) => {
        refreshPending();
        setToast({
          title: 'New order',
          body: `#${String(payload.new?.id || '').slice(-6)} · ₹${payload.new?.total ?? '—'}`,
        });
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'orders' }, () => refreshPending())
      .subscribe();
    return () => supabase.removeChannel(ch);
  }, [session, refreshPending]);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 4500);
    return () => clearTimeout(t);
  }, [toast]);

  const logout = async () => {
    clearOtpSession();
    await supabase.auth.signOut().catch(() => {});
    setSession(null);
    setAdminProfile(null);
  };

  // Filter navigation items by RBAC permissions
  const visibleNav = useMemo(() => {
    if (!adminProfile) return NAV;
    return NAV.map((group) => ({
      ...group,
      items: group.items.filter((item) => hasPermission(adminProfile, item.id)),
    })).filter((group) => group.items.length > 0);
  }, [adminProfile]);

  if (loading) {
    return (
      <div className="sz-loading" style={{ minHeight: '100vh' }}>
        <div className="sz-spinner" />
        Starting Sabzee Admin…
      </div>
    );
  }

  if (accessError) {
    return (
      <div className="sz-loading" style={{ minHeight: '100vh', background: '#fee2e2', color: '#991b1b' }}>
        <div style={{ fontSize: 42, marginBottom: 12 }}>🚫</div>
        <div style={{ fontWeight: 800, fontSize: 18 }}>{accessError}</div>
        <div style={{ fontSize: 13, marginTop: 8, color: '#b91c1c' }}>Signing out…</div>
      </div>
    );
  }

  if (!session) {
    return <AuthScreen onLoginSuccess={setSession} />;
  }

  const adminName =
    adminProfile?.name ||
    session.user?.user_metadata?.name ||
    session.user?.email ||
    session.user?.phone ||
    'Admin';

  const roleBadge = getRoleBadge(adminProfile?.role || 'admin');

  const go = (id) => {
    setPage(id);
    setMobileOpen(false);
  };

  const renderPage = () => {
    // Access control barrier
    if (adminProfile && !hasPermission(adminProfile, page)) {
      return (
        <div className="sz-card" style={{ padding: 40, textAlign: 'center', maxWidth: 640, margin: '60px auto' }}>
          <div style={{ fontSize: 54, marginBottom: 16 }}>🛡️</div>
          <h2 style={{ fontSize: 24, fontWeight: 900, color: 'var(--danger)' }}>Access Denied (403)</h2>
          <p style={{ color: 'var(--text-muted)', fontSize: 14, margin: '12px 0 24px', lineHeight: 1.6 }}>
            You do not have administrative permission to access the <strong>"{TITLES[page] || page}"</strong> module.<br />
            Your assigned role is <strong>{roleBadge.label}</strong>. Please contact a Super Admin if you need elevated clearance.
          </p>
          <button type="button" className="btn btn-primary" onClick={() => setPage('dashboard')}>
            Return to Dashboard
          </button>
        </div>
      );
    }

    switch (page) {
      case 'dashboard':
        return <Dashboard onNavigate={go} />;
      case 'categories':
        return <CategoriesPage />;
      case 'subcategories':
        return <SubCategoriesPage />;
      case 'products':
        return <ProductsPage />;
      case 'variants':
        return <VariantsPage />;
      case 'inventory':
        return <InventoryPage />;
      case 'orders':
        return <OrdersPage />;
      case 'customers':
        return <CustomersPage />;
      case 'delivery':
        return <DeliveryPage />;
      case 'outlets':
        return <OutletsPage />;
      case 'settings':
        return <SettingsPage />;
      case 'reports':
        return <ReportsPage />;
      case 'profile':
        return <ProfilePage session={session} onLogout={logout} />;
      case 'suppliers':
        return <SuppliersPage />;
      case 'purchase':
        return <PurchaseOrdersPage />;
      case 'coupons':
        return <CouponsPage />;
      case 'notifications':
        return <NotificationsPage />;
      case 'reviews':
        return (
          <OptionalCrudPage
            title="Reviews"
            subtitle="Approve / reject product ratings"
            table="reviews"
            fields={[
              { key: 'product_name', label: 'Product', required: true },
              { key: 'rating', label: 'Rating', type: 'number', required: true },
              { key: 'comment', label: 'Comment', type: 'textarea' },
              {
                key: 'status',
                label: 'Status',
                type: 'select',
                options: ['pending', 'approved', 'rejected'],
                defaultValue: 'pending',
              },
            ]}
            columns={[
              { key: 'product_name', label: 'Product' },
              { key: 'rating', label: 'Rating' },
              { key: 'status', label: 'Status' },
            ]}
          />
        );
      case 'support':
        return <CustomerSupportPage />;
      case 'refunds':
        return (
          <OptionalCrudPage
            title="Refunds"
            subtitle="Refund requests"
            table="refunds"
            fields={[
              { key: 'order_id', label: 'Order ID', required: true },
              { key: 'amount', label: 'Amount', type: 'number', required: true },
              {
                key: 'status',
                label: 'Status',
                type: 'select',
                options: ['requested', 'approved', 'rejected', 'processed'],
                defaultValue: 'requested',
              },
              { key: 'mode', label: 'Mode', type: 'select', options: ['gateway', 'manual'], defaultValue: 'manual' },
            ]}
            columns={[
              { key: 'order_id', label: 'Order' },
              { key: 'amount', label: 'Amount' },
              { key: 'status', label: 'Status' },
              { key: 'mode', label: 'Mode' },
            ]}
          />
        );
      case 'returns':
        return (
          <OptionalCrudPage
            title="Returns"
            subtitle="Return requests · restock"
            table="returns"
            fields={[
              { key: 'order_id', label: 'Order ID', required: true },
              { key: 'reason', label: 'Reason', type: 'textarea' },
              {
                key: 'status',
                label: 'Status',
                type: 'select',
                options: ['requested', 'approved', 'rejected', 'restocked'],
                defaultValue: 'requested',
              },
            ]}
            columns={[
              { key: 'order_id', label: 'Order' },
              { key: 'reason', label: 'Reason' },
              { key: 'status', label: 'Status' },
            ]}
          />
        );
      case 'roles':
        return <AdminAccessPage currentAdmin={adminProfile} />;
      default:
        return <Dashboard onNavigate={go} />;
    }
  };

  return (
    <div className="sz-shell">
      {mobileOpen && <div className="sz-overlay" onClick={() => setMobileOpen(false)} />}
      <aside className={`sz-sidebar ${mobileOpen ? 'open' : ''}`}>
        <div className="sz-brand">
          <div className="sz-brand-mark">S</div>
          <div>
            <h1>Sabzee Admin</h1>
            <span>10-min delivery app</span>
          </div>
        </div>
        <nav className="sz-nav">
          {visibleNav.map((group) => (
            <div key={group.label}>
              <div className="sz-nav-label">{group.label}</div>
              {group.items.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  className={`sz-nav-btn ${page === item.id ? 'active' : ''}`}
                  onClick={() => go(item.id)}
                >
                  <span>{item.icon}</span>
                  <span style={{ flex: 1 }}>{item.label}</span>
                  {item.badge && pending > 0 && <span className="badge">{pending}</span>}
                </button>
              ))}
            </div>
          ))}
        </nav>
        <div className="sz-sidebar-foot">
          <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginBottom: 10 }}>
            <div
              style={{
                width: 36,
                height: 36,
                borderRadius: 10,
                background: roleBadge.color,
                color: '#fff',
                display: 'grid',
                placeItems: 'center',
                fontWeight: 800,
                fontSize: 16,
              }}
            >
              {roleBadge.icon}
            </div>
            <div style={{ overflow: 'hidden' }}>
              <div style={{ fontSize: 13, fontWeight: 700, whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }}>
                {adminName}
              </div>
              <div
                style={{
                  fontSize: 11,
                  color: '#a7f3d0',
                  fontWeight: 600,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 4,
                }}
              >
                <span>{roleBadge.label}</span>
              </div>
            </div>
          </div>
          <button type="button" className="btn btn-danger" style={{ width: '100%' }} onClick={logout}>
            Logout
          </button>
        </div>
      </aside>

      <div className="sz-main">
        <header className="sz-topbar">
          <button type="button" className="btn btn-ghost mobile-menu-btn" onClick={() => setMobileOpen((v) => !v)}>
            ☰
          </button>
          <div style={{ flex: 1 }}>
            <h2>{TITLES[page] || 'Dashboard'}</h2>
            <p>Live</p>
          </div>
          {pending > 0 && (
            <button type="button" className="btn btn-warn btn-sm" onClick={() => go('orders')}>
              {pending} pending orders
            </button>
          )}
        </header>
        <div className="sz-content">{renderPage()}</div>
      </div>

      {toast && (
        <div
          className="sz-toast"
          onClick={() => {
            go('orders');
            setToast(null);
          }}
        >
          <strong>{toast.title}</strong>
          <span>{toast.body}</span>
        </div>
      )}
    </div>
  );
}
