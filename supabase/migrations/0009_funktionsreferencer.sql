-- 0009 Retter interne kald efter flytningen til schema app.
-- create or replace bevarer funktionernes id, saa politikkerne foelger med.

create or replace function app.har_rolle(roller public.app_role[])
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.app_users u
    where u.id = auth.uid() and u.aktiv and u.rolle = any(roller)
  );
$$;

create or replace function app.ser_oekonomi()
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select app.har_rolle(array['owner', 'editor']::public.app_role[]);
$$;

create or replace function app.kan_redigere()
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select app.har_rolle(array['owner', 'editor']::public.app_role[]);
$$;

create or replace function app.er_owner()
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select app.har_rolle(array['owner']::public.app_role[]);
$$;

create or replace function app.beskyt_rolle()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if app.er_owner() then
    return new;
  end if;
  if new.rolle is distinct from old.rolle or new.aktiv is distinct from old.aktiv then
    raise exception 'Kun en owner kan aendre rolle eller adgang';
  end if;
  return new;
end;
$$;

create or replace function public.inviter_bruger(
  p_email text,
  p_navn  text default '',
  p_rolle public.app_role default 'produktion'
)
returns public.invitations language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  rec public.invitations;
begin
  if not app.er_owner() then
    raise exception 'Kun en owner kan invitere brugere';
  end if;

  insert into public.invitations (email, navn, rolle, inviteret_af)
  values (lower(p_email), p_navn, p_rolle, auth.uid())
  on conflict (lower(email)) do update
    set navn = excluded.navn,
        rolle = excluded.rolle,
        brugt_at = null
  returning * into rec;

  update public.app_users
     set rolle = p_rolle, aktiv = true, navn = coalesce(nullif(p_navn, ''), navn)
   where lower(email) = lower(p_email);

  return rec;
end;
$$;

create or replace function public.deaktiver_bruger(p_email text)
returns void language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if not app.er_owner() then
    raise exception 'Kun en owner kan fjerne adgang';
  end if;
  update public.app_users set aktiv = false where lower(email) = lower(p_email);
  update public.invitations set brugt_at = now() where lower(email) = lower(p_email);
end;
$$;

create or replace function public.slet_demodata()
returns void language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if not app.er_owner() then
    raise exception 'Kun en owner kan slette demodata';
  end if;
  delete from public.deals  where kilde = 'demo';
  delete from public.brands where noter = 'demo';
end;
$$;

revoke all on all functions in schema app from public;
grant execute on all functions in schema app to authenticated, service_role;
