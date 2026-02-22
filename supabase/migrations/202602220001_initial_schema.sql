create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text,
  preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ingredients (
  id bigserial primary key,
  name text not null unique,
  category text not null,
  default_unit text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.pantry_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  ingredient_id bigint not null references public.ingredients(id) on delete cascade,
  is_in_stock boolean not null default false,
  quantity text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, ingredient_id)
);

create index if not exists pantry_items_user_id_idx on public.pantry_items(user_id);
create index if not exists pantry_items_ingredient_id_idx on public.pantry_items(ingredient_id);

alter table public.profiles enable row level security;
alter table public.pantry_items enable row level security;
alter table public.ingredients enable row level security;

create policy "ingredients_are_readable_by_authenticated"
on public.ingredients
for select
using (auth.role() = 'authenticated');

create policy "profiles_owned_by_user"
on public.profiles
for all
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "pantry_items_owned_by_user"
on public.pantry_items
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists pantry_items_touch_updated_at on public.pantry_items;
create trigger pantry_items_touch_updated_at
before update on public.pantry_items
for each row execute function public.touch_updated_at();
