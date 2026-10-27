-- Weekly schedule for the bing-ads-campaign-monthly-sync edge function (independent project).
-- Monday 06:00 Philippine Time = Sunday 22:00 UTC. The function is deployed --no-verify-jwt, so the
-- POST carries no Authorization header. It submits an async report then polls (up to ~2 min), so
-- give pg_net a 150s timeout. Keeps public.bing_ads_campaign_monthly_raw fresh. NOTE: this writes to
-- the *_raw* table only — it does NOT touch public.bing_ads_campaign_monthly, so it never affects the
-- MAG dashboard's ROAS basis.

select cron.unschedule('bing-ads-campaign-monthly-sync-weekly')
where exists (select 1 from cron.job where jobname = 'bing-ads-campaign-monthly-sync-weekly');

select cron.schedule(
  'bing-ads-campaign-monthly-sync-weekly',
  '0 22 * * 0',
  $$
  select net.http_post(
    url := 'https://aivitcomiywiysrfwqxt.supabase.co/functions/v1/bing-ads-campaign-monthly-sync?sync=1',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := '{}'::jsonb,
    timeout_milliseconds := 150000
  );
  $$
);
