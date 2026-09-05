-- 0002 Kerne: brands, kontakter, aftaler, stagehistorik og aktiviteter

create table public.brands (
  id                 uuid primary key default gen_random_uuid(),
  navn               text not null,
  cvr                text,
  branche            text,
  kategori           text,
  website            text,
  status             text not null default 'nyt_lead',
  ejer_id            uuid references public.app_users(id) on delete set null,
  lead_score         int not null default 0 check (lead_score between 0 and 100),
  sidste_kontakt_at  timestamptz,
  economic_kunde_nr  text,
  noter              text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index brands_navn_idx on public.brands (lower(navn));
create index brands_status_idx on public.brands (status);
create index brands_sidste_kontakt_idx on public.brands (sidste_kontakt_at desc nulls last);

comment on column public.brands.kategori is
  'Bruges til eksklusivitetstjek, fx byggemarked, maling, vaerktoej.';
comment on column public.brands.economic_kunde_nr is
  'Kundenummer i e-conomic. Bindeleddet til fakturering.';

create table public.contacts (
  id           uuid primary key default gen_random_uuid(),
  brand_id     uuid not null references public.brands(id) on delete cascade,
  navn         text not null,
  rolle        text,
  email        text,
  telefon      text,
  primaer      boolean not null default false,
  samtykke_at  timestamptz,
  kilde        text,
  noter        text,
  aktiv        boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index contacts_brand_idx on public.contacts (brand_id);
create unique index contacts_email_uniq on public.contacts (lower(email)) where email is not null;

comment on column public.contacts.samtykke_at is
  'Tidspunkt for samtykke til markedsfoeringsmails. Tom betyder kun svar paa egen henvendelse.';

create table public.deals (
  id                  uuid primary key default gen_random_uuid(),
  brand_id            uuid not null references public.brands(id) on delete restrict,
  titel               text not null,
  beskrivelse         text,
  vaerdi_kr           numeric(12,2) not null default 0,
  stage               public.deal_stage not null default 'lead',
  sandsynlighed       int not null default 10 check (sandsynlighed between 0 and 100),
  vejet_vaerdi_kr     numeric(12,2) generated always as
                        (round(vaerdi_kr * sandsynlighed / 100.0, 2)) stored,
  forventet_luk       date,
  ejer_id             uuid references public.app_users(id) on delete set null,
  primaer_kontakt_id  uuid references public.contacts(id) on delete set null,
  kilde               text,
  tabt_aarsag         text,
  automatik_pause     boolean not null default false,
  lukket_at           timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index deals_brand_idx on public.deals (brand_id);
create index deals_stage_idx on public.deals (stage);
create index deals_forventet_luk_idx on public.deals (forventet_luk) where lukket_at is null;

comment on column public.deals.automatik_pause is
  'Slaar al automatik fra paa denne aftale, naar dialogen kraever haandholdt tone.';

create table public.deal_stage_history (
  id          bigserial primary key,
  deal_id     uuid not null references public.deals(id) on delete cascade,
  fra_stage   public.deal_stage,
  til_stage   public.deal_stage not null,
  aendret_af  uuid references public.app_users(id) on delete set null,
  automatisk  boolean not null default false,
  aarsag      text,
  created_at  timestamptz not null default now()
);
create index deal_stage_history_deal_idx on public.deal_stage_history (deal_id, created_at);

comment on table public.deal_stage_history is
  'Append-only. Eneste kilde til konverteringsrater og liggetid pr. stage.';

create table public.activities (
  id          bigserial primary key,
  deal_id     uuid references public.deals(id) on delete cascade,
  brand_id    uuid references public.brands(id) on delete cascade,
  contact_id  uuid references public.contacts(id) on delete set null,
  type        public.activity_type not null,
  titel       text not null,
  body        text,
  automatisk  boolean not null default false,
  ekstern_id  text,
  bruger_id   uuid references public.app_users(id) on delete set null,
  sket_at     timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  constraint activities_har_anker check (deal_id is not null or brand_id is not null)
);
create index activities_deal_idx on public.activities (deal_id, sket_at desc);
create index activities_brand_idx on public.activities (brand_id, sket_at desc);

-- ---------------------------------------------------------------- triggere

create trigger brands_updated_at before update on public.brands
  for each row execute function public.set_updated_at();
create trigger contacts_updated_at before update on public.contacts
  for each row execute function public.set_updated_at();
create trigger deals_updated_at before update on public.deals
  for each row execute function public.set_updated_at();

-- Saetter lukketidspunkt naar en aftale forlader det aabne
create or replace function public.saet_lukket_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.stage in ('vundet', 'leveret', 'tabt') and new.lukket_at is null then
    new.lukket_at := now();
  elsif new.stage not in ('vundet', 'leveret', 'tabt') then
    new.lukket_at := null;
  end if;
  return new;
end;
$$;

create trigger deals_saet_lukket_at
  before insert or update of stage on public.deals
  for each row execute function public.saet_lukket_at();

-- Skriver hvert stageskift til historikken
create or replace function public.log_stage_skift()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.deal_stage_history (deal_id, fra_stage, til_stage, aendret_af)
    values (new.id, null, new.stage, auth.uid());
  elsif new.stage is distinct from old.stage then
    insert into public.deal_stage_history (deal_id, fra_stage, til_stage, aendret_af)
    values (new.id, old.stage, new.stage, auth.uid());

    insert into public.activities (deal_id, brand_id, type, titel, bruger_id)
    values (new.id, new.brand_id, 'stage_skift',
            'Flyttet fra ' || old.stage::text || ' til ' || new.stage::text, auth.uid());
  end if;
  return null;
end;
$$;

create trigger deals_log_stage_skift
  after insert or update of stage on public.deals
  for each row execute function public.log_stage_skift();

-- Holder brandets sidste kontakt opdateret ud fra aktiviteterne
create or replace function public.opdater_sidste_kontakt()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_brand uuid;
begin
  if new.type not in ('mail_ind', 'mail_ud', 'opkald', 'moede') then
    return null;
  end if;

  v_brand := new.brand_id;
  if v_brand is null and new.deal_id is not null then
    select brand_id into v_brand from public.deals where id = new.deal_id;
  end if;

  if v_brand is not null then
    update public.brands
       set sidste_kontakt_at = greatest(coalesce(sidste_kontakt_at, new.sket_at), new.sket_at)
     where id = v_brand;
  end if;
  return null;
end;
$$;

create trigger activities_opdater_sidste_kontakt
  after insert on public.activities
  for each row execute function public.opdater_sidste_kontakt();
