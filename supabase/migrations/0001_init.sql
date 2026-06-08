-- QuietStay — initial schema (multi-tenant digital guidebook platform)
-- Working name: QuietStay. Org: offer2stay.
-- Run as a single migration. Postgres 17 + PostGIS for proximity-based recommendations.

-- ============================================================
-- Extensions
-- ============================================================
create extension if not exists "pgcrypto";
create extension if not exists postgis;

-- ============================================================
-- Enums
-- ============================================================
create type public.org_role          as enum ('owner','manager','service_admin');
create type public.guidebook_status  as enum ('draft','published','archived');
create type public.rec_category       as enum ('restaurant','cafe','pub','attraction','beach','shop','transport','activity','essential','other');
create type public.service_stage      as enum ('intake','area_research','data_entry','awaiting_owner_input','review','published');
create type public.ingestion_status   as enum ('pending','parsing','parsed','failed');
create type public.print_status       as enum ('requested','designing','approved','printing','shipped','delivered','cancelled');
create type public.sub_status         as enum ('trialing','active','past_due','canceled');

-- ============================================================
-- Profiles (mirror of auth.users) + service-team flag
-- ============================================================
create table public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  full_name       text,
  is_service_team boolean not null default false,   -- our internal team can see across orgs
  created_at      timestamptz not null default now()
);

-- ============================================================
-- Organizations (a host account / management company) + membership
-- ============================================================
create table public.organizations (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

create table public.memberships (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       public.org_role not null default 'owner',
  created_at timestamptz not null default now(),
  unique (org_id, user_id)
);

-- ============================================================
-- Locations (reusable area libraries) + geo-tagged recommendations
-- ============================================================
create table public.locations (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,                       -- "Newcastle city centre", "Bamburgh & coast"
  region     text,                                -- "Tyne and Wear", "Northumberland"
  country    text not null default 'United Kingdom',
  geo        geography(Point,4326),
  created_at timestamptz not null default now()
);

create table public.recommendations (
  id          uuid primary key default gen_random_uuid(),
  location_id uuid references public.locations(id) on delete set null,
  category    public.rec_category not null default 'other',
  name        text not null,
  description text,
  address     text,
  url         text,
  geo         geography(Point,4326),              -- proximity: surface what's near a property
  curated     boolean not null default true,      -- our editorial pick
  created_at  timestamptz not null default now()
);
create index recommendations_geo_idx on public.recommendations using gist (geo);

-- ============================================================
-- Properties
-- ============================================================
create table public.properties (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  location_id uuid references public.locations(id) on delete set null,
  name        text not null,
  address     text,
  geo         geography(Point,4326),
  listing_url text,                                -- airbnb/booking/vrbo link for ingestion
  created_at  timestamptz not null default now()
);
create index properties_geo_idx on public.properties using gist (geo);
create index properties_org_idx on public.properties (org_id);

-- ============================================================
-- Guidebooks → sections → items
-- ============================================================
create table public.guidebooks (
  id          uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  org_id      uuid not null references public.organizations(id) on delete cascade,
  title       text not null default 'Welcome',
  slug        text unique,                         -- unguessable public share URL
  status      public.guidebook_status not null default 'draft',
  theme       jsonb not null default '{}'::jsonb,  -- branding: logo, colours, cover photo
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index guidebooks_property_idx on public.guidebooks (property_id);

create table public.sections (
  id           uuid primary key default gen_random_uuid(),
  guidebook_id uuid not null references public.guidebooks(id) on delete cascade,
  title        text not null,
  icon         text,
  position     int not null default 0,
  created_at   timestamptz not null default now()
);
create index sections_guidebook_idx on public.sections (guidebook_id);

create table public.items (
  id            uuid primary key default gen_random_uuid(),
  section_id    uuid not null references public.sections(id) on delete cascade,
  title         text,
  body          text,
  media_url     text,
  owner_supplied boolean not null default false,   -- the host must provide this (drives questionnaire)
  sensitive     boolean not null default false,    -- wifi/lock codes: handle with care in UI
  guest_visible boolean not null default true,     -- false = internal note, never shown to guests
  position      int not null default 0,
  created_at    timestamptz not null default now()
);
create index items_section_idx on public.items (section_id);

-- ============================================================
-- Media
-- ============================================================
create table public.media (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations(id) on delete cascade,
  property_id  uuid references public.properties(id) on delete cascade,
  storage_path text not null,
  kind         text,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- Done-for-you service pipeline
-- ============================================================
create table public.service_jobs (
  id          uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  org_id      uuid not null references public.organizations(id) on delete cascade,
  stage       public.service_stage not null default 'intake',
  assigned_to uuid references public.profiles(id),
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index service_jobs_stage_idx on public.service_jobs (stage);

-- Listing ingestion (auto-parse)
create table public.ingestion_jobs (
  id              uuid primary key default gen_random_uuid(),
  property_id     uuid not null references public.properties(id) on delete cascade,
  source_url      text not null,
  source_platform text,                            -- airbnb / booking / vrbo
  status          public.ingestion_status not null default 'pending',
  raw_payload     jsonb,
  created_at      timestamptz not null default now()
);

-- Host questionnaire responses (owner-supplied fields → auto-import)
create table public.questionnaire_responses (
  id           uuid primary key default gen_random_uuid(),
  property_id  uuid not null references public.properties(id) on delete cascade,
  answers      jsonb not null default '{}'::jsonb,
  submitted_at timestamptz,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- Print orders + subscriptions
-- ============================================================
create table public.print_orders (
  id            uuid primary key default gen_random_uuid(),
  guidebook_id  uuid not null references public.guidebooks(id) on delete cascade,
  org_id        uuid not null references public.organizations(id) on delete cascade,
  status        public.print_status not null default 'requested',
  quantity      int not null default 1,
  fulfilment_ref text,
  created_at    timestamptz not null default now()
);

create table public.subscriptions (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations(id) on delete cascade,
  property_id            uuid references public.properties(id) on delete cascade,
  stripe_customer_id     text,
  stripe_subscription_id text,
  status                 public.sub_status not null default 'trialing',
  free_month_ends_at     timestamptz,              -- the offer2stay first-month-free hook
  current_period_end     timestamptz,
  created_at             timestamptz not null default now()
);

-- ============================================================
-- Helper: is the current user a member of this org (or internal team)?
-- ============================================================
create or replace function public.is_org_member(_org uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
           select 1 from public.memberships m
           where m.org_id = _org and m.user_id = auth.uid()
         )
      or exists (
           select 1 from public.profiles p
           where p.id = auth.uid() and p.is_service_team = true
         );
$$;

-- ============================================================
-- Row-Level Security
-- ============================================================
alter table public.profiles               enable row level security;
alter table public.organizations          enable row level security;
alter table public.memberships            enable row level security;
alter table public.properties             enable row level security;
alter table public.guidebooks             enable row level security;
alter table public.sections               enable row level security;
alter table public.items                  enable row level security;
alter table public.media                  enable row level security;
alter table public.service_jobs           enable row level security;
alter table public.ingestion_jobs         enable row level security;
alter table public.questionnaire_responses enable row level security;
alter table public.print_orders           enable row level security;
alter table public.subscriptions          enable row level security;
alter table public.locations              enable row level security;
alter table public.recommendations        enable row level security;

-- Profiles: a user sees/edits their own profile
create policy profiles_self on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

-- Organizations: members only
create policy orgs_member_read on public.organizations
  for select using (public.is_org_member(id));

-- Memberships: members of the org can read
create policy memberships_member_read on public.memberships
  for select using (public.is_org_member(org_id));

-- Tenant tables keyed by org_id: full access to members
create policy properties_member_all on public.properties
  for all using (public.is_org_member(org_id)) with check (public.is_org_member(org_id));
create policy media_member_all on public.media
  for all using (public.is_org_member(org_id)) with check (public.is_org_member(org_id));
create policy service_jobs_member_all on public.service_jobs
  for all using (public.is_org_member(org_id)) with check (public.is_org_member(org_id));
create policy print_orders_member_all on public.print_orders
  for all using (public.is_org_member(org_id)) with check (public.is_org_member(org_id));
create policy subscriptions_member_all on public.subscriptions
  for all using (public.is_org_member(org_id)) with check (public.is_org_member(org_id));

-- Guidebooks: members manage; anon can read PUBLISHED (guest view via slug)
create policy guidebooks_member_all on public.guidebooks
  for all using (public.is_org_member(org_id)) with check (public.is_org_member(org_id));
create policy guidebooks_public_read on public.guidebooks
  for select to anon using (status = 'published');

-- Sections: member access via guidebook; anon read for published guidebooks
create policy sections_member_all on public.sections
  for all using (exists (
    select 1 from public.guidebooks g
    where g.id = sections.guidebook_id and public.is_org_member(g.org_id)
  ));
create policy sections_public_read on public.sections
  for select to anon using (exists (
    select 1 from public.guidebooks g
    where g.id = sections.guidebook_id and g.status = 'published'
  ));

-- Items: member access via section→guidebook; anon read only guest_visible items of published guidebooks
create policy items_member_all on public.items
  for all using (exists (
    select 1 from public.sections s
    join public.guidebooks g on g.id = s.guidebook_id
    where s.id = items.section_id and public.is_org_member(g.org_id)
  ));
create policy items_public_read on public.items
  for select to anon using (
    guest_visible = true and exists (
      select 1 from public.sections s
      join public.guidebooks g on g.id = s.guidebook_id
      where s.id = items.section_id and g.status = 'published'
    )
  );

-- Ingestion + questionnaire: member access via property
create policy ingestion_member_all on public.ingestion_jobs
  for all using (exists (
    select 1 from public.properties p
    where p.id = ingestion_jobs.property_id and public.is_org_member(p.org_id)
  ));
create policy questionnaire_member_all on public.questionnaire_responses
  for all using (exists (
    select 1 from public.properties p
    where p.id = questionnaire_responses.property_id and public.is_org_member(p.org_id)
  ));

-- Locations + recommendations: shared library. Any authenticated user can read;
-- only internal service team can write.
create policy locations_auth_read on public.locations
  for select to authenticated using (true);
create policy locations_public_read on public.locations
  for select to anon using (true);
create policy locations_team_write on public.locations
  for all to authenticated using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_service_team)
  ) with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_service_team)
  );

create policy recs_auth_read on public.recommendations
  for select to authenticated using (true);
create policy recs_public_read on public.recommendations
  for select to anon using (true);
create policy recs_team_write on public.recommendations
  for all to authenticated using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_service_team)
  ) with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_service_team)
  );

-- ============================================================
-- Auto-create a profile row when a new auth user signs up
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
