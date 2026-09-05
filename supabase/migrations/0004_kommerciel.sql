-- 0004 Kommerciel: prisliste, fakturaer, kanaler og kampagnetal

create table public.rate_card (
  id                uuid primary key default gen_random_uuid(),
  platform          public.platform not null,
  format            text not null,
  beskrivelse       text,
  listepris_kr      numeric(12,2) not null,
  minimumspris_kr   numeric(12,2),
  gaelder_fra       date not null default current_date,
  gaelder_til       date,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint rate_card_periode check (gaelder_til is null or gaelder_til >= gaelder_fra),
  constraint rate_card_minimum check (minimumspris_kr is null or minimumspris_kr <= listepris_kr)
);
create index rate_card_opslag_idx on public.rate_card (platform, format, gaelder_fra desc);

comment on table public.rate_card is
  'Gaeldende priser pr. format. Historikken bevares ved at saette gaelder_til i stedet for at rette prisen.';

create table public.invoices (
  id                uuid primary key default gen_random_uuid(),
  deal_id           uuid not null references public.deals(id) on delete restrict,
  fakturanummer     text,
  beloeb_kr         numeric(12,2) not null,
  moms_kr           numeric(12,2) not null default 0,
  status            public.invoice_status not null default 'udkast',
  faktura_dato      date,
  forfald_dato      date,
  betalt_at         timestamptz,
  eksternt_system   text not null default 'economic',
  eksternt_id       text,
  ekstern_kunde_nr  text,
  ekstern_url       text,
  sidst_synket_at   timestamptz,
  noter             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index invoices_deal_idx on public.invoices (deal_id);
create index invoices_status_idx on public.invoices (status, forfald_dato);
create unique index invoices_eksternt_id_uniq
  on public.invoices (eksternt_system, eksternt_id) where eksternt_id is not null;

comment on column public.invoices.eksternt_id is
  'e-conomic draftInvoiceNumber eller bookedInvoiceNumber. Vi opretter kladden, e-conomic ejer bogfoeringen.';

-- Vores egne kanaler. Adgangstokens ligger i Vault, aldrig i denne tabel.
create table public.social_accounts (
  id                   uuid primary key default gen_random_uuid(),
  platform             public.platform not null,
  handle               text not null,
  ekstern_id           text,
  token_reference      text,
  adgang_udloeber_at   timestamptz,
  sidst_synket_at      timestamptz,
  aktiv                boolean not null default true,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (platform, handle)
);

comment on column public.social_accounts.token_reference is
  'Navn paa hemmeligheden i Supabase Vault. Selve tokenet ligger aldrig i en almindelig tabel.';
comment on column public.social_accounts.adgang_udloeber_at is
  'Instagram og TikTok tokens udloeber. Varsles 14 dage foer, ellers stopper taldata i stilhed.';

-- Kampagnetal som oejebliksbilleder, ikke som et enkelt tal der overskrives.
-- Sammenligning over tid kraever historik, og et opslag vokser i ugevis.
create table public.campaign_metrics (
  id                    bigserial primary key,
  deliverable_id        uuid not null references public.deliverables(id) on delete cascade,
  maalt_at              timestamptz not null default now(),
  kilde                 public.metric_source not null default 'manuel',
  visninger             bigint,
  raekkevidde           bigint,
  engagement            bigint,
  klik                  bigint,
  gemt                  bigint,
  delinger              bigint,
  visningstid_sek       numeric(10,2),
  gennemfoerselsrate    numeric(5,2),
  raa_svar              jsonb,
  indtastet_af          uuid references public.app_users(id) on delete set null,
  created_at            timestamptz not null default now(),
  unique (deliverable_id, maalt_at, kilde)
);
create index campaign_metrics_deliverable_idx
  on public.campaign_metrics (deliverable_id, maalt_at desc);

comment on table public.campaign_metrics is
  'Et maalepunkt pr. leverance pr. kilde. Automatisk hentning og manuel indtastning lever side om side, saa et tal altid kan spores til sin kilde.';

create trigger rate_card_updated_at before update on public.rate_card
  for each row execute function public.set_updated_at();
create trigger invoices_updated_at before update on public.invoices
  for each row execute function public.set_updated_at();
create trigger social_accounts_updated_at before update on public.social_accounts
  for each row execute function public.set_updated_at();

-- Hvad tog vi sidst for dette format? Vaernet mod at underprise.
create or replace function public.pris_historik(p_platform public.platform, p_format text)
returns table (
  brand        text,
  deal_titel   text,
  vaerdi_kr    numeric,
  antal        int,
  pris_pr_stk  numeric,
  lukket       timestamptz
)
language sql
stable
set search_path = public, pg_temp
as $$
  select b.navn,
         d.titel,
         d.vaerdi_kr,
         dl.antal,
         round(d.vaerdi_kr / nullif(dl.antal, 0), 2),
         d.lukket_at
  from public.deliverables dl
  join public.deals d on d.id = dl.deal_id
  join public.brands b on b.id = d.brand_id
  where dl.platform = p_platform
    and dl.format = p_format
    and d.stage in ('vundet', 'leveret')
  order by d.lukket_at desc nulls last
  limit 20;
$$;
