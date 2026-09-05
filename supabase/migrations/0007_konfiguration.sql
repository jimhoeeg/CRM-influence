-- 0007 Konfiguration: automatikreglerne og et vaerktoej til at rydde demodata

-- De otte foerste regler. Alle starter i toerkoersel: de logger hvad de ville
-- have gjort, indtil vi har set to ugers forslag igennem.
insert into public.automation_rules (noegle, navn, beskrivelse, udloeser, handling, tilstand, kraever_godkendelse, config)
values
  ('mail_ind_kobles',
   'Indgaaende mail kobles paa aftalen',
   'Mail fra et kendt brand lander paa den rigtige aftale, og et lead flyttes til Kontaktet.',
   'email.modtaget', 'kobl_paa_aftale_og_flyt_stage', 'toerkoersel', false,
   '{"flyt_fra": ["lead"], "flyt_til": "kontaktet"}'),

  ('tilbud_aabnet',
   'Tilbud aabnet to gange samme dag',
   'Opretter opgaven ring i dag. Opkald inden for 48 timer efter anden aabning lukker markant flere aftaler.',
   'email.aabnet', 'opret_opgave', 'toerkoersel', false,
   '{"aabninger": 2, "inden_for_timer": 24, "opgave_prioritet": 1}'),

  ('opfoelgning_stilhed',
   'Opfoelgning ved stilhed',
   'Syv og fjorten dage uden svar udloeser en opfoelgning skrevet i vores tone.',
   'deal.ingen_svar', 'send_opfoelgning', 'toerkoersel', true,
   '{"dage": [7, 14], "kold_efter_dage": 21}'),

  ('kontrakt_underskrevet',
   'Kontrakt underskrevet',
   'Flytter aftalen til Vundet og opretter leverancer, brugsret og kalenderpunkter.',
   'deal.vundet', 'opret_leverancer_og_kalender', 'toerkoersel', false,
   '{}'),

  ('deadline_varsel',
   'Deadline om tre dage',
   'Paaminder den ansvarlige, og brandet hvis de mangler at godkende.',
   'deliverable.deadline_naer', 'paamind', 'toerkoersel', false,
   '{"dage_foer": 3}'),

  ('alt_leveret',
   'Alle leverancer godkendt',
   'Lægger fakturakladde i e-conomic klar og sender afrapportering med tal.',
   'deal.alle_leverancer_godkendt', 'opret_fakturaudkast_og_afrapportering', 'toerkoersel', true,
   '{"system": "economic", "betalingsbetingelser_dage": 14}'),

  ('brugsret_udloeb',
   'Brugsret udloeber om 30 dage',
   'Giver besked og foreslaar forlaengelse som mersalg.',
   'usage_right.udloeber', 'varsel_og_mersalg', 'toerkoersel', true,
   '{"dage_foer": 30}'),

  ('genkoeb',
   'Genkoebsoplaeg efter levering',
   'Bygger et oplaeg paa de bedst praesterende leverancer 90 dage efter levering.',
   'deal.leveret', 'byg_genkoebsoplaeg', 'toerkoersel', true,
   '{"dage_efter": 90}');

-- Demodata kan fjernes med et enkelt kald, naar de rigtige aftaler er inde.
create or replace function public.slet_demodata()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.er_owner() then
    raise exception 'Kun en owner kan slette demodata';
  end if;
  delete from public.deals  where kilde = 'demo';
  delete from public.brands where noter = 'demo';
end;
$$;

comment on function public.slet_demodata is
  'Fjerner alle raekker markeret med kilde/noter = demo. Roerer ikke rigtige aftaler.';
