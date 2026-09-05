-- 0005 Kommunikation og automatik: mails, opgaver, leadforslag og regelmotor

create table public.email_messages (
  id                uuid primary key default gen_random_uuid(),
  retning           public.email_direction not null,
  gmail_message_id  text,
  gmail_thread_id   text,
  resend_email_id   text,
  fra_email         text,
  fra_navn          text,
  til_email         text[] not null default '{}',
  emne              text,
  uddrag            text,
  brand_id          uuid references public.brands(id) on delete set null,
  deal_id           uuid references public.deals(id) on delete set null,
  contact_id        uuid references public.contacts(id) on delete set null,
  udtraek           jsonb,
  behandlet_at      timestamptz,
  sendt_at          timestamptz not null default now(),
  created_at        timestamptz not null default now()
);
create unique index email_gmail_uniq on public.email_messages (gmail_message_id)
  where gmail_message_id is not null;
create unique index email_resend_uniq on public.email_messages (resend_email_id)
  where resend_email_id is not null;
create index email_thread_idx on public.email_messages (gmail_thread_id);
create index email_deal_idx on public.email_messages (deal_id, sendt_at desc);

comment on column public.email_messages.udtraek is
  'Struktureret udtraek fra AI-laget: budget, oensket format, deadline. Aldrig fritekst der senere skal gaettes paa.';

create table public.email_events (
  id        bigserial primary key,
  email_id  uuid not null references public.email_messages(id) on delete cascade,
  type      text not null,
  sket_at   timestamptz not null default now(),
  metadata  jsonb
);
create index email_events_email_idx on public.email_events (email_id, sket_at desc);

comment on column public.email_events.type is
  'delivered, opened, clicked, bounced, complained eller unsubscribed fra Resend.';

create table public.suppressions (
  email       text primary key,
  aarsag      text not null,
  created_at  timestamptz not null default now()
);

comment on table public.suppressions is
  'Har nogen sagt fra, rammer ingen sekvens dem igen. Tjekkes foer hver udsendelse.';

create table public.tasks (
  id                     uuid primary key default gen_random_uuid(),
  titel                  text not null,
  beskrivelse            text,
  deal_id                uuid references public.deals(id) on delete cascade,
  brand_id               uuid references public.brands(id) on delete cascade,
  ansvarlig_id           uuid references public.app_users(id) on delete set null,
  forfald                date,
  prioritet              int not null default 2 check (prioritet between 1 and 3),
  faerdig_at             timestamptz,
  oprettet_af_automatik  boolean not null default false,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index tasks_aaben_idx on public.tasks (forfald, prioritet) where faerdig_at is null;
create index tasks_ansvarlig_idx on public.tasks (ansvarlig_id) where faerdig_at is null;

-- Ukendte afsendere bliver til forslag, ikke til data. Ellers drukner
-- kartoteket i nyhedsbreve inden for en maaned.
create table public.lead_forslag (
  id                 uuid primary key default gen_random_uuid(),
  email_id           uuid references public.email_messages(id) on delete cascade,
  fra_email          text not null,
  foreslaaet_brand   text not null,
  foreslaaet_kontakt text,
  begrundelse        text,
  udtraek            jsonb,
  status             text not null default 'afventer'
                       check (status in ('afventer', 'godkendt', 'afvist')),
  behandlet_af       uuid references public.app_users(id) on delete set null,
  behandlet_at       timestamptz,
  oprettet_brand_id  uuid references public.brands(id) on delete set null,
  created_at         timestamptz not null default now()
);
create index lead_forslag_status_idx on public.lead_forslag (status, created_at desc);

create table public.automation_rules (
  id                   uuid primary key default gen_random_uuid(),
  noegle               text not null unique,
  navn                 text not null,
  beskrivelse          text,
  udloeser             text not null,
  handling             text not null,
  tilstand             public.automation_mode not null default 'toerkoersel',
  kraever_godkendelse  boolean not null default true,
  config               jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

comment on column public.automation_rules.tilstand is
  'toerkoersel betyder at reglen logger hvad den ville goere, uden at goere det.';

create table public.automation_runs (
  id                    bigserial primary key,
  rule_id               uuid not null references public.automation_rules(id) on delete cascade,
  deal_id               uuid references public.deals(id) on delete cascade,
  brand_id              uuid references public.brands(id) on delete cascade,
  idempotens_noegle     text not null unique,
  tilstand              public.automation_mode not null,
  resultat              text not null
                          check (resultat in ('foreslaaet', 'udfoert', 'fejlet', 'sprunget_over')),
  handling_beskrivelse  text,
  fejl                  text,
  payload               jsonb,
  created_at            timestamptz not null default now()
);
create index automation_runs_rule_idx on public.automation_runs (rule_id, created_at desc);
create index automation_runs_deal_idx on public.automation_runs (deal_id, created_at desc);

comment on column public.automation_runs.idempotens_noegle is
  'Fx opfoelgning_7dage:<deal_id>:2026-09-08. Garantien mod at samme mail sendes to gange.';

create trigger tasks_updated_at before update on public.tasks
  for each row execute function public.set_updated_at();
create trigger automation_rules_updated_at before update on public.automation_rules
  for each row execute function public.set_updated_at();
