-- Seed: foerste bruger og demodata til at bygge skaermene mod.
-- Demodata er markeret med noter = 'demo' paa brands og kilde = 'demo' paa deals,
-- og fjernes samlet med: select public.slet_demodata();

-- ---------------------------------------------------------------- adgang
-- Foerste owner. Raekken her er den eneste, der ikke kan oprettes fra appen,
-- fordi der endnu ikke findes en owner til at invitere.
insert into public.invitations (email, navn, rolle)
values ('jimhoeeg@gmail.com', 'Jim', 'owner')
on conflict (lower(email)) do update
  set rolle = 'owner', brugt_at = null;

-- Aleksandra og Stephanie tilfoejes med deres arbejdsmail, naar den er kendt:
--   select public.inviter_bruger('navn@byggeligt.dk', 'Aleksandra', 'editor');
--   select public.inviter_bruger('navn@byggeligt.dk', 'Stephanie', 'produktion');

-- ---------------------------------------------------------------- brands
insert into public.brands (navn, branche, kategori, website, status, lead_score, sidste_kontakt_at, noter)
values
  ('STARK',              'Byggemarked', 'byggemarked', 'stark.dk',    'aktiv_aftale',  92, now() - interval '3 days',  'demo'),
  ('Bosch Professional', 'Vaerktoej',   'vaerktoej',   'bosch.dk',    'aktiv_aftale',  88, now() - interval '6 days',  'demo'),
  ('Flügger',            'Maling',      'maling',      'flugger.dk',  'i_produktion',  85, now() - interval '1 day',   'demo'),
  ('VELUX',              'Ovenlys',     'ovenlys',     'velux.dk',    'forhandling',   79, now() - interval '11 days', 'demo'),
  ('Kährs',              'Traegulve',   'gulv',        'kahrs.com',   'nyt_lead',      69, now() - interval '2 days',  'demo'),
  ('Bygma',              'Traelast',    'byggemarked', 'bygma.dk',    'faktureret',    74, now() - interval '24 days', 'demo');

-- ---------------------------------------------------------------- kontakter
insert into public.contacts (brand_id, navn, rolle, email, primaer)
select id, v.navn, v.rolle, v.email, true
from public.brands b
join (values
  ('STARK',              'Mette Krogh',   'Marketingchef',  'mette@example.com'),
  ('Bosch Professional', 'Anders Lund',   'Brand Manager',  'anders@example.com'),
  ('Flügger',            'Sofie Bang',    'Kampagne',       'sofie@example.com'),
  ('VELUX',              'Peter Hald',    'Nordics',        'peter@example.com'),
  ('Kährs',              'Jonas Ek',      'DK-ansvarlig',   'jonas@example.com'),
  ('Bygma',              'Line Toft',     'Marketing',      'line@example.com')
) as v(brand, navn, rolle, email) on v.brand = b.navn;

-- ---------------------------------------------------------------- aftaler
insert into public.deals (brand_id, titel, vaerdi_kr, stage, sandsynlighed, forventet_luk, primaer_kontakt_id, kilde)
select b.id, v.titel, v.vaerdi, v.stage::public.deal_stage, v.pct, v.luk::date, k.id, 'demo'
from public.brands b
join (values
  ('VELUX',              'Loft til leg, tagboligserie',   320000, 'forhandling', 60, '2026-09-25'),
  ('Bosch Professional', 'Vaerktoejstest-serie Q4',       240000, 'tilbud',      45, '2026-09-18'),
  ('STARK',              'Efteraarskampagne: Terrasse',   185000, 'forhandling', 75, '2026-09-12'),
  ('Flügger',            'Malerguide, 4 afsnit',           96000, 'vundet',     100, '2026-08-20'),
  ('Kährs',              'Gulv fra A til Z',              120000, 'lead',        10, null),
  ('Bygma',              'Fagfolk-serie, 6 afsnit',       210000, 'leveret',    100, '2026-08-12')
) as v(brand, titel, vaerdi, stage, pct, luk) on v.brand = b.navn
left join public.contacts k on k.brand_id = b.id and k.primaer;

-- ---------------------------------------------------------------- leverancer
insert into public.deliverables (deal_id, titel, platform, format, antal, deadline, status)
select d.id, v.titel, v.platform::public.platform, v.format, v.antal,
       v.deadline::date, v.status::public.deliverable_status
from public.deals d
join (values
  ('Malerguide, 4 afsnit',         'Afsnit 1: Forbehandling',        'youtube',   'yt_integration', 1, '2026-08-28', 'leveret'),
  ('Malerguide, 4 afsnit',         'Afsnit 2: Valg af maling',       'youtube',   'yt_integration', 1, '2026-09-02', 'leveret'),
  ('Malerguide, 4 afsnit',         'Afsnit 3: Teknik og vaerktoej',  'youtube',   'yt_integration', 1, '2026-09-04', 'godkendt'),
  ('Malerguide, 4 afsnit',         'Afsnit 4: Finish og fejlfinding','youtube',   'yt_integration', 1, '2026-09-11', 'i_gang'),
  ('Efteraarskampagne: Terrasse',  'Reels: byg din terrasse',        'instagram', 'reel',           4, '2026-09-21', 'ikke_startet'),
  ('Efteraarskampagne: Terrasse',  'Blogindlaeg med materialeliste', 'blog',      'blogindlaeg',    1, '2026-10-02', 'ikke_startet'),
  ('Fagfolk-serie, 6 afsnit',      'Seks afsnit, fagfolk',           'youtube',   'yt_integration', 6, '2026-08-12', 'leveret'),
  ('Loft til leg, tagboligserie',  'Reels til tagbolig',             'instagram', 'reel',           3, '2026-10-16', 'ikke_startet')
) as v(deal, titel, platform, format, antal, deadline, status) on v.deal = d.titel;

-- ---------------------------------------------------------------- brugsret
insert into public.usage_rights (deal_id, beskrivelse, kanaler, geografi, betalt_annoncering, start_dato, udloeb_dato)
select d.id, v.beskrivelse, v.kanaler::text[], v.geo, v.betalt, v.start::date, v.udloeb::date
from public.deals d
join (values
  ('Fagfolk-serie, 6 afsnit',     'Fuld brugsret til seks afsnit', '{"youtube","meta"}',   'DK',     true,  '2026-06-01', '2026-12-01'),
  ('Malerguide, 4 afsnit',        'Klip maa bruges i egne kanaler','{"youtube","meta"}',   'DK',     false, '2026-08-20', '2027-02-20'),
  ('Efteraarskampagne: Terrasse', 'Reels i betalt annoncering',    '{"instagram","meta"}', 'DK',     true,  '2026-09-15', '2027-09-15')
) as v(deal, beskrivelse, kanaler, geo, betalt, start, udloeb) on v.deal = d.titel;

-- ---------------------------------------------------------------- resultater
insert into public.campaign_metrics (deliverable_id, maalt_at, kilde, visninger, raekkevidde, engagement, klik, gennemfoerselsrate)
select dl.id, now() - interval '2 days', 'manuel', v.visninger, v.raekkevidde, v.engagement, v.klik, v.rate
from public.deliverables dl
join (values
  ('Seks afsnit, fagfolk',            1912000, 1240000, 84300, 12400, 41.2),
  ('Afsnit 1: Forbehandling',          214000,  168000,  9800,  1450, 46.8),
  ('Afsnit 2: Valg af maling',         188000,  151000,  8100,  1190, 44.1)
) as v(titel, visninger, raekkevidde, engagement, klik, rate) on v.titel = dl.titel;

-- ---------------------------------------------------------------- eksklusivitet
insert into public.exclusivity (brand_id, kategori, start_dato, slut_dato, noter)
select b.id, 'byggemarked', '2026-09-01', '2026-12-31',
       'STARK har eneret i kategorien byggemarked i kampagneperioden'
from public.brands b where b.navn = 'STARK';
