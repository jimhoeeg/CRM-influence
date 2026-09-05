# Databasen

Supabase-projekt **byggeligt-crm**, region eu-west-1 (Irland). Alle data ligger i EU.

Projekt-ref: `ecqmmimjgvxhozpyovsm`
API: `https://ecqmmimjgvxhozpyovsm.supabase.co`

## Migrationer

Databasen ændres kun gennem filerne i `migrations/`, aldrig ved at klikke i
Supabase-brugerfladen. Så kan vi altid genskabe den fra bunden, og vi kan se
hvornår noget blev lavet om og hvorfor.

```bash
supabase link --project-ref ecqmmimjgvxhozpyovsm
supabase db push                 # kører nye migrationer
supabase db reset                # bygger lokal database forfra og kører seed.sql
supabase gen types typescript --linked > ../src/types/database.ts
```

| Fil | Indhold |
| --- | --- |
| `0001_fundament.sql` | Typer, brugere, roller, adgangsfunktioner |
| `0002_kerne.sql` | Brands, kontakter, aftaler, stagehistorik, aktiviteter |
| `0003_produktion.sql` | Leverancer, brugsret, kapacitet, eksklusivitet |
| `0004_kommerciel.sql` | Prisliste, fakturaer, kanaler, kampagnetal |
| `0005_kommunikation.sql` | Mails, hændelser, opgaver, leadforslag, regelmotor |
| `0006_rls_og_views.sql` | Adgangskontrol på alle tabeller + visninger |
| `0007_konfiguration.sql` | De otte automatikregler, alle i tørkørsel |
| `0008`–`0011` | Hærdning: interne funktioner ud af det offentlige API |

## Brugere og roller

Der er ingen liste over godkendte mails i koden eller i miljøvariabler.
Adgang styres i databasen og kan ændres når som helst.

| Rolle | Kan |
| --- | --- |
| `owner` | Alt, inklusive at invitere og fjerne brugere |
| `editor` | Alt fagligt: brands, aftaler, priser, fakturaer |
| `produktion` | Leverancer, kalender, opgaver og kampagnetal. **Ser ikke fakturaer eller prisliste** |

Invitér en kollega (kaldes som owner, fra appen eller SQL-editoren):

```sql
select public.inviter_bruger('aleksandra@byggeligt.dk', 'Aleksandra', 'editor');
select public.inviter_bruger('stephanie@byggeligt.dk', 'Stephanie', 'produktion');
```

Personen logger ind med magic link på sin mail. Første login kobler dem
automatisk på invitationen og giver den rolle, invitationen siger.
**Logger nogen ind uden en invitation, oprettes de inaktive og ser ingenting.**

Fjern adgang uden at slette historikken bag personen:

```sql
select public.deaktiver_bruger('stephanie@byggeligt.dk');
```

Skift rolle: kør `inviter_bruger` igen med den nye rolle.

## Demodata

Seks brands, seks aftaler, otte leverancer og tre målinger, så skærmene har
noget at vise. Brands er markeret med `noter = 'demo'`, aftaler med
`kilde = 'demo'`. Fjern det hele, når de rigtige aftaler er inde:

```sql
select public.slet_demodata();
```

## Det der mangler data

`rate_card` står tom med vilje. Priser er ikke noget, der skal gættes —
indsæt jeres egne, når I har dem, én række pr. format:

```sql
insert into public.rate_card (platform, format, listepris_kr, minimumspris_kr)
values ('instagram', 'reel', 25000, 18000);
```

Historikken bevares ved at sætte `gaelder_til` på den gamle række frem for at
rette prisen.

## Sikkerhed

Row level security er slået til på alle 22 tabeller. Ingen række kan læses uden
en aktiv bruger bag. Adgangsfunktionerne ligger i schema `app`, som ikke er
eksponeret på REST-API'et.

Supabases sikkerhedsgennemgang melder tre resterende advarsler, alle på
`inviter_bruger`, `deaktiver_bruger` og `slet_demodata`. De er tilsigtede:
funktionerne **skal** kunne kaldes af en logget ind bruger, og de tjekker selv,
at kalderen er owner, før de gør noget. Anonym adgang til dem er fjernet.
