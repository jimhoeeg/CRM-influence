-- 0006 Adgangskontrol paa alle tabeller, samt laesevenlige visninger
--
-- Grundregel: ingen data forlader databasen uden en aktiv bruger bag.
-- Rollerne: owner = alt. editor = alt fagligt inkl. oekonomi.
-- produktion = leverancer, kalender og tal, men ingen fakturaer eller prisliste.

alter table public.app_users           enable row level security;
alter table public.invitations         enable row level security;
alter table public.brands              enable row level security;
alter table public.contacts            enable row level security;
alter table public.deals               enable row level security;
alter table public.deal_stage_history  enable row level security;
alter table public.activities          enable row level security;
alter table public.deliverables        enable row level security;
alter table public.usage_rights        enable row level security;
alter table public.capacity_blocks     enable row level security;
alter table public.exclusivity         enable row level security;
alter table public.rate_card           enable row level security;
alter table public.invoices            enable row level security;
alter table public.social_accounts     enable row level security;
alter table public.campaign_metrics    enable row level security;
alter table public.email_messages      enable row level security;
alter table public.email_events        enable row level security;
alter table public.suppressions        enable row level security;
alter table public.tasks               enable row level security;
alter table public.lead_forslag        enable row level security;
alter table public.automation_rules    enable row level security;
alter table public.automation_runs     enable row level security;

revoke all on all tables in schema public from anon;

-- ---------------------------------------------------------------- brugere

create policy app_users_select on public.app_users
  for select to authenticated using (public.er_aktiv() or id = auth.uid());
create policy app_users_update_egen on public.app_users
  for update to authenticated using (id = auth.uid() or public.er_owner())
  with check (id = auth.uid() or public.er_owner());
create policy app_users_delete on public.app_users
  for delete to authenticated using (public.er_owner());

create policy invitations_alle on public.invitations
  for all to authenticated using (public.er_owner()) with check (public.er_owner());

-- ---------------------------------------------------------------- fagligt
-- Laeses af alle aktive, redigeres af owner og editor.

create policy brands_select on public.brands
  for select to authenticated using (public.er_aktiv());
create policy brands_write on public.brands
  for insert to authenticated with check (public.kan_redigere());
create policy brands_update on public.brands
  for update to authenticated using (public.kan_redigere()) with check (public.kan_redigere());
create policy brands_delete on public.brands
  for delete to authenticated using (public.er_owner());

create policy contacts_select on public.contacts
  for select to authenticated using (public.er_aktiv());
create policy contacts_write on public.contacts
  for insert to authenticated with check (public.kan_redigere());
create policy contacts_update on public.contacts
  for update to authenticated using (public.kan_redigere()) with check (public.kan_redigere());
create policy contacts_delete on public.contacts
  for delete to authenticated using (public.er_owner());

create policy deals_select on public.deals
  for select to authenticated using (public.er_aktiv());
create policy deals_write on public.deals
  for insert to authenticated with check (public.kan_redigere());
create policy deals_update on public.deals
  for update to authenticated using (public.kan_redigere()) with check (public.kan_redigere());
create policy deals_delete on public.deals
  for delete to authenticated using (public.er_owner());

create policy usage_rights_select on public.usage_rights
  for select to authenticated using (public.er_aktiv());
create policy usage_rights_write on public.usage_rights
  for insert to authenticated with check (public.kan_redigere());
create policy usage_rights_update on public.usage_rights
  for update to authenticated using (public.kan_redigere()) with check (public.kan_redigere());
create policy usage_rights_delete on public.usage_rights
  for delete to authenticated using (public.kan_redigere());

create policy exclusivity_select on public.exclusivity
  for select to authenticated using (public.er_aktiv());
create policy exclusivity_write on public.exclusivity
  for insert to authenticated with check (public.kan_redigere());
create policy exclusivity_update on public.exclusivity
  for update to authenticated using (public.kan_redigere()) with check (public.kan_redigere());
create policy exclusivity_delete on public.exclusivity
  for delete to authenticated using (public.kan_redigere());

-- ---------------------------------------------------------------- produktion
-- Alle aktive kan arbejde her, ogsaa rollen produktion.

create policy deliverables_select on public.deliverables
  for select to authenticated using (public.er_aktiv());
create policy deliverables_write on public.deliverables
  for insert to authenticated with check (public.er_aktiv());
create policy deliverables_update on public.deliverables
  for update to authenticated using (public.er_aktiv()) with check (public.er_aktiv());
create policy deliverables_delete on public.deliverables
  for delete to authenticated using (public.kan_redigere());

create policy capacity_select on public.capacity_blocks
  for select to authenticated using (public.er_aktiv());
create policy capacity_write on public.capacity_blocks
  for insert to authenticated with check (public.er_aktiv());
create policy capacity_update on public.capacity_blocks
  for update to authenticated using (public.er_aktiv()) with check (public.er_aktiv());
create policy capacity_delete on public.capacity_blocks
  for delete to authenticated using (public.er_aktiv());

create policy tasks_select on public.tasks
  for select to authenticated using (public.er_aktiv());
create policy tasks_write on public.tasks
  for insert to authenticated with check (public.er_aktiv());
create policy tasks_update on public.tasks
  for update to authenticated using (public.er_aktiv()) with check (public.er_aktiv());
create policy tasks_delete on public.tasks
  for delete to authenticated using (public.er_aktiv());

create policy activities_select on public.activities
  for select to authenticated using (public.er_aktiv());
create policy activities_write on public.activities
  for insert to authenticated with check (public.er_aktiv());

create policy metrics_select on public.campaign_metrics
  for select to authenticated using (public.er_aktiv());
create policy metrics_write on public.campaign_metrics
  for insert to authenticated with check (public.er_aktiv());
create policy metrics_update on public.campaign_metrics
  for update to authenticated using (public.er_aktiv()) with check (public.er_aktiv());

create policy lead_forslag_select on public.lead_forslag
  for select to authenticated using (public.er_aktiv());
create policy lead_forslag_update on public.lead_forslag
  for update to authenticated using (public.er_aktiv()) with check (public.er_aktiv());

-- ---------------------------------------------------------------- oekonomi
-- Kun owner og editor. Rollen produktion ser hverken priser eller fakturaer.

create policy rate_card_select on public.rate_card
  for select to authenticated using (public.ser_oekonomi());
create policy rate_card_write on public.rate_card
  for insert to authenticated with check (public.ser_oekonomi());
create policy rate_card_update on public.rate_card
  for update to authenticated using (public.ser_oekonomi()) with check (public.ser_oekonomi());
create policy rate_card_delete on public.rate_card
  for delete to authenticated using (public.er_owner());

create policy invoices_select on public.invoices
  for select to authenticated using (public.ser_oekonomi());
create policy invoices_write on public.invoices
  for insert to authenticated with check (public.ser_oekonomi());
create policy invoices_update on public.invoices
  for update to authenticated using (public.ser_oekonomi()) with check (public.ser_oekonomi());
create policy invoices_delete on public.invoices
  for delete to authenticated using (public.er_owner());

-- ---------------------------------------------------------------- kun laesning
-- Historik og maskinskrevne raekker. Skrives af triggere og Edge Functions,
-- aldrig af en browser.

create policy stage_history_select on public.deal_stage_history
  for select to authenticated using (public.er_aktiv());
create policy email_select on public.email_messages
  for select to authenticated using (public.er_aktiv());
create policy email_events_select on public.email_events
  for select to authenticated using (public.er_aktiv());
create policy suppressions_select on public.suppressions
  for select to authenticated using (public.er_aktiv());
create policy automation_runs_select on public.automation_runs
  for select to authenticated using (public.er_aktiv());

create policy automation_rules_select on public.automation_rules
  for select to authenticated using (public.er_aktiv());
create policy automation_rules_update on public.automation_rules
  for update to authenticated using (public.er_owner()) with check (public.er_owner());

create policy social_accounts_select on public.social_accounts
  for select to authenticated using (public.er_aktiv());
create policy social_accounts_write on public.social_accounts
  for all to authenticated using (public.er_owner()) with check (public.er_owner());

-- ================================================================ visninger
-- security_invoker gør at adgangskontrollen ovenfor ogsaa gaelder her.

create view public.v_pipeline with (security_invoker = true) as
select d.id,
       d.titel,
       d.stage,
       d.vaerdi_kr,
       d.vejet_vaerdi_kr,
       d.sandsynlighed,
       d.forventet_luk,
       d.automatik_pause,
       b.id   as brand_id,
       b.navn as brand,
       b.branche,
       u.navn as ejer,
       k.navn as kontakt,
       b.sidste_kontakt_at,
       extract(day from now() - coalesce(b.sidste_kontakt_at, d.created_at))::int
         as dage_siden_kontakt,
       (select min(dl.deadline) from public.deliverables dl
         where dl.deal_id = d.id and dl.status not in ('leveret', 'aflyst'))
         as naeste_deadline
from public.deals d
join public.brands b on b.id = d.brand_id
left join public.app_users u on u.id = d.ejer_id
left join public.contacts k on k.id = d.primaer_kontakt_id;

create view public.v_forecast with (security_invoker = true) as
select date_trunc('month', coalesce(d.forventet_luk, current_date))::date as maaned,
       count(*)                                as antal_aftaler,
       sum(d.vaerdi_kr)                        as pipeline_kr,
       sum(d.vejet_vaerdi_kr)                  as vejet_kr,
       sum(d.vaerdi_kr) filter (where d.stage in ('vundet', 'leveret')) as vundet_kr
from public.deals d
where d.stage <> 'tabt'
group by 1
order by 1;

create view public.v_leverancer with (security_invoker = true) as
select dl.id,
       dl.titel,
       dl.platform,
       dl.format,
       dl.antal,
       dl.deadline,
       dl.status,
       dl.live_url,
       d.id   as deal_id,
       d.titel as deal,
       b.navn as brand,
       u.navn as ansvarlig,
       k.navn as godkender
from public.deliverables dl
join public.deals d on d.id = dl.deal_id
join public.brands b on b.id = d.brand_id
left join public.app_users u on u.id = dl.ansvarlig_id
left join public.contacts k on k.id = dl.godkendt_af_kontakt_id;

create view public.v_brugsret_udloeb with (security_invoker = true) as
select r.id,
       b.navn as brand,
       d.titel as deal,
       r.beskrivelse,
       r.kanaler,
       r.geografi,
       r.betalt_annoncering,
       r.udloeb_dato,
       (r.udloeb_dato - current_date) as dage_til_udloeb
from public.usage_rights r
join public.deals d on d.id = r.deal_id
join public.brands b on b.id = d.brand_id
where r.udloeb_dato is not null
order by r.udloeb_dato;

-- Seneste maaling pr. leverance, uanset om den er hentet eller tastet ind
create view public.v_seneste_metrics with (security_invoker = true) as
select distinct on (m.deliverable_id)
       m.deliverable_id,
       m.maalt_at,
       m.kilde,
       m.visninger,
       m.raekkevidde,
       m.engagement,
       m.klik,
       m.gennemfoerselsrate
from public.campaign_metrics m
order by m.deliverable_id, m.maalt_at desc;

create view public.v_deal_resultater with (security_invoker = true) as
select d.id as deal_id,
       b.navn as brand,
       d.titel,
       d.vaerdi_kr,
       count(dl.id)                     as antal_leverancer,
       sum(sm.visninger)                as visninger,
       sum(sm.engagement)               as engagement,
       sum(sm.klik)                     as klik,
       case when sum(sm.visninger) > 0
            then round(d.vaerdi_kr / (sum(sm.visninger) / 1000.0), 2)
       end                              as cpm_kr,
       max(sm.maalt_at)                 as sidst_maalt
from public.deals d
join public.brands b on b.id = d.brand_id
left join public.deliverables dl on dl.deal_id = d.id
left join public.v_seneste_metrics sm on sm.deliverable_id = dl.id
where d.stage in ('vundet', 'leveret')
group by d.id, b.navn, d.titel, d.vaerdi_kr;

create view public.v_brand_oversigt with (security_invoker = true) as
select b.id,
       b.navn,
       b.branche,
       b.kategori,
       b.status,
       b.lead_score,
       b.sidste_kontakt_at,
       extract(day from now() - b.sidste_kontakt_at)::int as dage_siden_kontakt,
       count(d.id) filter (where d.stage not in ('vundet', 'leveret', 'tabt')) as aabne_aftaler,
       coalesce(sum(d.vaerdi_kr) filter (where d.stage in ('vundet', 'leveret')), 0)
         as omsaetning_kr
from public.brands b
left join public.deals d on d.brand_id = b.id
group by b.id;
