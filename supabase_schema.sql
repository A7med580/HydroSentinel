-- 1. Enable UUID extension
create extension if not exists "pgcrypto";

-- 2. Create FACTORIES Table
create table if not exists factories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  drive_folder_id text unique not null,
  last_sync_at timestamptz,
  status text check (status in ('good', 'warning', 'critical')),
  created_at timestamptz default now()
);

-- 3. Create REPORTS Table
create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  factory_id uuid references factories(id) on delete cascade not null,
  file_id text not null, -- Google Drive File ID
  file_name text not null,
  analyzed_at timestamptz default now(),
  risk_scaling numeric,
  risk_corrosion numeric,
  risk_fouling numeric,
  data jsonb not null -- Full analysis result
);

-- 4. Enable Row Level Security (RLS)
alter table factories enable row level security;
alter table reports enable row level security;

-- 5. Create Policies
-- Allow authenticated users to view/create/update factories
create policy "Enable read access for authenticated users" on factories
  for select using (auth.role() = 'authenticated');

create policy "Enable insert for authenticated users" on factories
  for insert with check (auth.role() = 'authenticated');

create policy "Enable update for authenticated users" on factories
  for update using (auth.role() = 'authenticated');

-- Allow authenticated users to view/create reports
create policy "Enable read access for reports" on reports
  for select using (auth.role() = 'authenticated');

create policy "Enable insert for reports" on reports
  for insert with check (auth.role() = 'authenticated');
