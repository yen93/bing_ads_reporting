-- Independent Bing Ads reporting: raw per-campaign monthly performance pulled from the
-- Microsoft Advertising Reporting API. DELIBERATELY SEPARATE from the dashboard's
-- public.bing_ads_campaign_monthly (which holds only the Xero-billed sentinel row campaign_id=0
-- that the ROAS "All-in" basis reads). This table is written by the bing-ads-campaign-monthly-sync
-- edge function and is NOT read by the dashboard, so Bing report data here never affects ROAS.
create table if not exists public.bing_ads_campaign_monthly_raw (
  month             date    not null,
  account_id        text,
  campaign_id       bigint  not null,
  campaign_name     text,
  channel_type      text,
  impressions       bigint,
  clicks            bigint,
  cost              numeric,
  conversions       numeric,
  conversions_value numeric,
  all_conversions   numeric,
  currency          text,
  updated_at        timestamptz not null default now(),
  primary key (month, campaign_id)
);

create index if not exists bing_ads_campaign_monthly_raw_month_idx
  on public.bing_ads_campaign_monthly_raw (month);
