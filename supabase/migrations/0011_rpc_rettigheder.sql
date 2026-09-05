-- 0011 create or replace nulstiller standardrettigheder, saa de skal saettes igen.
-- De tre RPC er skal kunne kaldes af en logget ind bruger og tjekker selv,
-- at kalderen er owner. Ingen af dem maa kunne rammes uden login.

revoke all on function public.inviter_bruger(text, text, public.app_role) from public, anon;
revoke all on function public.deaktiver_bruger(text) from public, anon;
revoke all on function public.slet_demodata() from public, anon;

grant execute on function public.inviter_bruger(text, text, public.app_role) to authenticated, service_role;
grant execute on function public.deaktiver_bruger(text) to authenticated, service_role;
grant execute on function public.slet_demodata() to authenticated, service_role;

revoke all on function public.tjek_eksklusivitet(uuid, date) from public, anon;
revoke all on function public.pris_historik(public.platform, text) from public, anon;
grant execute on function public.tjek_eksklusivitet(uuid, date) to authenticated, service_role;
grant execute on function public.pris_historik(public.platform, text) to authenticated, service_role;
