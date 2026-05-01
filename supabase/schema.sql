-- RennAuktion + RennMarkt shared Supabase schema
-- Run this once in: Supabase Dashboard → SQL Editor → New Query → Run
-- Project: kulgecvykrhfalvvyeru

-- ── User profiles (extends Supabase auth.users) ──────────────────────────────
create table if not exists public.profiles (
  id          uuid references auth.users(id) on delete cascade primary key,
  email       text,
  display_name text,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- ── Saved auctions (RennAuktion) ─────────────────────────────────────────────
create table if not exists public.saved_auctions (
  id          bigserial primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  listing_id  text not null,           -- matches listing URL or DB id
  source      text,                    -- 'bat' | 'cnb' | 'pcarmarket'
  title       text,                    -- "2019 Porsche 911 GT3"
  listing_url text,
  image_url   text,
  saved_at    timestamptz default now(),
  unique(user_id, listing_id)
);

-- ── Saved listings (RennMarkt inventory) ─────────────────────────────────────
create table if not exists public.saved_listings (
  id          bigserial primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  listing_id  text not null,
  source      text,
  title       text,
  listing_url text,
  image_url   text,
  saved_at    timestamptz default now(),
  unique(user_id, listing_id)
);

-- ── Alert preferences ─────────────────────────────────────────────────────────
create table if not exists public.alert_prefs (
  id          bigserial primary key,
  user_id     uuid references auth.users(id) on delete cascade not null unique,
  push_enabled     boolean default false,
  email_enabled    boolean default false,
  tier1_only       boolean default false,   -- GT/collector only
  min_year         int,
  max_price        int,
  keywords         text[],                  -- e.g. ['GT3', 'Touring', 'manual']
  updated_at  timestamptz default now()
);

-- ── Row Level Security ────────────────────────────────────────────────────────
alter table public.profiles        enable row level security;
alter table public.saved_auctions  enable row level security;
alter table public.saved_listings  enable row level security;
alter table public.alert_prefs     enable row level security;

-- profiles: user sees/edits only their own
create policy "profiles_select" on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- saved_auctions: user sees/edits only their own
create policy "saved_auctions_select" on public.saved_auctions for select using (auth.uid() = user_id);
create policy "saved_auctions_insert" on public.saved_auctions for insert with check (auth.uid() = user_id);
create policy "saved_auctions_delete" on public.saved_auctions for delete using (auth.uid() = user_id);

-- saved_listings: user sees/edits only their own
create policy "saved_listings_select" on public.saved_listings for select using (auth.uid() = user_id);
create policy "saved_listings_insert" on public.saved_listings for insert with check (auth.uid() = user_id);
create policy "saved_listings_delete" on public.saved_listings for delete using (auth.uid() = user_id);

-- alert_prefs: user sees/edits only their own
create policy "alert_prefs_select" on public.alert_prefs for select using (auth.uid() = user_id);
create policy "alert_prefs_upsert" on public.alert_prefs for insert with check (auth.uid() = user_id);
create policy "alert_prefs_update" on public.alert_prefs for update using (auth.uid() = user_id);

-- ── Auto-create profile on signup ─────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
