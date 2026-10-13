/**
 * Role-Based Access Control (RBAC) System for Sabzee Admin
 */

export const MODULES = [
  { id: 'dashboard', label: 'Dashboard', group: 'Overview', icon: '▣' },
  { id: 'orders', label: 'Orders', group: 'Overview', icon: '🛍️' },
  { id: 'notifications', label: 'Push Notifications', group: 'Overview', icon: '🔔' },
  { id: 'reports', label: 'Reports & Analytics', group: 'Overview', icon: '📈' },

  { id: 'categories', label: 'Categories', group: 'Catalog', icon: '🥬' },
  { id: 'subcategories', label: 'Sub Categories', group: 'Catalog', icon: '📁' },
  { id: 'products', label: 'Products', group: 'Catalog', icon: '🛒' },
  { id: 'variants', label: 'Variants', group: 'Catalog', icon: '⚖️' },
  { id: 'inventory', label: 'Inventory', group: 'Catalog', icon: '📦' },

  { id: 'suppliers', label: 'Suppliers', group: 'Supply', icon: '🏭' },
  { id: 'purchase', label: 'Purchase Orders', group: 'Supply', icon: '🧾' },
  { id: 'outlets', label: 'Outlets', group: 'Supply', icon: '🏪' },

  { id: 'customers', label: 'Customers', group: 'People', icon: '👥' },
  { id: 'delivery', label: 'Delivery Partners', group: 'People', icon: '🛵' },
  { id: 'roles', label: 'Admin Access & Roles', group: 'People', icon: '🔐', sensitive: true },

  { id: 'coupons', label: 'Coupons', group: 'Growth', icon: '🏷️' },
  { id: 'reviews', label: 'Reviews', group: 'Growth', icon: '⭐' },
  { id: 'support', label: 'Customer Support', group: 'Growth', icon: '💬' },
  { id: 'refunds', label: 'Refunds', group: 'Growth', icon: '💸' },
  { id: 'returns', label: 'Returns', group: 'Growth', icon: '↩️' },

  { id: 'settings', label: 'Store Settings', group: 'System', icon: '⚙️', sensitive: true },
  { id: 'profile', label: 'My Profile', group: 'System', icon: '👤' },
];

export const DEFAULT_ROLES = [
  {
    name: 'super_admin',
    displayName: 'Super Admin',
    description: 'Full unrestricted system access, user management, and sensitive settings.',
    permissions: '*',
    badgeColor: '#dc2626',
    icon: '👑',
  },
  {
    name: 'admin',
    displayName: 'Administrator',
    description: 'Full operational access with admin management permissions.',
    permissions: '*',
    badgeColor: '#7c3aed',
    icon: '🛡️',
  },
  {
    name: 'operations_manager',
    displayName: 'Operations Manager',
    description: 'Manages orders, inventory, catalog, outlets, delivery, and customer service.',
    permissions: 'dashboard,orders,reports,categories,subcategories,products,variants,inventory,suppliers,purchase,outlets,customers,delivery,coupons,reviews,support,refunds,returns,profile',
    badgeColor: '#2563eb',
    icon: '🛠️',
  },
  {
    name: 'catalog_inventory_manager',
    displayName: 'Catalog & Inventory Lead',
    description: 'Manages products, categories, variants, inventory, and supplier orders.',
    permissions: 'dashboard,categories,subcategories,products,variants,inventory,suppliers,purchase,outlets,profile',
    badgeColor: '#059669',
    icon: '📦',
  },
  {
    name: 'order_delivery_manager',
    displayName: 'Order & Dispatch Lead',
    description: 'Tracks live orders, handles delivery partners, outlets, and dispatch.',
    permissions: 'dashboard,orders,delivery,outlets,customers,support,refunds,returns,profile',
    badgeColor: '#d97706',
    icon: '🛵',
  },
  {
    name: 'marketing_manager',
    displayName: 'Marketing & Growth',
    description: 'Manages coupon campaigns, push notifications, reviews, and customer insights.',
    permissions: 'dashboard,coupons,notifications,reviews,reports,support,profile',
    badgeColor: '#db2777',
    icon: '🚀',
  },
  {
    name: 'support_agent',
    displayName: 'Customer Support',
    description: 'Reviews orders, answers support tickets, processes refunds, and customer inquiries.',
    permissions: 'dashboard,orders,customers,reviews,support,refunds,returns,profile',
    badgeColor: '#475569',
    icon: '💬',
  },
];

/**
 * Normalizes role name for comparison
 */
export function normalizeRole(role) {
  return String(role || '').toLowerCase().trim().replace(/[\s-]+/g, '_');
}

/**
 * Checks if a given role is a Super Admin
 */
export function isSuperAdmin(role) {
  const r = normalizeRole(role);
  return r === 'super_admin' || r === 'superadmin' || r === 'owner';
}

/**
 * Checks if a given role has Admin privileges (can manage access/users)
 */
export function isAdminOrHigher(role) {
  const r = normalizeRole(role);
  return isSuperAdmin(r) || r === 'admin';
}

/**
 * Returns a human-friendly role name
 */
export function getRoleDisplayName(role) {
  const found = DEFAULT_ROLES.find((d) => d.name === normalizeRole(role));
  if (found) return found.displayName;
  // Format slug e.g. "custom_role" -> "Custom Role"
  return String(role || 'Admin')
    .replace(/[_-]/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Returns role badge config
 */
export function getRoleBadge(role) {
  const found = DEFAULT_ROLES.find((d) => d.name === normalizeRole(role));
  if (found) return { label: found.displayName, color: found.badgeColor, icon: found.icon };
  return { label: getRoleDisplayName(role), color: '#4b5563', icon: '👤' };
}

/**
 * Evaluates whether an admin has permission to access a specific module/page
 * @param {Object} adminUser - { role, permissions, status }
 * @param {string} pageId - e.g. 'orders', 'roles', 'settings'
 * @returns {boolean}
 */
export function hasPermission(adminUser, pageId) {
  if (!adminUser) return false;
  if (adminUser.status && adminUser.status !== 'active') return false;

  const role = normalizeRole(adminUser.role);

  // Super admins have unrestricted access to all modules
  if (isSuperAdmin(role) || role === 'admin') return true;

  // Profile is always accessible by any active user
  if (pageId === 'profile') return true;

  // Sensitive security pages require admin or explicit 'roles' permission
  if (pageId === 'roles') {
    return isAdminOrHigher(role) || (adminUser.permissions || '').includes('roles');
  }

  // Check explicit permissions string or list
  const perms = adminUser.permissions;
  if (perms === '*' || perms?.includes?.('*')) return true;

  if (typeof perms === 'string') {
    const list = perms.split(',').map((p) => p.trim());
    return list.includes(pageId);
  }

  if (Array.isArray(perms)) {
    return perms.includes(pageId);
  }

  // Fallback to default role permissions
  const defaultRole = DEFAULT_ROLES.find((d) => d.name === role);
  if (defaultRole) {
    if (defaultRole.permissions === '*') return true;
    const defaultList = defaultRole.permissions.split(',').map((p) => p.trim());
    return defaultList.includes(pageId);
  }

  return false;
}
