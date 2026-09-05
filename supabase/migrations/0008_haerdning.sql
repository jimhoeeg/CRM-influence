-- 0008 Haerdning: interne funktioner ud af det offentlige API
--
-- Alt i schema public bliver til et REST-endepunkt. Adgangsfunktionerne og
-- triggerne har intet at goere der, saa de flyttes til schema app, som ikke
-- er eksponeret. Politikkerne peger paa funktionernes id og foelger med.

create schema if not exists app;

revoke all on schema app from public;
grant usage on schema app to authenticated, service_role;

-- Adgangskontrol, kaldes indefra politikkerne
alter function public.er_aktiv()                          set schema app;
alter function public.har_rolle(public.app_role[])        set schema app;
alter function public.kan_redigere()                      set schema app;
alter function public.ser_oekonomi()                      set schema app;
alter function public.er_owner()                          set schema app;

-- Triggerfunktioner, kaldes kun af databasen selv
alter function public.set_updated_at()                    set schema app;
alter function public.handle_new_user()                   set schema app;
alter function public.beskyt_rolle()                      set schema app;
alter function public.log_stage_skift()                   set schema app;
alter function public.opdater_sidste_kontakt()            set schema app;
alter function public.saet_lukket_at()                    set schema app;
alter function public.saet_godkendt_at()                  set schema app;

revoke all on all functions in schema app from public;
grant execute on all functions in schema app to authenticated, service_role;

-- Disse tre skal kunne kaldes fra appen, men aldrig af en ikke-logget ind
-- besoegende. De tjekker selv, at kalderen er owner.
revoke execute on function public.inviter_bruger(text, text, public.app_role) from anon;
revoke execute on function public.deaktiver_bruger(text) from anon;
revoke execute on function public.slet_demodata() from anon;
revoke execute on function public.tjek_eksklusivitet(uuid, date) from anon;
revoke execute on function public.pris_historik(public.platform, text) from anon;
