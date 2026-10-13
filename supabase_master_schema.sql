-- ============================================================================
-- SABZEEWALA MASTER PRODUCTION DATABASE REPLICATION SCHEMA (ALL 29 TABLES)
-- ============================================================================
-- 💡 DIRECT SUPABASE PROJECT CONFIGURATION:
-- Project URL: https://mhqyaqvnlurqamojelae.supabase.co
-- Storage Bucket: SabzeeWala (Categories, Sub Categories, Products)
-- ============================================================================

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- ============================================================================
-- 1. STORE OPERATIONS & SYSTEM SETTINGS
-- ============================================================================

-- 1. Store Settings (Master App Control & Delivery Fees)
create table if not exists store_settings (
  id text primary key default 'main_store',
  store_name text default 'Sabzee Quick Mart',
  is_open boolean default true,
  is_store_open boolean default true,
  opening_time text default '06:00 AM',
  closing_time text default '11:00 PM',
  delivery_fee numeric default 25,
  base_delivery_fee numeric default 25,
  free_delivery_threshold numeric default 199,
  service_charge numeric default 5,
  packaging_fee numeric default 10,
  product_handling_fee numeric default 2,
  min_order_amount numeric default 99,
  delivery_radius_km numeric default 10,
  contact_phone text default '+91 9876543210',
  support_email text default 'support@sabzeewala.com',
  referral_reward_amount numeric default 100,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

-- 2. Key-Value Settings (Out-of-stock sync, app toggles)
create table if not exists settings (
  key text primary key,
  value text,
  updated_at timestamptz default now()
);

-- ============================================================================
-- 2. PRODUCT CATALOG & INVENTORY
-- ============================================================================

-- 3. Categories
create table if not exists categories (
  id text primary key,
  name text not null,
  image_url text,
  icon text,
  display_order integer default 0,
  status text default 'active',
  created_at timestamptz default now()
);

-- 4. Sub Categories
create table if not exists sub_categories (
  id text primary key,
  category_id text references categories(id) on delete cascade,
  name text not null,
  image_url text,
  status text default 'active',
  created_at timestamptz default now()
);

-- 5. Products Catalog
create table if not exists products (
  id text primary key,
  category_id text references categories(id) on delete set null,
  sub_category_id text references sub_categories(id) on delete set null,
  name text not null,
  description text,
  image_url text,
  is_organic boolean default false,
  is_new_launch boolean default false,
  status text default 'active',
  created_at timestamptz default now()
);

-- 6. Product Variants (Units, MRP, Selling Price, Cost, Stock)
create table if not exists product_variants (
  id text primary key,
  product_id text references products(id) on delete cascade,
  weight numeric default 1,
  unit text default 'kg',
  mrp numeric not null,
  selling_price numeric not null,
  purchase_price numeric default 0,
  sku text,
  barcode text,
  stock_total integer default 100,
  created_at timestamptz default now()
);

-- 7. Organic Products Tagging
create table if not exists organic_products (
  id text primary key,
  product_id text references products(id) on delete cascade,
  created_at timestamptz default now()
);

-- 8. Inventory Status
create table if not exists inventory (
  variant_id text primary key references product_variants(id) on delete cascade,
  in_stock boolean not null default true,
  updated_at timestamptz default now()
);

-- 9. Inventory Spoilage / Wastage Log
create table if not exists inventory_wastage (
  id uuid primary key default gen_random_uuid(),
  variant_id text references product_variants(id) on delete cascade,
  product_name text not null,
  quantity numeric not null,
  reason text not null,
  cost_loss numeric default 0,
  logged_by text default 'Admin',
  created_at timestamptz default now()
);

-- ============================================================================
-- 3. SUPPLY CHAIN & FLEET OPERATIONS
-- ============================================================================

-- 10. Suppliers Directory
create table if not exists suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_person text,
  phone text not null,
  email text,
  gst text,
  address text,
  payment_terms text default 'Net 15',
  status text default 'active',
  created_at timestamptz default now()
);

-- 11. Purchase Orders
create table if not exists purchase_orders (
  id text primary key,
  supplier_id uuid references suppliers(id) on delete set null,
  supplier_name text not null,
  total_amount numeric default 0,
  status text default 'pending',
  items jsonb default '[]'::jsonb,
  expected_delivery_date date,
  received_at timestamptz,
  notes text,
  created_at timestamptz default now()
);

-- 12. Delivery Partners (Riders Fleet)
create table if not exists delivery_partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  vehicle_type text default 'Bike',
  vehicle_number text,
  driving_license text,
  status text default 'available',
  active_orders_count integer default 0,
  total_deliveries integer default 0,
  payout_per_order numeric default 35,
  created_at timestamptz default now()
);

-- 13. Outlets / Warehouses
create table if not exists outlets (
  id text primary key,
  name text not null,
  address text,
  latitude numeric,
  longitude numeric,
  phone text,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- ============================================================================
-- 4. USERS, PROFILES & ADDRESSES
-- ============================================================================

-- 14. Users & Customer Profiles (Device Telemetry, Push Tokens, Wallet)
create table if not exists users (
  id text primary key,
  full_name text,
  mobile text,
  email text,
  fcm_token text,
  role text default 'customer',
  status text default 'active',
  wallet_balance numeric default 0,
  profile_completion_status text default 'incomplete',
  registration_date timestamptz default now(),
  last_login_date timestamptz default now(),
  first_login_date timestamptz default now(),
  login_count integer default 1,
  last_active_time timestamptz default now(),
  app_version_used text,
  device_brand text,
  device_model text,
  android_version text,
  app_version text,
  device_identifier text,
  screen_resolution text,
  language text,
  time_zone text,
  country text,
  network_type text,
  device_change_history jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 15. Legacy/Alternative Profiles
create table if not exists profiles (
  id text primary key,
  full_name text,
  phone text,
  email text,
  status text default 'active',
  role text default 'customer',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 16. Delivery Addresses (Supports Flutter Mobile App & Web Admin Schemas)
create table if not exists addresses (
  id text primary key default gen_random_uuid()::text,
  user_id text not null,
  title text default 'Home',
  full_name text,
  name text,
  mobile text,
  phone text,
  address_line text,
  house_no text,
  area text,
  landmark text,
  city text,
  pin_code text,
  pincode text,
  type text default 'home',
  latitude numeric,
  longitude numeric,
  is_selected boolean default false,
  is_default boolean default false,
  created_at timestamptz default now()
);

-- ============================================================================
-- 5. ORDERS & COMMERCE TRANSACTIONS
-- ============================================================================

-- 17. Orders
create table if not exists orders (
  id text primary key,
  order_number text,
  user_id text not null,
  address_id text,
  customer_name text,
  customer_phone text,
  total numeric not null,
  delivery_fee numeric default 0,
  status text default 'placed',
  order_status text default 'placed',
  payment_method text default 'COD',
  payment_status text default 'pending',
  delivery_address text,
  rider_id uuid references delivery_partners(id) on delete set null,
  rider_name text,
  rider_phone text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 18. Order Items
create table if not exists order_items (
  id text primary key default gen_random_uuid()::text,
  order_id text references orders(id) on delete cascade,
  product_id text,
  variant_id text,
  product_name text,
  weight text,
  unit text,
  price numeric not null,
  quantity integer not null,
  created_at timestamptz default now()
);

-- 19. Cart & Wishlist
create table if not exists cart (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  product_id text,
  variant_id text not null,
  quantity integer default 1,
  image_url text,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

create table if not exists wishlists (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  product_id text not null,
  created_at timestamptz default now(),
  unique (user_id, product_id)
);

-- 20. Wallet Transactions
create table if not exists wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  amount numeric not null,
  type text not null,
  description text,
  status text default 'completed',
  order_id text,
  created_at timestamptz default now()
);

-- 21. Coupons & Promotions
create table if not exists coupons (
  id text primary key,
  code text unique not null,
  discount_type text default 'flat',
  discount_value numeric not null,
  min_order_value numeric default 0,
  max_discount numeric,
  status text default 'active',
  created_at timestamptz default now()
);

-- ============================================================================
-- 6. ADMINISTRATION, HR & B2B
-- ============================================================================

-- 22. Admin Users
create table if not exists admin_users (
  id text primary key,
  mobile text not null,
  name text,
  role text default 'admin',
  status text default 'active',
  created_at timestamptz default now()
);

-- 23. Admin Roles & Permissions
create table if not exists admin_roles (
  id text primary key,
  name text not null,
  permissions jsonb default '[]'::jsonb,
  created_at timestamptz default now()
);

-- 24. Employees Directory
create table if not exists employees (
  id text primary key,
  name text not null,
  role text,
  phone text,
  status text default 'active',
  created_at timestamptz default now()
);

-- 25. Companies (B2B Accounts)
create table if not exists companies (
  id text primary key,
  name text not null,
  contact_person text,
  phone text,
  email text,
  gstin text,
  address text,
  status text default 'active',
  created_at timestamptz default now()
);

-- ============================================================================
-- 7. ANALYTICS, LIVE TRAFFIC & CUSTOMER SUPPORT
-- ============================================================================

-- 26. User Sessions & Live Traffic Telemetry
create table if not exists user_sessions (
  user_id text primary key,
  login_time timestamptz default now(),
  last_active_at timestamptz default now(),
  app_opens integer default 1,
  current_state text default 'browsing',
  search_query text,
  session_duration integer default 0,
  device_info text,
  created_at timestamptz default now()
);

-- 27. Push Notifications Audit & Campaigns
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  type text default 'broadcast',
  user_id text,
  status text default 'sent',
  recipients_count integer default 0,
  created_at timestamptz default now()
);

-- 28. Customer Support Tickets
create table if not exists support_tickets (
  id text primary key,
  user_id text not null,
  customer_name text,
  customer_phone text,
  order_id text,
  category text default 'General',
  subject text not null,
  message text not null,
  status text default 'open',
  resolution_notes text,
  refund_amount numeric default 0,
  created_at timestamptz default now(),
  resolved_at timestamptz
);

-- ============================================================================
-- 8. INDEXES FOR PERFORMANCE
-- ============================================================================

create index if not exists idx_sessions_last_active on user_sessions(last_active_at);
create index if not exists idx_orders_user_id on orders(user_id);
create index if not exists idx_orders_created_at on orders(created_at desc);
create index if not exists idx_order_items_order_id on order_items(order_id);
create index if not exists idx_addresses_user_id on addresses(user_id);
create index if not exists idx_cart_user_id on cart(user_id);
create index if not exists idx_wishlists_user_id on wishlists(user_id);
create index if not exists idx_wallet_tx_user_id on wallet_transactions(user_id);
create index if not exists idx_products_category on products(category_id);
create index if not exists idx_variants_product on product_variants(product_id);

-- ============================================================================
-- 9. SUPABASE REALTIME REPLICATION
-- ============================================================================

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE 
      orders, 
      order_items, 
      inventory, 
      wishlists, 
      user_sessions, 
      store_settings, 
      settings, 
      product_variants, 
      cart;
  EXCEPTION 
    WHEN duplicate_object THEN NULL;
    WHEN OTHERS THEN NULL;
  END;
END $$;

-- ============================================================================
-- 10. STORAGE BUCKET CONFIGURATION (SABZEEWALA PUBLIC ASSETS)
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('SabzeeWala', 'SabzeeWala', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('Sabzee', 'Sabzee', true)
on conflict (id) do update set public = true;

DO $$
BEGIN
  -- Storage bucket policies for public read and anonymous/app uploads
  DROP POLICY IF EXISTS "Public Access to SabzeeWala bucket" ON storage.objects;
  CREATE POLICY "Public Access to SabzeeWala bucket"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id in ('SabzeeWala', 'Sabzee'));

  DROP POLICY IF EXISTS "Anon Upload to SabzeeWala bucket" ON storage.objects;
  CREATE POLICY "Anon Upload to SabzeeWala bucket"
    ON storage.objects FOR INSERT TO public
    WITH CHECK (bucket_id in ('SabzeeWala', 'Sabzee'));

  DROP POLICY IF EXISTS "Anon Update on SabzeeWala bucket" ON storage.objects;
  CREATE POLICY "Anon Update on SabzeeWala bucket"
    ON storage.objects FOR UPDATE TO public
    USING (bucket_id in ('SabzeeWala', 'Sabzee'));

  DROP POLICY IF EXISTS "Anon Delete on SabzeeWala bucket" ON storage.objects;
  CREATE POLICY "Anon Delete on SabzeeWala bucket"
    ON storage.objects FOR DELETE TO public
    USING (bucket_id in ('SabzeeWala', 'Sabzee'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ============================================================================
-- 11. ROW LEVEL SECURITY (RLS) & PERMISSIONS
-- ============================================================================
-- Enables full access for 'anon' and 'authenticated' roles so mobile app & web admin connect smoothly

DO $$
DECLARE
  t text;
  tbls text[] := ARRAY[
    'store_settings', 'settings', 'categories', 'sub_categories', 'products',
    'product_variants', 'organic_products', 'inventory', 'inventory_wastage', 'suppliers',
    'purchase_orders', 'delivery_partners', 'users', 'profiles', 'addresses',
    'orders', 'order_items', 'cart', 'wishlists', 'wallet_transactions',
    'coupons', 'admin_users', 'admin_roles', 'user_sessions', 'notifications',
    'support_tickets', 'employees', 'companies', 'outlets'
  ];
BEGIN
  FOREACH t IN ARRAY tbls LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'allow_anon_all_' || t, t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO anon USING (true) WITH CHECK (true)', 'allow_anon_all_' || t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'allow_auth_all_' || t, t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (true) WITH CHECK (true)', 'allow_auth_all_' || t, t);
  END LOOP;
END $$;

-- ============================================================================
-- 12. SEED DATA INSERTION (CATEGORIES, SUBCATEGORIES, PRODUCTS & VARIANTS)
-- ============================================================================

DO $$
DECLARE
  base_url text := 'https://mhqyaqvnlurqamojelae.supabase.co';
BEGIN
  -- Insert Store Settings default
  insert into store_settings (
    id, store_name, is_open, is_store_open, delivery_fee, base_delivery_fee, 
    free_delivery_threshold, service_charge, packaging_fee, product_handling_fee, min_order_amount
  )
  values ('main_store', 'Sabzee Quick Mart', true, true, 25, 25, 199, 5, 10, 2, 99)
  on conflict (id) do update set store_name = excluded.store_name;

  -- Insert Out of Stock sync default in settings
  insert into settings (key, value)
  values ('out_of_stock_ids', '')
  on conflict (key) do nothing;

  -- Insert Admin Roles default
  insert into admin_roles (id, name, permissions)
  values ('super_admin', 'Super Administrator', '["*"]'::jsonb)
  on conflict (id) do nothing;

  -- Insert Admin User default
  insert into admin_users (id, mobile, name, role, status)
  values ('admin_master', '9599989241', 'Super Admin', 'admin', 'active')
  on conflict (id) do nothing;

  -- Insert Welcome Coupon
  insert into coupons (id, code, discount_type, discount_value, min_order_value, max_discount, status)
  values ('coup_welcome', 'WELCOME50', 'flat', 50, 199, 50, 'active')
  on conflict (id) do nothing;

  -- Insert Main Outlet
  insert into outlets (id, name, address, latitude, longitude, phone, is_active)
  values ('outlet_main', 'Sabzee Central Hub', 'Main Market, City Center', 28.6139, 77.2090, '9599989241', true)
  on conflict (id) do nothing;

  -- Insert Categories (.webp image format pointing to SabzeeWala bucket)
  insert into categories (id, name, image_url, status, display_order) values
    ('vegetables', 'Vegetables', base_url || '/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp', 'active', 1),
    ('fruits', 'Fruits', base_url || '/storage/v1/object/public/SabzeeWala/Categories/Fruits.webp', 'active', 2),
    ('dairy', 'Dairy', base_url || '/storage/v1/object/public/SabzeeWala/Categories/Diary.webp', 'active', 3),
    ('bakery', 'Bakery', base_url || '/storage/v1/object/public/SabzeeWala/Categories/Bakery.webp', 'active', 4),
    ('snacks', 'Snacks', base_url || '/storage/v1/object/public/SabzeeWala/Categories/Snacks.webp', 'active', 5),
    ('beverages', 'Beverages', base_url || '/storage/v1/object/public/SabzeeWala/Categories/Beverages.webp', 'active', 6)
  on conflict (id) do update set image_url = excluded.image_url;

  -- Insert Sub-Categories (.webp image format pointing to SabzeeWala bucket)
  insert into sub_categories (id, category_id, name, image_url, status) values
    ('leafy_vegetables', 'vegetables', 'Leafy Vegetables', base_url || '/storage/v1/object/public/SabzeeWala/Sub%20Categories/Leafy%20Veggies.webp', 'active'),
    ('root_vegetables', 'vegetables', 'Root Vegetables', base_url || '/storage/v1/object/public/SabzeeWala/Sub%20Categories/Root%20Vegies.webp', 'active'),
    ('organic_vegetables', 'vegetables', 'Organic Vegetables', base_url || '/storage/v1/object/public/SabzeeWala/Categories/Veggies.webp', 'active'),
    ('fresh_fruits', 'fruits', 'Fresh Fruits', base_url || '/storage/v1/object/public/SabzeeWala/Sub%20Categories/Fresh%20Fruits.webp', 'active'),
    ('fresh_milk', 'dairy', 'Fresh Milk', base_url || '/storage/v1/object/public/SabzeeWala/Sub%20Categories/Fresh%20Dairy.webp', 'active'),
    ('cakes', 'bakery', 'Cakes', base_url || '/storage/v1/object/public/SabzeeWala/Sub%20Categories/Cakes.webp', 'active')
  on conflict (id) do update set image_url = excluded.image_url;

  -- Product: Bhindi
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_bhindi', 'vegetables', 'organic_vegetables', 'Bhindi', 'Fresh, tender green ladyfinger rich in fiber, perfect for everyday cooking.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Bhindi.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_veg_bhindi', 'veg_bhindi') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_bhindi', 'veg_bhindi', 250, 'kg', 22, 19, 'SKU_VEG_BHINDI', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_bhindi', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_bhindi_var_2', 'veg_bhindi', 500, 'kg', 45, 39, 'SKU_VEG_BHINDI_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_bhindi_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_bhindi_var_3', 'veg_bhindi', 1, 'kg', 85, 75, 'SKU_VEG_BHINDI_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_bhindi_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Cabbage
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_cabbage', 'vegetables', 'organic_vegetables', 'Cabbage', 'Farm-fresh green cabbage with crisp leaves, ideal for salads and curries.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Cabbage.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_veg_cabbage', 'veg_cabbage') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cabbage', 'veg_cabbage', 1, 'pcs', 45, 39, 'SKU_VEG_CABBAGE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cabbage', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cabbage_var_2', 'veg_cabbage', 1, 'pcs', 45, 39, 'SKU_VEG_CABBAGE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cabbage_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cabbage_var_3', 'veg_cabbage', 1, 'pcs', 45, 39, 'SKU_VEG_CABBAGE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cabbage_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Capsicum
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_capsicum', 'vegetables', 'organic_vegetables', 'Capsicum', 'Fresh green capsicum with a crunchy texture, suitable for Chinese and Indian dishes.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Capsicum.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_veg_capsicum', 'veg_capsicum') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_capsicum', 'veg_capsicum', 250, 'kg', 38, 32, 'SKU_VEG_CAPSICUM', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_capsicum', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_capsicum_var_2', 'veg_capsicum', 500, 'kg', 70, 59, 'SKU_VEG_CAPSICUM_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_capsicum_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_capsicum_var_3', 'veg_capsicum', 1, 'kg', 130, 110, 'SKU_VEG_CAPSICUM_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_capsicum_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Carrot
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_carrot', 'vegetables', 'root_vegetables', 'Carrot', 'Fresh organic carrots, sweet and crisp, perfect for salads and juice.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Carrot.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_carrot', 'veg_carrot', 250, 'kg', 25, 20, 'SKU_VEG_CARROT', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_carrot', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_carrot_var_2', 'veg_carrot', 500, 'kg', 45, 39, 'SKU_VEG_CARROT_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_carrot_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_carrot_var_3', 'veg_carrot', 1, 'kg', 85, 75, 'SKU_VEG_CARROT_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_carrot_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Cauliflower
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_cauliflower', 'vegetables', 'organic_vegetables', 'Cauliflower', 'Fresh white cauliflower with tightly packed florets, perfect for curries and snacks.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Cauliflower.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_veg_cauliflower', 'veg_cauliflower') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cauliflower', 'veg_cauliflower', 1, 'pcs', 65, 55, 'SKU_VEG_CAULIFLOWER', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cauliflower', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cauliflower_var_2', 'veg_cauliflower', 1, 'pcs', 65, 55, 'SKU_VEG_CAULIFLOWER_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cauliflower_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cauliflower_var_3', 'veg_cauliflower', 1, 'pcs', 65, 55, 'SKU_VEG_CAULIFLOWER_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cauliflower_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Chili
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_chili', 'vegetables', null, 'Chili', 'Fresh green chilies with natural spicy flavor for enhancing every meal.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Chili.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_chili', 'veg_chili', 100, 'kg', 20, 15, 'SKU_VEG_CHILI', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_chili', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_chili_var_2', 'veg_chili', 250, 'kg', 40, 32, 'SKU_VEG_CHILI_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_chili_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_chili_var_3', 'veg_chili', 500, 'kg', 70, 59, 'SKU_VEG_CHILI_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_chili_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Cucumber
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_cucumber', 'vegetables', 'organic_vegetables', 'Cucumber', 'Fresh, juicy cucumber rich in water content, great for salads and healthy diets.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Cucumber.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_veg_cucumber', 'veg_cucumber') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cucumber', 'veg_cucumber', 250, 'kg', 18, 15, 'SKU_VEG_CUCUMBER', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cucumber', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cucumber_var_2', 'veg_cucumber', 500, 'kg', 35, 29, 'SKU_VEG_CUCUMBER_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cucumber_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_cucumber_var_3', 'veg_cucumber', 1, 'kg', 65, 55, 'SKU_VEG_CUCUMBER_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_cucumber_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Mutter (Green Peas)
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_mutter', 'vegetables', null, 'Mutter (Green Peas)', 'Fresh green peas packed with protein and natural sweetness.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Mutter.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_mutter', 'veg_mutter', 250, 'kg', 50, 42, 'SKU_VEG_MUTTER', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_mutter', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_mutter_var_2', 'veg_mutter', 500, 'kg', 90, 79, 'SKU_VEG_MUTTER_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_mutter_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_mutter_var_3', 'veg_mutter', 1, 'kg', 170, 149, 'SKU_VEG_MUTTER_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_mutter_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Onion
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_onion', 'vegetables', 'root_vegetables', 'Onion', 'Premium quality red onions with a strong natural flavor for daily cooking.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Onion.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_onion', 'veg_onion', 1, 'kg', 45, 39, 'SKU_VEG_ONION', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_onion', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_onion_var_2', 'veg_onion', 2, 'kg', 85, 75, 'SKU_VEG_ONION_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_onion_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_onion_var_3', 'veg_onion', 5, 'kg', 200, 179, 'SKU_VEG_ONION_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_onion_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Potato
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_potato', 'vegetables', 'organic_vegetables', 'Potato', 'Fresh farm potatoes suitable for fries, curries, and everyday meals.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Potato.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_veg_potato', 'veg_potato') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_potato', 'veg_potato', 1, 'kg', 40, 35, 'SKU_VEG_POTATO', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_potato', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_potato_var_2', 'veg_potato', 2, 'kg', 75, 65, 'SKU_VEG_POTATO_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_potato_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_potato_var_3', 'veg_potato', 5, 'kg', 180, 155, 'SKU_VEG_POTATO_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_potato_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Radish
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_radish', 'vegetables', null, 'Radish', 'Fresh white radish with a crunchy texture, perfect for salads and parathas.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Radish.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_radish', 'veg_radish', 250, 'kg', 20, 15, 'SKU_VEG_RADISH', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_radish', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_radish_var_2', 'veg_radish', 500, 'kg', 35, 29, 'SKU_VEG_RADISH_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_radish_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_radish_var_3', 'veg_radish', 1, 'kg', 65, 55, 'SKU_VEG_RADISH_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_radish_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Saag (Mustard Greens)
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_saag', 'vegetables', 'leafy_vegetables', 'Saag (Mustard Greens)', 'Fresh mustard greens rich in iron and vitamins, ideal for traditional dishes.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Saag.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_saag', 'veg_saag', 250, 'kg', 22, 18, 'SKU_VEG_SAAG', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_saag', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_saag_var_2', 'veg_saag', 500, 'kg', 40, 35, 'SKU_VEG_SAAG_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_saag_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_saag_var_3', 'veg_saag', 1, 'kg', 75, 65, 'SKU_VEG_SAAG_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_saag_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Sem (French Beans)
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_sem', 'vegetables', null, 'Sem (French Beans)', 'Fresh green beans with a tender texture, perfect for stir-fries and curries.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Beans.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_sem', 'veg_sem', 250, 'kg', 38, 32, 'SKU_VEG_SEM', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_sem', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_sem_var_2', 'veg_sem', 500, 'kg', 70, 59, 'SKU_VEG_SEM_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_sem_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_sem_var_3', 'veg_sem', 1, 'kg', 130, 110, 'SKU_VEG_SEM_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_sem_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Spinach
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_spinach', 'vegetables', 'organic_vegetables', 'Spinach', 'Fresh spinach leaves rich in iron and nutrients, ideal for healthy recipes.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Spinach.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_veg_spinach', 'veg_spinach') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_spinach', 'veg_spinach', 250, 'kg', 22, 18, 'SKU_VEG_SPINACH', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_spinach', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_spinach_var_2', 'veg_spinach', 500, 'kg', 40, 35, 'SKU_VEG_SPINACH_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_spinach_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_spinach_var_3', 'veg_spinach', 1, 'kg', 75, 65, 'SKU_VEG_SPINACH_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_spinach_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Tomato
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('veg_tomato', 'vegetables', 'organic_vegetables', 'Tomato', 'Fresh, juicy red tomatoes with a rich natural taste for everyday cooking.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Vegetables/Tomato.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_veg_tomato', 'veg_tomato') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_tomato', 'veg_tomato', 500, 'kg', 32, 26, 'SKU_VEG_TOMATO', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_tomato', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_tomato_var_2', 'veg_tomato', 1, 'kg', 60, 49, 'SKU_VEG_TOMATO_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_tomato_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('veg_tomato_var_3', 'veg_tomato', 2, 'kg', 110, 92, 'SKU_VEG_TOMATO_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('veg_tomato_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Apple
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_apple', 'fruits', 'fresh_fruits', 'Apple', 'Fresh premium red apples.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Apple.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_apple', 'fr_apple') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_apple', 'fr_apple', 500, 'kg', 115, 105, 'SKU_FR_APPLE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_apple', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_apple_var_2', 'fr_apple', 1, 'kg', 220, 199, 'SKU_FR_APPLE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_apple_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_apple_var_3', 'fr_apple', 2, 'kg', 420, 380, 'SKU_FR_APPLE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_apple_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Banana
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_banana', 'fruits', null, 'Banana', 'Fresh ripe yellow bananas.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Banana.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_banana', 'fr_banana') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_banana', 'fr_banana', 6, 'pcs', 38, 32, 'SKU_FR_BANANA', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_banana', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_banana_var_2', 'fr_banana', 1, 'pcs', 70, 59, 'SKU_FR_BANANA_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_banana_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_banana_var_3', 'fr_banana', 2, 'pcs', 130, 110, 'SKU_FR_BANANA_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_banana_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Grapes
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_grapes', 'fruits', 'fresh_fruits', 'Grapes', 'Fresh seedless green grapes.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Grapes.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_grapes', 'fr_grapes') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_grapes', 'fr_grapes', 250, 'kg', 48, 42, 'SKU_FR_GRAPES', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_grapes', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_grapes_var_2', 'fr_grapes', 500, 'kg', 90, 79, 'SKU_FR_GRAPES_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_grapes_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_grapes_var_3', 'fr_grapes', 1, 'kg', 170, 150, 'SKU_FR_GRAPES_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_grapes_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Guava
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_guava', 'fruits', null, 'Guava', 'Fresh green guava rich in Vitamin C.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Guava.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_guava', 'fr_guava') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_guava', 'fr_guava', 500, 'kg', 48, 42, 'SKU_FR_GUAVA', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_guava', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_guava_var_2', 'fr_guava', 1, 'kg', 90, 79, 'SKU_FR_GUAVA_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_guava_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_guava_var_3', 'fr_guava', 2, 'kg', 170, 150, 'SKU_FR_GUAVA_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_guava_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Kashmiri Guava
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_kashmiri_guava', 'fruits', null, 'Kashmiri Guava', 'Premium sweet Kashmiri guava.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Kashmiri%20Guava.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_kashmiri_guava', 'fr_kashmiri_guava') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_kashmiri_guava', 'fr_kashmiri_guava', 500, 'kg', 75, 69, 'SKU_FR_KASHMIRI_GUAVA', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_kashmiri_guava', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_kashmiri_guava_var_2', 'fr_kashmiri_guava', 1, 'kg', 140, 129, 'SKU_FR_KASHMIRI_GUAVA_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_kashmiri_guava_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_kashmiri_guava_var_3', 'fr_kashmiri_guava', 2, 'kg', 270, 249, 'SKU_FR_KASHMIRI_GUAVA_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_kashmiri_guava_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Kiwi
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_kiwi', 'fruits', null, 'Kiwi', 'Imported fresh kiwi fruit.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Kiwi.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_kiwi', 'fr_kiwi') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_kiwi', 'fr_kiwi', 3, 'pcs', 150, 139, 'SKU_FR_KIWI', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_kiwi', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_kiwi_var_2', 'fr_kiwi', 6, 'pcs', 290, 269, 'SKU_FR_KIWI_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_kiwi_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_kiwi_var_3', 'fr_kiwi', 12, 'pcs', 550, 519, 'SKU_FR_KIWI_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_kiwi_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Mango
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_mango', 'fruits', 'fresh_fruits', 'Mango', 'Sweet juicy seasonal mangoes.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Mango.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_mango', 'fr_mango') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_mango', 'fr_mango', 500, 'kg', 65, 55, 'SKU_FR_MANGO', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_mango', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_mango_var_2', 'fr_mango', 1, 'kg', 120, 99, 'SKU_FR_MANGO_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_mango_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_mango_var_3', 'fr_mango', 2, 'kg', 230, 189, 'SKU_FR_MANGO_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_mango_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Orange
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_orange', 'fruits', null, 'Orange', 'Fresh juicy oranges.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Orange.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_orange', 'fr_orange') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_orange', 'fr_orange', 500, 'kg', 55, 48, 'SKU_FR_ORANGE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_orange', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_orange_var_2', 'fr_orange', 1, 'kg', 100, 89, 'SKU_FR_ORANGE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_orange_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_orange_var_3', 'fr_orange', 2, 'kg', 190, 169, 'SKU_FR_ORANGE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_orange_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Papaya
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_papaya', 'fruits', null, 'Papaya', 'Naturally ripe fresh papaya.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Papaya.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_papaya', 'fr_papaya') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_papaya', 'fr_papaya', 1, 'kg', 70, 59, 'SKU_FR_PAPAYA', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_papaya', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_papaya_var_2', 'fr_papaya', 1, 'kg', 70, 59, 'SKU_FR_PAPAYA_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_papaya_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_papaya_var_3', 'fr_papaya', 1, 'kg', 70, 59, 'SKU_FR_PAPAYA_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_papaya_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Pear
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_pear', 'fruits', null, 'Pear', 'Fresh crunchy pears.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Papaya.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_pear', 'fr_pear') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pear', 'fr_pear', 500, 'kg', 115, 105, 'SKU_FR_PEAR', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pear', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pear_var_2', 'fr_pear', 1, 'kg', 220, 199, 'SKU_FR_PEAR_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pear_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pear_var_3', 'fr_pear', 2, 'kg', 420, 380, 'SKU_FR_PEAR_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pear_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Pineapple
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_pineapple', 'fruits', 'fresh_fruits', 'Pineapple', 'Sweet tropical pineapple.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Pineapple.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_pineapple', 'fr_pineapple') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pineapple', 'fr_pineapple', 1, 'pcs', 90, 79, 'SKU_FR_PINEAPPLE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pineapple', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pineapple_var_2', 'fr_pineapple', 1, 'pcs', 90, 79, 'SKU_FR_PINEAPPLE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pineapple_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pineapple_var_3', 'fr_pineapple', 1, 'pcs', 90, 79, 'SKU_FR_PINEAPPLE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pineapple_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Pomegranate
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_pomegranate', 'fruits', null, 'Pomegranate', 'Fresh ruby red pomegranate.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Pomegranate.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_pomegranate', 'fr_pomegranate') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pomegranate', 'fr_pomegranate', 500, 'kg', 115, 105, 'SKU_FR_POMEGRANATE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pomegranate', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pomegranate_var_2', 'fr_pomegranate', 1, 'kg', 220, 199, 'SKU_FR_POMEGRANATE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pomegranate_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_pomegranate_var_3', 'fr_pomegranate', 2, 'kg', 420, 380, 'SKU_FR_POMEGRANATE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_pomegranate_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Watermelon
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('fr_watermelon', 'fruits', null, 'Watermelon', 'Fresh juicy watermelon.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Fruits/Watermelon.webp', true, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into organic_products (id, product_id) values ('org_fr_watermelon', 'fr_watermelon') on conflict (id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_watermelon', 'fr_watermelon', 1, 'pcs', 110, 99, 'SKU_FR_WATERMELON', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_watermelon', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_watermelon_var_2', 'fr_watermelon', 1, 'pcs', 110, 99, 'SKU_FR_WATERMELON_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_watermelon_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('fr_watermelon_var_3', 'fr_watermelon', 1, 'pcs', 110, 99, 'SKU_FR_WATERMELON_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('fr_watermelon_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Amulya Milk Powder
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_amulya_milk_powder', 'dairy', null, 'Amulya Milk Powder', 'Premium dairy whitener made from high-quality milk, perfect for tea, coffee, and desserts.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Amulya.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_amulya_milk_powder', 'dy_amulya_milk_powder', 200, 'kg', 110, 105, 'SKU_DY_AMULYA_MILK_POWDER', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_amulya_milk_powder', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_amulya_milk_powder_var_2', 'dy_amulya_milk_powder', 500, 'kg', 255, 245, 'SKU_DY_AMULYA_MILK_POWDER_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_amulya_milk_powder_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_amulya_milk_powder_var_3', 'dy_amulya_milk_powder', 1, 'kg', 499, 479, 'SKU_DY_AMULYA_MILK_POWDER_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_amulya_milk_powder_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Butter
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_butter', 'dairy', null, 'Butter', 'Fresh and creamy salted butter made from pure milk, ideal for cooking, baking, and spreading.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Butter.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_butter', 'dy_butter', 100, 'kg', 65, 62, 'SKU_DY_BUTTER', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_butter', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_butter_var_2', 'dy_butter', 500, 'kg', 310, 299, 'SKU_DY_BUTTER_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_butter_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_butter_var_3', 'dy_butter', 1, 'kg', 600, 585, 'SKU_DY_BUTTER_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_butter_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Buttermilk
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_buttermilk', 'dairy', null, 'Buttermilk', 'Refreshing probiotic buttermilk prepared from fresh curd, perfect for daily digestion and hydration.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/ButterMilk.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_buttermilk', 'dy_buttermilk', 200, 'kg', 13, 12, 'SKU_DY_BUTTERMILK', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_buttermilk', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_buttermilk_var_2', 'dy_buttermilk', 500, 'kg', 29, 27, 'SKU_DY_BUTTERMILK_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_buttermilk_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_buttermilk_var_3', 'dy_buttermilk', 1, 'kg', 55, 52, 'SKU_DY_BUTTERMILK_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_buttermilk_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Cheese
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_cheese', 'dairy', null, 'Cheese', 'Rich and creamy processed cheese made from premium milk, suitable for sandwiches, pizzas, and snacks.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Cheese.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_cheese', 'dy_cheese', 100, 'kg', 72, 68, 'SKU_DY_CHEESE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_cheese', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_cheese_var_2', 'dy_cheese', 200, 'kg', 135, 129, 'SKU_DY_CHEESE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_cheese_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_cheese_var_3', 'dy_cheese', 400, 'kg', 260, 249, 'SKU_DY_CHEESE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_cheese_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Fresh Cream
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_fresh_cream', 'dairy', null, 'Fresh Cream', 'Smooth and rich fresh cream for cooking, baking, soups, desserts, and gravies.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Cream.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_fresh_cream', 'dy_fresh_cream', 250, 'kg', 75, 70, 'SKU_DY_FRESH_CREAM', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_fresh_cream', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_fresh_cream_var_2', 'dy_fresh_cream', 1, 'kg', 275, 259, 'SKU_DY_FRESH_CREAM_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_fresh_cream_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_fresh_cream_var_3', 'dy_fresh_cream', 2, 'kg', 530, 499, 'SKU_DY_FRESH_CREAM_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_fresh_cream_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Curd
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_curd', 'dairy', null, 'Curd', 'Thick and creamy fresh curd prepared from high-quality pasteurized milk.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Curd.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_curd', 'dy_curd', 200, 'kg', 20, 18, 'SKU_DY_CURD', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_curd', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_curd_var_2', 'dy_curd', 400, 'kg', 36, 34, 'SKU_DY_CURD_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_curd_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_curd_var_3', 'dy_curd', 900, 'kg', 52, 49, 'SKU_DY_CURD_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_curd_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Dahi
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_dahi', 'dairy', 'fresh_milk', 'Dahi', 'Fresh homemade-style dahi with a rich texture and natural taste, ideal for daily meals.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Dahi.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_dahi', 'dy_dahi', 200, 'kg', 20, 18, 'SKU_DY_DAHI', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_dahi', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_dahi_var_2', 'dy_dahi', 450, 'kg', 36, 34, 'SKU_DY_DAHI_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_dahi_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_dahi_var_3', 'dy_dahi', 1, 'kg', 75, 72, 'SKU_DY_DAHI_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_dahi_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Ghee
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_ghee', 'dairy', null, 'Ghee', 'Pure cow ghee with authentic aroma and rich taste, suitable for cooking and religious use.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Ghee.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_ghee', 'dy_ghee', 200, 'kg', 165, 155, 'SKU_DY_GHEE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_ghee', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_ghee_var_2', 'dy_ghee', 500, 'kg', 365, 350, 'SKU_DY_GHEE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_ghee_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_ghee_var_3', 'dy_ghee', 1, 'pcs', 710, 679, 'SKU_DY_GHEE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_ghee_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Ice Cream
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_ice_cream', 'dairy', null, 'Ice Cream', 'Delicious creamy vanilla ice cream made with premium dairy ingredients for a rich taste.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Ice%20Cream.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_ice_cream', 'dy_ice_cream', 100, 'kg', 28, 25, 'SKU_DY_ICE_CREAM', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_ice_cream', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_ice_cream_var_2', 'dy_ice_cream', 500, 'kg', 120, 110, 'SKU_DY_ICE_CREAM_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_ice_cream_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_ice_cream_var_3', 'dy_ice_cream', 750, 'kg', 162, 149, 'SKU_DY_ICE_CREAM_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_ice_cream_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Malai
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_malai', 'dairy', null, 'Malai', 'Fresh milk malai with a rich creamy texture, ideal for sweets, curries, and desserts.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Malai.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_malai', 'dy_malai', 100, 'kg', 42, 39, 'SKU_DY_MALAI', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_malai', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_malai_var_2', 'dy_malai', 250, 'kg', 95, 89, 'SKU_DY_MALAI_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_malai_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_malai_var_3', 'dy_malai', 500, 'kg', 180, 169, 'SKU_DY_MALAI_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_malai_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Milk
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_milk', 'dairy', 'fresh_milk', 'Milk', 'Fresh pasteurized toned milk rich in calcium and protein for everyday nutrition.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Milk.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_milk', 'dy_milk', 500, 'kg', 35, 34, 'SKU_DY_MILK', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_milk', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_milk_var_2', 'dy_milk', 1, 'pcs', 70, 68, 'SKU_DY_MILK_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_milk_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_milk_var_3', 'dy_milk', 2, 'pcs', 136, 132, 'SKU_DY_MILK_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_milk_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Paneer
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('dy_paneer', 'dairy', 'fresh_milk', 'Paneer', 'Soft and fresh cottage cheese made from pure milk, perfect for Indian and continental dishes.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Dairy/Paneer.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_paneer', 'dy_paneer', 100, 'kg', 45, 42, 'SKU_DY_PANEER', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_paneer', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_paneer_var_2', 'dy_paneer', 200, 'kg', 85, 79, 'SKU_DY_PANEER_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_paneer_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('dy_paneer_var_3', 'dy_paneer', 500, 'kg', 200, 189, 'SKU_DY_PANEER_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('dy_paneer_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Bread
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bk_bread', 'bakery', null, 'Bread', 'Freshly baked soft sandwich bread made from premium wheat flour, perfect for breakfast and snacks.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Bakery/Bread.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_bread', 'bk_bread', 200, 'kg', 30, 27, 'SKU_BK_BREAD', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_bread', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_bread_var_2', 'bk_bread', 400, 'kg', 50, 45, 'SKU_BK_BREAD_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_bread_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_bread_var_3', 'bk_bread', 800, 'kg', 95, 89, 'SKU_BK_BREAD_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_bread_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Chocolate Cake
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bk_chocolate_cake', 'bakery', 'cakes', 'Chocolate Cake', 'Rich chocolate sponge cake layered with creamy chocolate frosting, ideal for birthdays and celebrations.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Bakery/Cocoalate%20Cake.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_chocolate_cake', 'bk_chocolate_cake', 500, 'kg', 550, 499, 'SKU_BK_CHOCOLATE_CAKE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_chocolate_cake', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_chocolate_cake_var_2', 'bk_chocolate_cake', 1, 'kg', 1000, 899, 'SKU_BK_CHOCOLATE_CAKE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_chocolate_cake_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_chocolate_cake_var_3', 'bk_chocolate_cake', 2, 'kg', 1950, 1799, 'SKU_BK_CHOCOLATE_CAKE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_chocolate_cake_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Fruit Cake
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bk_fruit_cake', 'bakery', 'cakes', 'Fruit Cake', 'Soft vanilla sponge cake topped with fresh seasonal fruits and whipped cream.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Bakery/Fruit%20Cake.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_fruit_cake', 'bk_fruit_cake', 500, 'kg', 600, 549, 'SKU_BK_FRUIT_CAKE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_fruit_cake', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_fruit_cake_var_2', 'bk_fruit_cake', 1, 'kg', 1100, 999, 'SKU_BK_FRUIT_CAKE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_fruit_cake_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_fruit_cake_var_3', 'bk_fruit_cake', 2, 'kg', 2100, 1949, 'SKU_BK_FRUIT_CAKE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_fruit_cake_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Anniversary Cake
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bk_multi_layer_cake', 'bakery', 'cakes', 'Anniversary Cake', 'Premium multi-layer celebration cake with delicious cream filling and decorative frosting.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Bakery/MCake.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_multi_layer_cake', 'bk_multi_layer_cake', 1, 'kg', 1100, 999, 'SKU_BK_MULTI_LAYER_CAKE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_multi_layer_cake', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_multi_layer_cake_var_2', 'bk_multi_layer_cake', 2, 'kg', 2100, 1949, 'SKU_BK_MULTI_LAYER_CAKE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_multi_layer_cake_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_multi_layer_cake_var_3', 'bk_multi_layer_cake', 3, 'kg', 3100, 2899, 'SKU_BK_MULTI_LAYER_CAKE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_multi_layer_cake_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Pav Buns
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bk_pav_buns', 'bakery', null, 'Pav Buns', 'Soft and fluffy pav buns freshly baked, perfect for pav bhaji, burgers, and sandwiches.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Bakery/Paav%20Buns.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_pav_buns', 'bk_pav_buns', 4, 'pcs', 30, 27, 'SKU_BK_PAV_BUNS', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_pav_buns', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_pav_buns_var_2', 'bk_pav_buns', 6, 'pcs', 45, 40, 'SKU_BK_PAV_BUNS_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_pav_buns_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_pav_buns_var_3', 'bk_pav_buns', 12, 'pcs', 85, 79, 'SKU_BK_PAV_BUNS_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_pav_buns_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Pizza
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bk_pizza', 'bakery', null, 'Pizza', 'Freshly baked vegetable cheese pizza loaded with mozzarella cheese and flavorful toppings.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Bakery/Pizza.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_pizza', 'bk_pizza', 1, 'pcs', 349, 299, 'SKU_BK_PIZZA', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_pizza', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_pizza_var_2', 'bk_pizza', 1, 'pcs', 349, 299, 'SKU_BK_PIZZA_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_pizza_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bk_pizza_var_3', 'bk_pizza', 1, 'pcs', 349, 299, 'SKU_BK_PIZZA_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bk_pizza_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Aloo Bhujiya
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('sn_aloo_bhujiya', 'snacks', null, 'Aloo Bhujiya', 'Crispy and spicy potato-based namkeen made with gram flour, perfect for tea-time and everyday snacking.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Snacks/Aloo%20Bhujiya.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_aloo_bhujiya', 'sn_aloo_bhujiya', 150, 'kg', 60, 55, 'SKU_SN_ALOO_BHUJIYA', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_aloo_bhujiya', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_aloo_bhujiya_var_2', 'sn_aloo_bhujiya', 400, 'kg', 170, 159, 'SKU_SN_ALOO_BHUJIYA_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_aloo_bhujiya_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_aloo_bhujiya_var_3', 'sn_aloo_bhujiya', 1, 'kg', 390, 369, 'SKU_SN_ALOO_BHUJIYA_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_aloo_bhujiya_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Aloo Bhujiyaa (Premium)
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('sn_aloo_bhujiya_premium', 'snacks', null, 'Aloo Bhujiyaa (Premium)', 'Premium crunchy aloo bhujia prepared with authentic spices for a rich traditional taste.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Snacks/Aloo%20Bhujiya.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_aloo_bhujiya_premium', 'sn_aloo_bhujiya_premium', 150, 'kg', 70, 65, 'SKU_SN_ALOO_BHUJIYA_PREMIUM', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_aloo_bhujiya_premium', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_aloo_bhujiya_premium_var_2', 'sn_aloo_bhujiya_premium', 400, 'kg', 190, 179, 'SKU_SN_ALOO_BHUJIYA_PREMIUM_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_aloo_bhujiya_premium_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_aloo_bhujiya_premium_var_3', 'sn_aloo_bhujiya_premium', 1, 'kg', 420, 399, 'SKU_SN_ALOO_BHUJIYA_PREMIUM_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_aloo_bhujiya_premium_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Biscuit
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('sn_biscuit', 'snacks', null, 'Biscuit', 'Crispy and delicious tea-time biscuits baked with premium quality ingredients.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Snacks/Biscuit.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_biscuit', 'sn_biscuit', 100, 'kg', 20, 18, 'SKU_SN_BISCUIT', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_biscuit', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_biscuit_var_2', 'sn_biscuit', 300, 'kg', 55, 50, 'SKU_SN_BISCUIT_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_biscuit_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_biscuit_var_3', 'sn_biscuit', 600, 'kg', 105, 95, 'SKU_SN_BISCUIT_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_biscuit_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Butter Makkhan Roti
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('sn_butter_makkhan_roti', 'snacks', null, 'Butter Makkhan Roti', 'Soft butter-flavoured baked roti, ready to heat and enjoy with curries or tea.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Snacks/Butter%20Makkhan%20Roti.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_butter_makkhan_roti', 'sn_butter_makkhan_roti', 3, 'pcs', 40, 36, 'SKU_SN_BUTTER_MAKKHAN_ROTI', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_butter_makkhan_roti', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_butter_makkhan_roti_var_2', 'sn_butter_makkhan_roti', 6, 'pcs', 75, 69, 'SKU_SN_BUTTER_MAKKHAN_ROTI_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_butter_makkhan_roti_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_butter_makkhan_roti_var_3', 'sn_butter_makkhan_roti', 12, 'pcs', 140, 129, 'SKU_SN_BUTTER_MAKKHAN_ROTI_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_butter_makkhan_roti_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Kurkure
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('sn_kurkure', 'snacks', null, 'Kurkure', 'Crunchy masala corn puffs packed with bold Indian spices for a delicious snack.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Snacks/Kurkure.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_kurkure', 'sn_kurkure', 40, 'kg', 10, 10, 'SKU_SN_KURKURE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_kurkure', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_kurkure_var_2', 'sn_kurkure', 90, 'kg', 25, 20, 'SKU_SN_KURKURE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_kurkure_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_kurkure_var_3', 'sn_kurkure', 150, 'kg', 35, 33, 'SKU_SN_KURKURE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_kurkure_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Lay\
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('sn_lays_classic_chips', 'snacks', null, 'Lay\', 'Thin, crispy potato chips lightly salted for a classic crunchy snacking experience.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Snacks/Lays.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_lays_classic_chips', 'sn_lays_classic_chips', 30, 'kg', 10, 10, 'SKU_SN_LAYS_CLASSIC_CHIPS', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_lays_classic_chips', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_lays_classic_chips_var_2', 'sn_lays_classic_chips', 50, 'kg', 20, 20, 'SKU_SN_LAYS_CLASSIC_CHIPS_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_lays_classic_chips_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('sn_lays_classic_chips_var_3', 'sn_lays_classic_chips', 82, 'kg', 50, 45, 'SKU_SN_LAYS_CLASSIC_CHIPS_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('sn_lays_classic_chips_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Cold Coffee
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bv_cold_coffee', 'beverages', null, 'Cold Coffee', 'Rich and creamy ready-to-drink cold coffee made with premium milk and coffee beans.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Beverage/Cold%20Coffee.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_cold_coffee', 'bv_cold_coffee', 180, 'pcs', 40, 38, 'SKU_BV_COLD_COFFEE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_cold_coffee', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_cold_coffee_var_2', 'bv_cold_coffee', 250, 'pcs', 60, 55, 'SKU_BV_COLD_COFFEE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_cold_coffee_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_cold_coffee_var_3', 'bv_cold_coffee', 300, 'pcs', 75, 69, 'SKU_BV_COLD_COFFEE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_cold_coffee_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Lahori Zeera
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bv_lahori_zeera', 'beverages', null, 'Lahori Zeera', 'Refreshing jeera-flavored carbonated drink with authentic Indian spices.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Beverage/Lahori%20Zeera.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_lahori_zeera', 'bv_lahori_zeera', 250, 'pcs', 20, 18, 'SKU_BV_LAHORI_ZEERA', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_lahori_zeera', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_lahori_zeera_var_2', 'bv_lahori_zeera', 600, 'pcs', 45, 40, 'SKU_BV_LAHORI_ZEERA_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_lahori_zeera_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_lahori_zeera_var_3', 'bv_lahori_zeera', 1.25, 'pcs', 75, 69, 'SKU_BV_LAHORI_ZEERA_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_lahori_zeera_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Lassi
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bv_lassi', 'beverages', null, 'Lassi', 'Traditional sweet yogurt drink made from fresh curd, perfect for a refreshing treat.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Beverage/Lassi.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_lassi', 'bv_lassi', 200, 'pcs', 30, 28, 'SKU_BV_LASSI', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_lassi', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_lassi_var_2', 'bv_lassi', 500, 'pcs', 60, 55, 'SKU_BV_LASSI_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_lassi_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_lassi_var_3', 'bv_lassi', 1, 'pcs', 110, 99, 'SKU_BV_LASSI_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_lassi_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Maaza
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bv_maaza', 'beverages', null, 'Maaza', 'Delicious mango fruit drink made with real mango pulp for a refreshing taste.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Beverage/Maaza.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_maaza', 'bv_maaza', 250, 'pcs', 20, 18, 'SKU_BV_MAAZA', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_maaza', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_maaza_var_2', 'bv_maaza', 600, 'pcs', 45, 40, 'SKU_BV_MAAZA_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_maaza_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_maaza_var_3', 'bv_maaza', 1.2, 'pcs', 75, 69, 'SKU_BV_MAAZA_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_maaza_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Mineral Drinking Water
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bv_mineral_drinking_water', 'beverages', null, 'Mineral Drinking Water', 'Packaged drinking water purified through advanced filtration for safe daily hydration.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Beverage/Mineral%20Drinking%20Water.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_mineral_drinking_water', 'bv_mineral_drinking_water', 500, 'pcs', 10, 10, 'SKU_BV_MINERAL_DRINKING_WATER', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_mineral_drinking_water', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_mineral_drinking_water_var_2', 'bv_mineral_drinking_water', 1, 'pcs', 20, 20, 'SKU_BV_MINERAL_DRINKING_WATER_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_mineral_drinking_water_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_mineral_drinking_water_var_3', 'bv_mineral_drinking_water', 2, 'pcs', 30, 28, 'SKU_BV_MINERAL_DRINKING_WATER_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_mineral_drinking_water_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Soda Water
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bv_soda_water', 'beverages', null, 'Soda Water', 'Crisp carbonated soda water, ideal for refreshing drinks and mocktails.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Beverage/Soda%20Water.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_soda_water', 'bv_soda_water', 300, 'pcs', 15, 14, 'SKU_BV_SODA_WATER', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_soda_water', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_soda_water_var_2', 'bv_soda_water', 750, 'pcs', 25, 22, 'SKU_BV_SODA_WATER_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_soda_water_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_soda_water_var_3', 'bv_soda_water', 1, 'pcs', 35, 32, 'SKU_BV_SODA_WATER_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_soda_water_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Sprite
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bv_sprite', 'beverages', null, 'Sprite', 'Lemon-lime flavored soft drink with a refreshing and fizzy taste.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Beverage/Sprite.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_sprite', 'bv_sprite', 250, 'pcs', 20, 18, 'SKU_BV_SPRITE', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_sprite', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_sprite_var_2', 'bv_sprite', 750, 'pcs', 40, 38, 'SKU_BV_SPRITE_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_sprite_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_sprite_var_3', 'bv_sprite', 2.25, 'pcs', 99, 95, 'SKU_BV_SPRITE_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_sprite_var_3', true) on conflict (variant_id) do nothing;

  -- Product: Sting Energy Drink
  insert into products (id, category_id, sub_category_id, name, description, image_url, is_organic, status)
  values ('bv_sting_energy_drink', 'beverages', null, 'Sting Energy Drink', 'High-energy carbonated drink with caffeine and vitamins for an instant energy boost.', base_url || '/storage/v1/object/public/SabzeeWala/Products/Beverage/Sting%20Drink.webp', false, 'active')
  on conflict (id) do update set image_url = excluded.image_url, name = excluded.name, description = excluded.description;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_sting_energy_drink', 'bv_sting_energy_drink', 250, 'pcs', 25, 22, 'SKU_BV_STING_ENERGY_DRINK', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_sting_energy_drink', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_sting_energy_drink_var_2', 'bv_sting_energy_drink', 350, 'pcs', 35, 32, 'SKU_BV_STING_ENERGY_DRINK_VAR_2', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_sting_energy_drink_var_2', true) on conflict (variant_id) do nothing;
  insert into product_variants (id, product_id, weight, unit, mrp, selling_price, sku, stock_total)
  values ('bv_sting_energy_drink_var_3', 'bv_sting_energy_drink', 500, 'pcs', 55, 50, 'SKU_BV_STING_ENERGY_DRINK_VAR_3', 100)
  on conflict (id) do update set mrp = excluded.mrp, selling_price = excluded.selling_price;
  insert into inventory (variant_id, in_stock) values ('bv_sting_energy_drink_var_3', true) on conflict (variant_id) do nothing;

END $$;
