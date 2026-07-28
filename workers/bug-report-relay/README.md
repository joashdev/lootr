# Lootr report relay

Cloudflare Worker that validates user-reviewed public reports, stores an
optional public screenshot in private R2, and creates an issue in
`joashdev/lootr`.

## Setup

1. Create the R2 bucket:
   `npx wrangler r2 bucket create lootr-report-screenshots`
2. Add the required R2 lifecycle rule:
   `npx wrangler r2 bucket lifecycle add lootr-report-screenshots --expire-days 30`
3. Create a fine-grained GitHub token with only `Issues: write` permission for
   `joashdev/lootr`.
4. Store it without printing or committing it:
   `npx wrangler secret put GITHUB_TOKEN`
5. Run `pnpm test`, `pnpm check`, then `pnpm deploy`.
6. Build Lootr with the deployed Worker origin:
   `flutter build apk --dart-define=LOOTR_REPORT_ENDPOINT=https://<worker>.workers.dev`

Invocation logs and automatic traces stay disabled because attachment paths are
public bearer URLs. The Worker emits allowlisted operational JSON logs without
descriptions, diagnostics, attachment keys, IP addresses, or credentials.
