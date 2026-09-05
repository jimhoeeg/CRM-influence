-- 0003 Produktion: leverancer, brugsret, kapacitet og eksklusivitet

create table public.deliverables (
  id                      uuid primary key default gen_random_uuid(),
  deal_id                 uuid not null references public.deals(id) on delete cascade,
  titel                   text not null,
  platform                public.platform not null default 'instagram',
  format                  text,
  antal                   int not null default 1 check (antal > 0),
  deadline                date,
  ansvarlig_id            uuid references public.app_users(id) on delete set null,
  status                  public.deliverable_status not null default 'ikke_startet',
  godkendt_af_kontakt_id  uuid references public.contacts(id) on delete set null,
  godkendt_at             timestamptz,
  publiceret_at           timestamptz,
  live_url                text,
  ekstern_kalender_id     text,
  noter                   text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);
create index deliverables_deal_idx on public.deliverables (deal_id);
create index deliverables_deadline_idx on public.deliverables (deadline)
  where status not in ('leveret', 'aflyst');
create index deliverables_ansvarlig_idx on public.deliverables (ansvarlig_id);

comment on column public.deliverables.format is
  'Fx reel, story, yt_integration, blogindlaeg, stills. Matcher rate_card.format.';
comment on column public.deliverables.live_url is
  'Permalink til det publicerede opslag. Noeglen til automatisk hentning af tal.';

create table public.usage_rights (
  id                  uuid primary key default gen_random_uuid(),
  deal_id             uuid not null references public.deals(id) on delete cascade,
  beskrivelse         text not null default '',
  kanaler             text[] not null default '{}',
  geografi            text not null default 'DK',
  betalt_annoncering  boolean not null default false,
  whitelisting        boolean not null default false,
  start_dato          date,
  udloeb_dato         date,
  varsel_sendt_at     timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint usage_rights_periode check (udloeb_dato is null or start_dato is null or udloeb_dato >= start_dato)
);
create index usage_rights_udloeb_idx on public.usage_rights (udloeb_dato)
  where udloeb_dato is not null;

comment on table public.usage_rights is
  'Hvor laenge og hvor brandet maa bruge materialet. Udloeb udloeser varsel og mersalg.';

create table public.capacity_blocks (
  id                   uuid primary key default gen_random_uuid(),
  bruger_id            uuid references public.app_users(id) on delete set null,
  titel                text not null,
  type                 text not null default 'optagelse',
  start_dato           date not null,
  slut_dato            date not null,
  deal_id              uuid references public.deals(id) on delete set null,
  ekstern_kalender_id  text,
  noter                text,
  created_at           timestamptz not null default now(),
  constraint capacity_periode check (slut_dato >= start_dato)
);
create index capacity_blocks_periode_idx on public.capacity_blocks (start_dato, slut_dato);

comment on column public.capacity_blocks.type is
  'optagelse, ferie, redigering eller andet. Svarer paa om vi kan naa det.';

create table public.exclusivity (
  id          uuid primary key default gen_random_uuid(),
  brand_id    uuid not null references public.brands(id) on delete cascade,
  deal_id     uuid references public.deals(id) on delete set null,
  kategori    text not null,
  start_dato  date not null,
  slut_dato   date not null,
  noter       text,
  created_at  timestamptz not null default now(),
  constraint exclusivity_periode check (slut_dato >= start_dato)
);
create index exclusivity_kategori_idx on public.exclusivity (kategori, start_dato, slut_dato);

comment on table public.exclusivity is
  'Karensperioder. Spoerg tjek_eksklusivitet() foer et tilbud sendes til en konkurrent.';

create trigger deliverables_updated_at before update on public.deliverables
  for each row execute function public.set_updated_at();
create trigger usage_rights_updated_at before update on public.usage_rights
  for each row execute function public.set_updated_at();

-- Er der en aftale, der spaerrer for at vi saelger til dette brand netop nu?
create or replace function public.tjek_eksklusivitet(
  p_brand_id uuid,
  p_dato     date default current_date
)
returns table (
  konflikt_brand   text,
  kategori         text,
  gaelder_til      date
)
language sql
stable
set search_path = public, pg_temp
as $$
  select b.navn, e.kategori, e.slut_dato
  from public.exclusivity e
  join public.brands b on b.id = e.brand_id
  where e.brand_id <> p_brand_id
    and p_dato between e.start_dato and e.slut_dato
    and e.kategori = (select kategori from public.brands where id = p_brand_id);
$$;

-- Saetter godkendelsestidspunkt automatisk, saa fakturagrundlaget er entydigt
create or replace function public.saet_godkendt_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status in ('godkendt', 'leveret') and new.godkendt_at is null then
    new.godkendt_at := now();
  end if;
  return new;
end;
$$;

create trigger deliverables_saet_godkendt_at
  before insert or update of status on public.deliverables
  for each row execute function public.saet_godkendt_at();
