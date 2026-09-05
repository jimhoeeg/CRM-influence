-- 0010 Servicekonteksten (Edge Functions, migrationer, foerste opsaetning) har
-- intet JWT og skal kunne rette roller. Kun en logget ind bruger uden
-- owner-rolle spaerres.

create or replace function app.beskyt_rolle()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or app.er_owner() then
    return new;
  end if;
  if new.rolle is distinct from old.rolle or new.aktiv is distinct from old.aktiv then
    raise exception 'Kun en owner kan aendre rolle eller adgang';
  end if;
  return new;
end;
$$;
