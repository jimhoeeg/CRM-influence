-- 0001 Fundament: typer, brugere, roller og adgangsfunktioner
-- Byggeligt CRM

-- ---------------------------------------------------------------- typer

create type public.app_role as enum ('owner', 'editor', 'produktion');

create type public.deal_stage as enum
  ('lead', 'kontaktet', 'tilbud', 'forhandling', 'vundet', 'leveret', 'tabt');

create type public.deliverable_status as enum
  ('ikke_startet', 'i_gang', 'til_godkendelse', 'godkendt', 'leveret', 'aflyst');

create type public.activity_type as enum
  ('mail_ind', 'mail_ud', 'opkald', 'moede', 'note', 'automatik', 'stage_skift', 'fil');

create type public.invoice_status as enum
  ('udkast', 'sendt', 'betalt', 'forfalden', 'krediteret');

create type public.platform as enum
  ('instagram', 'tiktok', 'youtube', 'facebook', 'blog', 'andet');

create type public.metric_source as enum
  ('manuel', 'instagram_graph', 'tiktok_api', 'youtube_api', 'brand_rapport');

create type public.email_direction as enum ('ind', 'ud');

create type public.automation_mode as enum ('slaaet_fra', 'toerkoersel', 'aktiv');

-- ---------------------------------------------------------------- hjælpere

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- brugere

-- Brugere administreres i appen, ikke i miljøvariabler. En person får adgang
-- ved at blive inviteret her; første login kobler auth-brugeren på rækken.
create table public.app_users (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  navn        text not null default '',
  rolle       public.app_role not null default 'produktion',
  aktiv       boolean not null default false,
  telefon     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index app_users_email_uniq on public.app_users (lower(email));

comment on table public.app_users is
  'Brugere med adgang til CRM et. aktiv=false betyder oprettet men uden adgang.';
comment on column public.app_users.rolle is
  'owner = alt inkl. brugeradministration. editor = alt fagligt inkl. oekonomi. produktion = leverancer og kalender, ingen oekonomi.';

create table public.invitations (
  id            uuid primary key default gen_random_uuid(),
  email         text not null,
  navn          text not null default '',
  rolle         public.app_role not null default 'produktion',
  inviteret_af  uuid references public.app_users(id) on delete set null,
  brugt_at      timestamptz,
  created_at    timestamptz not null default now()
);
create unique index invitations_email_uniq on public.invitations (lower(email));

create trigger app_users_updated_at
  before update on public.app_users
  for each row execute function public.set_updated_at();

-- Kobler et nyt auth-login sammen med en invitation. Uden invitation bliver
-- brugeren oprettet inaktiv og kan intet se.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  inv public.invitations%rowtype;
begin
  select * into inv
  from public.invitations
  where lower(email) = lower(new.email)
    and brugt_at is null
  limit 1;

  insert into public.app_users (id, email, navn, rolle, aktiv)
  values (
    new.id,
    new.email,
    coalesce(nullif(inv.navn, ''), split_part(new.email, '@', 1)),
    coalesce(inv.rolle, 'produktion'::public.app_role),
    inv.id is not null
  )
  on conflict (id) do nothing;

  if inv.id is not null then
    update public.invitations set brugt_at = now() where id = inv.id;
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- adgang

create or replace function public.er_aktiv()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.app_users u
    where u.id = auth.uid() and u.aktiv
  );
$$;

create or replace function public.har_rolle(roller public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.app_users u
    where u.id = auth.uid() and u.aktiv and u.rolle = any(roller)
  );
$$;

-- Hvem må se oekonomi: fakturaer, priser, daekningsbidrag.
create or replace function public.ser_oekonomi()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.har_rolle(array['owner', 'editor']::public.app_role[]);
$$;

create or replace function public.kan_redigere()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.har_rolle(array['owner', 'editor']::public.app_role[]);
$$;

create or replace function public.er_owner()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.har_rolle(array['owner']::public.app_role[]);
$$;

-- Ingen kan give sig selv en hoejere rolle eller aktivere sig selv.
create or replace function public.beskyt_rolle()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.er_owner() then
    return new;
  end if;
  if new.rolle is distinct from old.rolle or new.aktiv is distinct from old.aktiv then
    raise exception 'Kun en owner kan aendre rolle eller adgang';
  end if;
  return new;
end;
$$;

create trigger app_users_beskyt_rolle
  before update on public.app_users
  for each row execute function public.beskyt_rolle();

-- Inviter en kollega. Kaldes fra appen af en owner.
create or replace function public.inviter_bruger(
  p_email text,
  p_navn  text default '',
  p_rolle public.app_role default 'produktion'
)
returns public.invitations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  rec public.invitations;
begin
  if not public.er_owner() then
    raise exception 'Kun en owner kan invitere brugere';
  end if;

  insert into public.invitations (email, navn, rolle, inviteret_af)
  values (lower(p_email), p_navn, p_rolle, auth.uid())
  on conflict (lower(email)) do update
    set navn = excluded.navn,
        rolle = excluded.rolle,
        brugt_at = null
  returning * into rec;

  -- Har personen allerede logget ind, får de adgangen med det samme.
  update public.app_users
     set rolle = p_rolle, aktiv = true, navn = coalesce(nullif(p_navn, ''), navn)
   where lower(email) = lower(p_email);

  return rec;
end;
$$;

-- Fjern adgang uden at slette historikken bag personen.
create or replace function public.deaktiver_bruger(p_email text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.er_owner() then
    raise exception 'Kun en owner kan fjerne adgang';
  end if;
  update public.app_users set aktiv = false where lower(email) = lower(p_email);
  update public.invitations set brugt_at = now() where lower(email) = lower(p_email);
end;
$$;
