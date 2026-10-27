# CLAUDE.md — Bing Ads Reporting (independent)

Standalone sync that pulls monthly **Microsoft Advertising (Bing Ads)** per-campaign
performance into Supabase. **Not part of the MAG dashboard** — it lives here on purpose so
its data never touches the dashboard's ROAS basis. (The dashboard is a separate repo at
`C:\Users\Cloverly\claude_code\dashboard`.)

- **Supabase project:** `aivitcomiywiysrfwqxt` (MAGTestProject)
- **Edge function:** `bing-ads-campaign-monthly-sync` (Deno), deployed `--no-verify-jwt`
- **Destination table:** `public.bing_ads_campaign_monthly_raw` (UPSERT on `(month, campaign_id)`)
- **Cron:** `bing-ads-campaign-monthly-sync-weekly`, `0 22 * * 0` = Mon 06:00 PH

## The non-obvious bits
- **Write to `_raw`, never `public.bing_ads_campaign_monthly`.** That second table is the
  *dashboard's* — its ROAS "All-in" basis (`roas.js`) **sums every row**, and it holds a single
  Xero-billed sentinel row (`campaign_id=0`). Writing per-campaign rows there double-counts Bing
  spend. The target is set by `TARGET_TABLE` (env `BING_ADS_TARGET_TABLE`, default
  `bing_ads_campaign_monthly_raw`). Do not repoint it.
- **Deploy keeps flipping `verify_jwt`.** The Supabase MCP `deploy_edge_function` (and plain
  `supabase functions deploy`) sets `verify_jwt=true`. The cron POSTs with **no** Authorization
  header, so it must be **false** or the job silently 401s while `cron.job_run_details` still shows
  "succeeded". After any deploy, re-PATCH it:
  `PATCH https://api.supabase.com/v1/projects/aivitcomiywiysrfwqxt/functions/bing-ads-campaign-monthly-sync`
  body `{"verify_jwt": false}` (Bearer = a Supabase personal access token). There is no local
  `supabase` CLI on this machine — deploy via MCP, then PATCH.

## Auth — the identity gotchas (both solved 2026-10-27)
Microsoft Advertising rejects a mismatched identity in two layers:
1. **Code 105 InvalidCredentials** → needs a **Universal** developer token. A single-user dev token
   only authenticates its own user. Stored in `BING_ADS_DEVELOPER_TOKEN`.
2. **Code 126 IdentityTypeMismatch** → the Bing account's logins are Gmail-based, and even a
   Microsoft *personal* account whose username is a Gmail address still 126s (that email's Bing user
   is the **Google** identity type). **Fix:** OAuth as a **clean `@outlook.com` Standard user**
   (no Google link) added to Bing account `180767648`. Standard role is enough to pull reports.

### Tokens
Personal Microsoft refresh tokens are **single-use** and rotate every run. The live token lives in
`public.oauth_token_store` (`provider='bing_ads'`); the function reads it first and writes the
rotated one back. `BING_ADS_REFRESH_TOKEN` is only a seed fallback. To re-consent: open the
authorize URL in `credentials.example.txt` (sign in as the `@outlook.com` user), copy the
`?code=…` from the nativeclient redirect, exchange it (authorization_code grant), and upsert the
new refresh token into `oauth_token_store`. **Never print a token** — build request bodies inside a
script and POST via the Supabase Management API so secrets don't materialize into context.

## Run / verify
```
curl -X POST "https://aivitcomiywiysrfwqxt.supabase.co/functions/v1/bing-ads-campaign-monthly-sync"
```
Expect `{"ok":true, table:"bing_ads_campaign_monthly_raw", upserted, distinct_months, …}`.
The function always submits+polls+upserts (no dry-run; query params are ignored).

## Secrets
All real values live in **Supabase edge secrets** (and a gitignored local credentials file) — never
in the repo. `credentials.example.txt` holds only non-secret identifiers + the re-consent URL.
`.gitignore` blocks `*credentials*.txt` (except the example), `*_secret*`, `*.key`, etc.

## Layout
```
supabase/functions/bing-ads-campaign-monthly-sync/index.ts    the sync
supabase/migrations/20261027000000_bing_ads_campaign_monthly_raw.sql    table
supabase/migrations/20261027000100_schedule_bing_ads_campaign_monthly_sync.sql    cron
credentials.example.txt   non-secret ids + re-consent URL
README.md                 project overview + the auth saga
as_built.txt              current-state inventory
```
