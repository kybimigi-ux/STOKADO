-- =============================================================================
-- CBHIMS 1.1 → Supabase Migration Script
-- Project ID : cunrimpeugkvejtjouhw
-- Run this entire script in the Supabase SQL Editor
-- =============================================================================

-- Enable UUID extension (already available on Supabase, but safe to repeat)
create extension if not exists "uuid-ossp";

-- =============================================================================
-- 1. USERS TABLE
-- Mirrors the Firestore `users` collection.
-- auth.users is managed by Supabase Auth; this table stores the profile data.
-- =============================================================================
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text        not null default '',
  email       text        not null default '',
  role        text        check (role in ('admin', 'manager', 'staff')) default null,
  is_demo     boolean     not null default false,
  created_at  timestamptz not null default now()
);

comment on table public.users is 'App user profiles linked to Supabase Auth.';

-- =============================================================================
-- 2. HARDWARES TABLE  (workspaces)
-- Mirrors the Firestore `hardwares` collection.
-- =============================================================================
create table if not exists public.hardwares (
  id              uuid primary key default uuid_generate_v4(),
  name            text        not null,
  description     text        not null default '',
  created_by      uuid        references public.users(id) on delete set null,
  created_at      timestamptz not null default now()
);

comment on table public.hardwares is 'Hardware workspace that groups products and transactions.';

-- =============================================================================
-- 3. HARDWARE MEMBERS TABLE
-- Replaces the embedded `members` map and `memberIds` array in Firestore.
-- =============================================================================
create table if not exists public.hardware_members (
  id                    uuid primary key default uuid_generate_v4(),
  hardware_id           uuid        not null references public.hardwares(id) on delete cascade,
  user_id               uuid        not null references public.users(id) on delete cascade,
  role                  text        not null default 'staff' check (role in ('admin', 'staff')),
  joined_at             timestamptz not null default now(),
  -- Granular permissions (mirrors MemberPermissions in hardware.dart)
  can_add_products      boolean     not null default true,
  can_edit_products     boolean     not null default true,
  can_remove_products   boolean     not null default false,
  can_add_transactions  boolean     not null default true,
  can_cancel_transactions boolean   not null default false,

  unique (hardware_id, user_id)
);

comment on table public.hardware_members is 'Members (users) belonging to a hardware workspace with their roles and permissions.';

-- =============================================================================
-- 4. HARDWARE INVITES TABLE
-- Replaces the `invitedEmails` array in Firestore.
-- =============================================================================
create table if not exists public.hardware_invites (
  id           uuid primary key default uuid_generate_v4(),
  hardware_id  uuid  not null references public.hardwares(id) on delete cascade,
  email        text  not null,
  invited_at   timestamptz not null default now(),

  unique (hardware_id, email)
);

comment on table public.hardware_invites is 'Pending email invitations to join a hardware workspace.';

-- =============================================================================
-- 5. PRODUCTS TABLE  ← price column ADDED here
-- Mirrors hardwares/{id}/products subcollection.
-- =============================================================================
create table if not exists public.products (
  id            uuid primary key default uuid_generate_v4(),
  hardware_id   uuid        not null references public.hardwares(id) on delete cascade,
  product_name  text        not null,
  category_id   uuid        default null,   -- future use / optional
  category_name text        default null,
  quantity      numeric(15, 4) not null default 0,
  unit          text        not null default 'pcs',
  -- ✅ PRICE COLUMN (missing from original system — added here)
  price         numeric(15, 2) not null default 0,   -- selling / retail price per unit
  cost_price    numeric(15, 2) not null default 0,   -- purchase / cost price per unit
  -- ✅ IMAGE URL COLUMN — stores a URL to a product photo (external or Supabase Storage)
  image_url     text        default null,
  is_active     boolean     not null default true,
  remarks       text        default null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.products is 'Inventory products scoped to a hardware workspace.';
comment on column public.products.price      is 'Selling/retail price per unit.';
comment on column public.products.cost_price is 'Purchase/cost price per unit.';

-- Auto-update updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger products_set_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

-- =============================================================================
-- 6. TRANSACTIONS TABLE
-- Mirrors hardwares/{id}/transactions subcollection.
-- =============================================================================
create table if not exists public.transactions (
  id           uuid primary key default uuid_generate_v4(),
  hardware_id  uuid        not null references public.hardwares(id) on delete cascade,
  bill_no      text        not null,
  type         text        not null check (type in ('Receive', 'Release')),
  total_items  numeric(15, 4) not null default 0,
  -- ✅ TOTAL PRICE COLUMN (computed summary — added alongside items)
  total_price  numeric(15, 2) not null default 0,
  status       text        not null default 'Completed' check (status in ('Completed', 'Cancelled', 'Pending')),
  issued_to    text        not null default 'N/A',
  remarks      text        not null default 'N/A',
  created_by   uuid        references public.users(id) on delete set null,
  created_at   timestamptz not null default now()
);

comment on table public.transactions is 'Stock transactions (Receive / Release) scoped to a hardware workspace.';
comment on column public.transactions.total_price is 'Sum of (quantity × price) for all items in this transaction.';

create index if not exists idx_transactions_hardware_id on public.transactions(hardware_id);
create index if not exists idx_transactions_created_at  on public.transactions(created_at desc);
create index if not exists idx_transactions_bill_no     on public.transactions(bill_no);

-- =============================================================================
-- 7. TRANSACTION ITEMS TABLE  ← price column ADDED here
-- Mirrors hardwares/{id}/transactions/{id}/items subcollection.
-- =============================================================================
create table if not exists public.transaction_items (
  id             uuid primary key default uuid_generate_v4(),
  transaction_id uuid        not null references public.transactions(id) on delete cascade,
  hardware_id    uuid        not null references public.hardwares(id) on delete cascade,
  product_id     uuid        references public.products(id) on delete set null,
  product_name   text        not null default '',
  quantity       numeric(15, 4) not null default 0,
  unit           text        not null default 'pcs',
  -- ✅ PRICE COLUMN (missing from original system — added here)
  price          numeric(15, 2) not null default 0,   -- price per unit at time of transaction
  line_total     numeric(15, 2) generated always as (quantity * price) stored,
  created_at     timestamptz not null default now()
);

comment on table public.transaction_items is 'Individual line items within a transaction.';
comment on column public.transaction_items.price      is 'Unit price at the time of the transaction (snapshot from products.price).';
comment on column public.transaction_items.line_total is 'Computed: quantity × price.';

create index if not exists idx_transaction_items_transaction_id on public.transaction_items(transaction_id);
create index if not exists idx_transaction_items_product_id     on public.transaction_items(product_id);

-- =============================================================================
-- 8. ROW LEVEL SECURITY (RLS)
-- =============================================================================

alter table public.users              enable row level security;
alter table public.hardwares          enable row level security;
alter table public.hardware_members   enable row level security;
alter table public.hardware_invites   enable row level security;
alter table public.products           enable row level security;
alter table public.transactions       enable row level security;
alter table public.transaction_items  enable row level security;

-- ─── Helper: check if caller has a role in users table ───────────────────────
create or replace function public.get_my_role()
returns text language sql security definer stable as $$
  select role from public.users where id = auth.uid() limit 1;
$$;

create or replace function public.is_approved()
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role is not null
  );
$$;

create or replace function public.is_admin()
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and lower(role) = 'admin'
  );
$$;

-- ─── Helper: check if caller is a member of a given hardware ─────────────────
create or replace function public.is_hardware_member(p_hardware_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.hardware_members
    where hardware_id = p_hardware_id and user_id = auth.uid()
  );
$$;

-- ─── users ───────────────────────────────────────────────────────────────────
create policy "Users can read all user profiles"
  on public.users for select
  using (auth.uid() is not null);

create policy "Users can insert their own profile"
  on public.users for insert
  with check (id = auth.uid());

create policy "Admins or self can update user profiles"
  on public.users for update
  using (
    public.is_admin()
    or (auth.uid() = id)
  );

create policy "Only admins can delete users"
  on public.users for delete
  using (public.is_admin());

-- ─── hardwares ───────────────────────────────────────────────────────────────
create policy "Authenticated users can view hardwares"
  on public.hardwares for select
  using (auth.uid() is not null);

create policy "Authenticated users can create hardwares"
  on public.hardwares for insert
  with check (auth.uid() is not null and created_by = auth.uid());

create policy "Members can update their hardwares"
  on public.hardwares for update
  using (public.is_hardware_member(id));

create policy "Creator or admin can delete hardware"
  on public.hardwares for delete
  using (created_by = auth.uid() or public.is_admin());

-- ─── hardware_members ────────────────────────────────────────────────────────
create policy "Members can view workspace membership"
  on public.hardware_members for select
  using (public.is_hardware_member(hardware_id));

create policy "Admin members can manage workspace membership"
  on public.hardware_members for all
  using (
    exists (
      select 1 from public.hardware_members hm
      where hm.hardware_id = hardware_members.hardware_id
        and hm.user_id = auth.uid()
        and lower(hm.role) = 'admin'
    )
  );

create policy "Users can join when invited (insert own record)"
  on public.hardware_members for insert
  with check (user_id = auth.uid());

-- ─── hardware_invites ────────────────────────────────────────────────────────
create policy "Members can view invites"
  on public.hardware_invites for select
  using (public.is_hardware_member(hardware_id));

create policy "Admin members can manage invites"
  on public.hardware_invites for all
  using (
    exists (
      select 1 from public.hardware_members hm
      where hm.hardware_id = hardware_invites.hardware_id
        and hm.user_id = auth.uid()
        and lower(hm.role) = 'admin'
    )
  );

-- ─── products ────────────────────────────────────────────────────────────────
create policy "Hardware members can view products"
  on public.products for select
  using (public.is_hardware_member(hardware_id));

create policy "Approved members can add products"
  on public.products for insert
  with check (public.is_approved() and public.is_hardware_member(hardware_id));

create policy "Approved members can update products"
  on public.products for update
  using (public.is_approved() and public.is_hardware_member(hardware_id));

create policy "Admin or manager can delete products"
  on public.products for delete
  using (
    public.is_hardware_member(hardware_id)
    and (public.is_admin() or public.get_my_role() = 'manager')
  );

-- ─── transactions ─────────────────────────────────────────────────────────────
create policy "Hardware members can view transactions"
  on public.transactions for select
  using (public.is_hardware_member(hardware_id));

create policy "Approved members can create transactions"
  on public.transactions for insert
  with check (
    public.is_approved()
    and public.is_hardware_member(hardware_id)
    and (created_by = auth.uid() or created_by is null)
  );

create policy "Only admins can update transactions"
  on public.transactions for update
  using (public.is_admin() and public.is_hardware_member(hardware_id));

create policy "Only admins can delete transactions"
  on public.transactions for delete
  using (public.is_admin() and public.is_hardware_member(hardware_id));

-- ─── transaction_items ───────────────────────────────────────────────────────
create policy "Hardware members can view transaction items"
  on public.transaction_items for select
  using (public.is_hardware_member(hardware_id));

create policy "Approved members can create transaction items"
  on public.transaction_items for insert
  with check (public.is_approved() and public.is_hardware_member(hardware_id));

create policy "Only admins can update or delete transaction items"
  on public.transaction_items for update
  using (public.is_admin() and public.is_hardware_member(hardware_id));

create policy "Only admins can delete transaction items"
  on public.transaction_items for delete
  using (public.is_admin() and public.is_hardware_member(hardware_id));

-- =============================================================================
-- 9. AUTO-CREATE USER PROFILE ON SIGN-UP
-- Trigger fires after a new user is created in auth.users
-- =============================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, full_name, email, role, created_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.email, ''),
    null,   -- pending approval by default
    now()
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =============================================================================
-- 10. USEFUL VIEWS
-- =============================================================================

-- Transactions with creator name (mirrors the Firestore join in TransactionService)
create or replace view public.transactions_with_user as
  select
    t.*,
    u.full_name as created_by_name
  from public.transactions t
  left join public.users u on u.id = t.created_by;

-- Products with hardware name (useful for admin overviews)
create or replace view public.products_with_hardware as
  select
    p.*,
    h.name as hardware_name
  from public.products p
  join public.hardwares h on h.id = p.hardware_id;

-- =============================================================================
-- 11. DEMO ACCOUNTS & SAMPLE WORKSPACE SEED
-- Pre-creates confirmed demo accounts:
--   • Admin: demo-admin@stokado.app  /  DemoAdmin123!
--   • Staff: demo-staff@stokado.app  /  DemoStaff123!
-- Pre-creates 'Demo Hardware Store' workspace with sample inventory & prices.
-- =============================================================================
create extension if not exists "pgcrypto";

DO $$
DECLARE
  v_admin_id uuid := 'd0000000-0000-0000-0000-000000000001';
  v_staff_id uuid := 'd0000000-0000-0000-0000-000000000002';
  v_hw_id    uuid := 'd0000000-0000-0000-0000-000000000010';
BEGIN
  -- ─── 1. Demo Admin in auth.users & auth.identities ───────────────────────────
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'demo-admin@stokado.app') THEN
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_admin_id,
      'authenticated',
      'authenticated',
      'demo-admin@stokado.app',
      crypt('DemoAdmin123!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Demo Admin"}'::jsonb,
      now(), now(), '', ''
    );

    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
      v_admin_id,
      v_admin_id,
      json_build_object('sub', v_admin_id::text, 'email', 'demo-admin@stokado.app')::jsonb,
      'email',
      v_admin_id::text,
      now(), now(), now()
    ) ON CONFLICT DO NOTHING;
  ELSE
    SELECT id INTO v_admin_id FROM auth.users WHERE email = 'demo-admin@stokado.app' LIMIT 1;
    UPDATE auth.users SET
      encrypted_password = crypt('DemoAdmin123!', gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now())
    WHERE id = v_admin_id;
  END IF;

  -- ─── 2. Demo Staff in auth.users & auth.identities ───────────────────────────
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'demo-staff@stokado.app') THEN
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_staff_id,
      'authenticated',
      'authenticated',
      'demo-staff@stokado.app',
      crypt('DemoStaff123!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Demo Staff"}'::jsonb,
      now(), now(), '', ''
    );

    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
      v_staff_id,
      v_staff_id,
      json_build_object('sub', v_staff_id::text, 'email', 'demo-staff@stokado.app')::jsonb,
      'email',
      v_staff_id::text,
      now(), now(), now()
    ) ON CONFLICT DO NOTHING;
  ELSE
    SELECT id INTO v_staff_id FROM auth.users WHERE email = 'demo-staff@stokado.app' LIMIT 1;
    UPDATE auth.users SET
      encrypted_password = crypt('DemoStaff123!', gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now())
    WHERE id = v_staff_id;
  END IF;

  -- ─── 3. Ensure public.users profile records ──────────────────────────────────
  INSERT INTO public.users (id, full_name, email, role, is_demo, created_at)
  VALUES (v_admin_id, 'Demo Admin', 'demo-admin@stokado.app', 'admin', true, now())
  ON CONFLICT (id) DO UPDATE SET role = 'admin', is_demo = true, full_name = 'Demo Admin';

  INSERT INTO public.users (id, full_name, email, role, is_demo, created_at)
  VALUES (v_staff_id, 'Demo Staff', 'demo-staff@stokado.app', 'staff', true, now())
  ON CONFLICT (id) DO UPDATE SET role = 'staff', is_demo = true, full_name = 'Demo Staff';

  -- ─── 4. Demo Hardware Store Workspace ───────────────────────────────────────
  INSERT INTO public.hardwares (id, name, description, created_by, created_at)
  VALUES (v_hw_id, 'Demo Hardware Store', 'Sample workspace for testing features and demo mode', v_admin_id, now())
  ON CONFLICT (id) DO NOTHING;

  -- ─── 5. Add Members to Demo Hardware Store ───────────────────────────────────
  INSERT INTO public.hardware_members (
    hardware_id, user_id, role,
    can_add_products, can_edit_products, can_remove_products,
    can_add_transactions, can_cancel_transactions
  ) VALUES (
    v_hw_id, v_admin_id, 'admin',
    true, true, true, true, true
  ) ON CONFLICT (hardware_id, user_id) DO NOTHING;

  INSERT INTO public.hardware_members (
    hardware_id, user_id, role,
    can_add_products, can_edit_products, can_remove_products,
    can_add_transactions, can_cancel_transactions
  ) VALUES (
    v_hw_id, v_staff_id, 'staff',
    true, true, false, true, false
  ) ON CONFLICT (hardware_id, user_id) DO NOTHING;

  -- ─── 6. Sample Inventory Products with Prices ─────────────────────────────────
  INSERT INTO public.products (hardware_id, product_name, category_name, quantity, unit, price, cost_price, is_active, remarks)
  VALUES
    (v_hw_id, 'Portland Cement 40kg', 'Masonry', 150, 'bag', 280.00, 240.00, true, 'Standard Portland Type 1'),
    (v_hw_id, 'Deformed Steel Rebar 12mm x 6m', 'Steel', 85, 'pcs', 320.00, 280.00, true, 'Grade 40 structural rebar'),
    (v_hw_id, 'Ordinary Plywood 1/2 x 4 x 8', 'Lumber', 45, 'pcs', 650.00, 580.00, true, 'Smooth face finish'),
    (v_hw_id, 'PVC Pipe Blue 1/2" x 10ft', 'Plumbing', 120, 'pcs', 95.00, 75.00, true, 'Schedule 40 potable water pipe'),
    (v_hw_id, 'Gloss Latex White Paint 4L', 'Paints', 30, 'bag', 540.00, 480.00, true, 'Quick-dry premium paint')
  ON CONFLICT DO NOTHING;

END $$;

-- =============================================================================
-- STORAGE BUCKET: product-images (for product photo uploads)
-- =============================================================================
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

-- Drop existing policies if re-running
drop policy if exists "Public Access for product images" on storage.objects;
drop policy if exists "Authenticated users can upload product images" on storage.objects;
drop policy if exists "Authenticated users can update product images" on storage.objects;
drop policy if exists "Authenticated users can delete product images" on storage.objects;

-- Public can view product images
create policy "Public Access for product images"
  on storage.objects for select
  using ( bucket_id = 'product-images' );

-- Authenticated users can upload product images
create policy "Authenticated users can upload product images"
  on storage.objects for insert
  to authenticated
  with check ( bucket_id = 'product-images' );

-- Authenticated users can update/replace product images
create policy "Authenticated users can update product images"
  on storage.objects for update
  to authenticated
  using ( bucket_id = 'product-images' );

-- Authenticated users can delete product images
create policy "Authenticated users can delete product images"
  on storage.objects for delete
  to authenticated
  using ( bucket_id = 'product-images' );

-- =============================================================================
-- IF YOU ALREADY RAN THIS MIGRATION BEFORE (database already initialized):
-- Run these statements in Supabase SQL Editor:
--
-- 1. Ensure column exists on products table:
--    alter table public.products add column if not exists image_url text default null;
--
-- 2. Create the storage bucket & policies:
--    insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true) on conflict (id) do update set public = true;
--    create policy "Public Access for product images" on storage.objects for select using ( bucket_id = 'product-images' );
--    create policy "Authenticated users can upload product images" on storage.objects for insert to authenticated with check ( bucket_id = 'product-images' );
--
-- =============================================================================
-- ✅ MIGRATION COMPLETE
-- Tables created:
--   public.users
--   public.hardwares
--   public.hardware_members
--   public.hardware_invites
--   public.products            ← includes price, cost_price & image_url columns
--   public.transactions        ← includes total_price column
--   public.transaction_items   ← includes price & line_total columns
-- Storage:
--   storage.buckets            ← product-images (public bucket)
-- Pre-seeded:
--   Demo Admin (demo-admin@stokado.app / DemoAdmin123!)
--   Demo Staff (demo-staff@stokado.app / DemoStaff123!)
--   Demo Hardware Store (with 5 sample inventory products & prices)
-- =============================================================================

