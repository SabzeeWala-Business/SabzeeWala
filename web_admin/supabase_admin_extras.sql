-- Optional Supabase schema extras for Sabzee Web Admin
-- Run in Supabase SQL Editor if columns/tables are missing.

-- Store charges
alter table if exists store_settings
  add column if not exists service_charge numeric default 0,
  add column if not exists packaging_fee numeric default 0;

-- Category image (optional)
alter table if exists categories
  add column if not exists image_url text,
  add column if not exists status text default 'active';

-- Orders payment fields (used by Flutter + admin)
alter table if exists orders
  add column if not exists payment_method text,
  add column if not exists delivery_fee numeric default 0,
  add column if not exists delivery_address text;

-- Denormalized invoice fields on line items
alter table if exists order_items
  add column if not exists product_name text,
  add column if not exists weight text,
  add column if not exists unit text;

-- Profile status / phone aliases for admin directory
alter table if exists profiles
  add column if not exists phone text,
  add column if not exists status text default 'active',
  add column if not exists role text default 'customer';

-- Staff directory
create table if not exists employees (
  id text primary key,
  name text not null,
  role text,
  phone text,
  status text default 'active',
  created_at timestamptz default now()
);

-- B2B / company accounts
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

-- Enable realtime for live order notifications (Dashboard → Database → Replication)
-- alter publication supabase_realtime add table orders;

-- Wishlists table (synced from Flutter favorites)
create table if not exists wishlists (
  id uuid primary key default gen_random_uuid(),
  user_id text not null, -- Holds mobile number/identifier
  product_id text not null,
  created_at timestamptz default now(),
  unique (user_id, product_id)
);

-- Inventory table (replaces profiles hack for stock status)
create table if not exists inventory (
  variant_id text primary key references product_variants(id) on delete cascade,
  in_stock boolean not null default true,
  updated_at timestamptz default now()
);

-- Enable realtime for wishlist and inventory
-- alter publication supabase_realtime add table wishlists;
-- alter publication supabase_realtime add table inventory;

-- Stock quantity on product_variants (REQUIRED for web admin inventory management)
alter table if exists product_variants
  add column if not exists stock_total integer default null;

-- User sessions and live app traffic tracking
create table if not exists user_sessions (
  user_id text primary key, -- User mobile identifier acts as primary key
  login_time timestamptz default now(),
  last_active_at timestamptz default now(),
  app_opens integer default 1,
  current_state text default 'browsing', -- browsing | details | cart | checkout | searching
  search_query text, -- Current active search query typed in mobile app
  session_duration integer default 0,
  device_info text,
  created_at timestamptz default now()
);

-- Ensure user_sessions columns exist if the table was created previously without them
alter table if exists user_sessions
  add column if not exists current_state text default 'browsing',
  add column if not exists search_query text,
  add column if not exists session_duration integer default 0,
  add column if not exists device_info text;

-- Cart last update tracking
alter table if exists cart 
  add column if not exists updated_at timestamptz default now();

create index if not exists idx_sessions_last_active on user_sessions(last_active_at);

-- Onboarding and device logs for profiles / users
alter table if exists users
  add column if not exists profile_completion_status text default 'incomplete',
  add column if not exists registration_date timestamptz default now(),
  add column if not exists last_login_date timestamptz default now(),
  add column if not exists first_login_date timestamptz default now(),
  add column if not exists login_count integer default 1,
  add column if not exists last_active_time timestamptz default now(),
  add column if not exists app_version_used text,
  
  -- Device information columns
  add column if not exists device_brand text,
  add column if not exists device_model text,
  add column if not exists android_version text,
  add column if not exists app_version text,
  add column if not exists device_identifier text,
  add column if not exists screen_resolution text,
  add column if not exists language text,
  add column if not exists time_zone text,
  add column if not exists country text,
  add column if not exists network_type text,
  add column if not exists device_change_history jsonb default '[]'::jsonb;

-- Organic & New Launch flags on products
alter table if exists products
  add column if not exists is_organic boolean default false,
  add column if not exists is_new_launch boolean default false,
  add column if not exists sub_category_id text,
  add column if not exists status text default 'active';

-- Cost / purchase price on product_variants for margin tracking
alter table if exists product_variants
  add column if not exists purchase_price numeric default 0,
  add column if not exists barcode text;

-- Display order on categories
alter table if exists categories
  add column if not exists display_order integer default 0,
  add column if not exists icon text;

-- Inventory Spoilage / Wastage Log
create table if not exists inventory_wastage (
  id uuid primary key default gen_random_uuid(),
  variant_id text references product_variants(id) on delete cascade,
  product_name text not null,
  quantity numeric not null,
  reason text not null, -- 'damaged', 'expired', 'shrinkage', 'quality_rejection'
  cost_loss numeric default 0,
  logged_by text default 'Admin',
  created_at timestamptz default now()
);

-- Suppliers Directory
create table if not exists suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_person text,
  phone text not null,
  email text,
  gst text,
  address text,
  payment_terms text default 'Net 15', -- 'Cash on Delivery', 'Net 15', 'Net 30'
  status text default 'active',
  created_at timestamptz default now()
);

-- Purchase Orders & Items
create table if not exists purchase_orders (
  id text primary key,
  supplier_id uuid references suppliers(id) on delete set null,
  supplier_name text not null,
  total_amount numeric default 0,
  status text default 'pending', -- 'pending', 'approved', 'received', 'cancelled'
  items jsonb default '[]'::jsonb,
  expected_delivery_date date,
  received_at timestamptz,
  notes text,
  created_at timestamptz default now()
);

-- Delivery Partners
create table if not exists delivery_partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  vehicle_type text default 'Bike',
  vehicle_number text,
  driving_license text,
  status text default 'available', -- 'available', 'on_delivery', 'offline', 'inactive'
  active_orders_count integer default 0,
  total_deliveries integer default 0,
  payout_per_order numeric default 35,
  created_at timestamptz default now()
);

-- Rider Order Assignment
alter table if exists orders
  add column if not exists rider_id uuid references delivery_partners(id) on delete set null,
  add column if not exists rider_name text,
  add column if not exists rider_phone text;

-- Store Settings (Master App Control)
create table if not exists store_settings (
  id text primary key default 'main_store',
  store_name text default 'Sabzee Quick Mart',
  is_store_open boolean default true,
  opening_time text default '06:00 AM',
  closing_time text default '11:00 PM',
  base_delivery_fee numeric default 30,
  free_delivery_threshold numeric default 139,
  product_handling_fee numeric default 2,
  delivery_radius_km numeric default 10,
  contact_phone text default '+91 9876543210',
  support_email text default 'support@sabzeewala.com',
  referral_reward_amount numeric default 100,
  updated_at timestamptz default now()
);

-- Support Tickets
create table if not exists support_tickets (
  id text primary key,
  user_id text not null,
  customer_name text,
  customer_phone text,
  order_id text,
  category text default 'General', -- 'Missing Item', 'Quality Issue', 'Late Delivery', 'Payment Issue'
  subject text not null,
  message text not null,
  status text default 'open', -- 'open', 'in_progress', 'resolved', 'closed'
  resolution_notes text,
  refund_amount numeric default 0,
  created_at timestamptz default now(),
  resolved_at timestamptz
);

-- Ensure RLS allows admin panel access
CREATE POLICY IF NOT EXISTS "Allow anon all on suppliers" ON public.suppliers FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow anon all on purchase_orders" ON public.purchase_orders FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow anon all on delivery_partners" ON public.delivery_partners FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow anon all on store_settings" ON public.store_settings FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow anon all on support_tickets" ON public.support_tickets FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow anon all on inventory_wastage" ON public.inventory_wastage FOR ALL TO anon USING (true) WITH CHECK (true);

-- Push Notifications Audit Log & Campaign Store
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  type text DEFAULT 'broadcast', -- 'broadcast', 'direct', 'order_status'
  user_id text,
  status text DEFAULT 'sent',
  recipients_count integer DEFAULT 1,
  created_at timestamptz DEFAULT now()
);

CREATE POLICY IF NOT EXISTS "Allow anon all on notifications" ON public.notifications FOR ALL TO anon USING (true) WITH CHECK (true);

