# Lootr report relay

Cloudflare Worker that validates user-reviewed public reports, stores an
optional public screenshot in private R2, and creates an issue in
`joashdev/lootr`.

## Setup

1. In Cloudflare Turnstile, create a **Managed** widget for the Worker hostname.
   Put its public site key in `wrangler.toml`.
2. Store the Turnstile secret without printing or committing it:
   `npx wrangler secret put TURNSTILE_SECRET`
3. Create the R2 bucket:
   `npx wrangler r2 bucket create lootr-report-screenshots`
4. Add the required R2 lifecycle rule:
   `npx wrangler r2 bucket lifecycle add lootr-report-screenshots report-screenshots-30-days --expire-days 30`
5. Create a fine-grained GitHub token with only `Issues: write` permission for
   `joashdev/lootr`.
6. Store it without printing or committing it:
   `npx wrangler secret put GITHUB_TOKEN`
7. Run `pnpm test`, `pnpm check`, then `pnpm deploy`. The first deploy creates
   the `ReportQuota` Durable Object.
8. Build Lootr with the deployed Worker origin:
   `flutter build apk --dart-define=LOOTR_REPORT_ENDPOINT=https://<worker>.workers.dev`

Invocation logs and automatic traces stay disabled because attachment paths are
public bearer URLs. The Worker emits allowlisted operational JSON logs without
descriptions, diagnostics, Turnstile tokens, attachment keys, IP addresses, or
credentials.

The per-location rate limiter is an inexpensive first filter. `ReportQuota`
enforces the exact global ceiling of 25 valid report attempts per UTC day and
10 screenshot attempts per UTC hour before R2 is touched. Set
`REPORTING_ENABLED = "false"` and redeploy for an emergency kill switch.
