# Bing Ads Reporting (independent)

Pulls monthly **Microsoft Advertising (Bing Ads)** per-campaign performance into Supabase for
reporting/analysis. **Standalone** — deliberately decoupled from the MAG dashboard.

- **Supabase project:** `aivitcomiywiysrfwqxt` (MAGTestProject)
- **Edge function:** `bing-ads-campaign-monthly-sync` (deployed `--no-verify-jwt`)
- **Destination table:** `public.bing_ads_campaign_monthly_raw` (per-campaign, UPSERT on `(month, campaign_id)`)
- **Schedule:** pg_cron `bing-ads-campaign-monthly-sync-weekly`, `0 22 * * 0` = **Mon 06:00 Philippine Time**

## ⚠ Why its own `_raw` table
The MAG dashboard's ROAS "All-in" cost basis reads `public.bing_ads_campaign_monthly`, and
`server/metrics/roas.js` **sums every row** of it. That table holds a single Xero-billed sentinel
row (`campaign_id=0`, written by the dashboard's `xero-ad-spend-sync`). If this reporting sync wrote
per-campaign rows there too, ROAS would **double-count** Bing spend. So this project writes to
`bing_ads_campaign_monthly_raw` instead — the dashboard never reads it. **Do not repoint the
function at `bing_ads_campaign_monthly`.** (Override via the `BING_ADS_TARGET_TABLE` secret if ever
needed.)

## Auth — how we got it working (2026-10-27)
Microsoft Advertising rejects a mismatched sign-in identity:
- **Code 105 InvalidCredentials** → fixed by the Super Admin issuing a **Universal developer token**
  (a single-user dev token only authenticates its own user).
- **Code 126 IdentityTypeMismatch** → the ad account's primary logins are Gmail-based; a Microsoft
  personal account whose *username* is a Gmail address still 126s, because that email's Bing user is
  keyed to the **Google** identity type. **Fix:** a clean **`@outlook.com`** account (no Google link)
  was added as a **Standard user** on account `180767648`, and we OAuth as that identity.

### Token rotation
Personal Microsoft refresh tokens are **single-use**. The live token is kept in
`public.oauth_token_store` (`provider='bing_ads'`) and rotated on every run; `BING_ADS_REFRESH_TOKEN`
is only a seed fallback. To re-consent, use the authorize URL in `credentials.example.txt` (sign in
as the `@outlook.com` user), exchange the code, and upsert the new refresh token into
`oauth_token_store`.

## Run it manually
```
curl -X POST "https://aivitcomiywiysrfwqxt.supabase.co/functions/v1/bing-ads-campaign-monthly-sync"
```
Expect `{"ok":true, table, upserted, distinct_months, first_month, last_month, total_cost}`.

## Deploy
```
supabase functions deploy bing-ads-campaign-monthly-sync --no-verify-jwt
```
(or via the Supabase MCP, then ensure `verify_jwt=false`). The cron POSTs with no auth header, so
`--no-verify-jwt` is mandatory.

## Layout
```
supabase/functions/bing-ads-campaign-monthly-sync/index.ts   the sync
supabase/migrations/20261027000000_bing_ads_campaign_monthly_raw.sql    destination table
supabase/migrations/20261027000100_schedule_bing_ads_campaign_monthly_sync.sql    weekly cron
credentials.example.txt    non-secret identifiers + re-consent URL
```

## Status (2026-10-27)
First live backfill succeeded: **146 campaign-rows, 17 months (Jun 2025 → Oct 2026), ≈ $17,426**.
