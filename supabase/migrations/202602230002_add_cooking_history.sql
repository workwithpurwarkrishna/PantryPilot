create table if not exists public.cooking_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  dish_name text not null,
  source_query text,
  people_count int check (people_count >= 1),
  extra_budget_inr text,
  max_time_minutes int check (max_time_minutes >= 1),
  recipe_snapshot jsonb,
  dish_card_snapshot jsonb,
  cooked_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cooking_followups (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.cooking_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  question text not null,
  answer text not null,
  created_at timestamptz not null default now()
);

create index if not exists cooking_sessions_user_id_cooked_at_idx
on public.cooking_sessions(user_id, cooked_at desc);

create index if not exists cooking_followups_session_id_created_at_idx
on public.cooking_followups(session_id, created_at asc);

alter table public.cooking_sessions enable row level security;
alter table public.cooking_followups enable row level security;

create policy "cooking_sessions_owned_by_user"
on public.cooking_sessions
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "cooking_followups_owned_by_user"
on public.cooking_followups
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop trigger if exists cooking_sessions_touch_updated_at on public.cooking_sessions;
create trigger cooking_sessions_touch_updated_at
before update on public.cooking_sessions
for each row execute function public.touch_updated_at();
