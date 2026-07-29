# Legal and Privacy Compliance — Personal Finance App

Defines Lootr's V1 legal disclosures, privacy controls, publication surfaces, and V2 compliance gates.
References: `product-strategy.md` (privacy and scope), `security-model.md` (data boundaries and deletion), `public-alpha-release.md` (feedback processing), `legal-compliance-research.md` (primary-source legal research).

---

## 1. Purpose and Boundary

This specification converts Lootr's privacy promise into product requirements.
It is an engineering and publication baseline. It is not legal advice.

The policy set covers:

- the official Android and iOS application.
- the static Lootr website and GitHub release flow.
- optional public feedback through Cloudflare and GitHub.
- current device permissions and local processing.
- future account, sync, backup, household, subscription, and server processing.

V1 and V2 must not share one vague disclosure.
V1 is a local ledger with narrowly initiated network features.
V2 makes the operator a controller of account and financial data.
V2 cannot launch until its separate gates are complete.

## 2. Canonical Legal Package

| **Document or notice** | **Canonical surface** | **Required access** | **Status** |
|---|---|---|---|
| Privacy Policy | `website/src/pages/privacy.astro` | Public URL, store listing, in-app About | Implemented |
| Terms of Use | `website/src/pages/terms.astro` | Public URL, store listing, in-app About | Implemented |
| Open-source license | `LICENSE` + `NOTICE` | Repository and in-app About | Implemented |
| Third-party notices | Flutter license page | In-app About | Implemented |
| Security reporting | `SECURITY.md` | Repository and feedback warning | Implemented |
| Feedback notice and consent | Feedback composition and preview flow | Immediately before submission | Implemented |
| App-store privacy declarations | Apple App Privacy + Google Play Data safety | Store consoles before submission | Launch task |
| Operator and privacy contact | Legal publisher name + private contact | Public policy and in-app About | Legal name required |
| Incident response plan | Private operating procedure | Before V2 server processing | V2 blocker |

The published policy URLs are:

```text
https://lootr-bhl.pages.dev/privacy
https://lootr-bhl.pages.dev/terms
```

The website, store listing, and app must point to the same URLs.
A release check must fail if a URL fails or loses its effective date.

## 3. V1 Data Inventory

### 3.1 Device-only data

The official V1 app processes the following locally:

| **Category** | **Examples** | **Purpose** | **Default retention** |
|---|---|---|---|
| Financial ledger | Accounts, balances, transactions, budgets, goals, debts | User-requested tracking and reports | Until record or app-data removal |
| User content | Payees, categories, notes, imported Cashew content | Recordkeeping and migration | Until record or app-data removal |
| Receipt content | Selected or captured image, extracted text, parsed values | User-requested OCR | Until record or app-data removal |
| Local assistance | Parsed text, OCR and AI logs, confidence, processing metadata | Explain and audit suggestions | Until app-data removal |
| Settings | Theme, currency, notification and security preferences | Configure the app | Until app-data removal |
| Diagnostics | Allowlisted events, sanitized app stack frames | Local troubleshooting | Seven days, bounded to 512 KiB |

Exported backups, CSV files, and screenshots leave the app's sandbox at the user's direction. The app must warn that the destination may not be encrypted and that deletion from Lootr does not delete external copies.
Android excludes Lootr app data from operating-system backup.
On iOS, encrypted app data can enter an Apple device backup under the user's settings.

### 3.2 Deliberately initiated external processing

| **Feature** | **Recipient** | **Data** | **Disclosure and control** |
|---|---|---|---|
| Public feedback | Cloudflare, GitHub, public internet | Approved report fields and optional diagnostics | Exact preview + two confirmations |
| Feedback screenshot | Cloudflare R2, public link in GitHub | One re-encoded image | Separate opt-in. Enable only with a 30-day lifecycle |
| Human challenge | Cloudflare Turnstile | Network and device challenge signals | Just-in-time notice in Privacy Policy |
| Voice input | OS-selected speech provider | Microphone audio and transcription context | Runtime permission + provider caveat |
| Legal and source links | Cloudflare Pages, GitHub | Ordinary web request metadata | User taps external link |

“On-device voice recognition” must not be claimed unless the implementation both requests and verifies offline recognition on every supported platform. The current integration delegates recognition to the operating system and may use a network service.

## 4. Privacy Policy Requirements

The Privacy Policy must state in plain language:

- the responsible operator and a working private contact method.
- what stays on-device and what leaves only after a deliberate action.
- categories, purposes, recipients, retention, and security controls.
- that V1 has no Lootr account, cloud ledger, advertising, or automatic analytics.
- the optional feedback, screenshot, Turnstile, speech, hosting, and GitHub flows.
- applicable lawful purposes and the user's ability to withdraw optional consent.
- data-subject choices and rights, including access, correction, erasure, objection, portability, and complaint.
- international processing by service providers.
- age and children boundary.
- material-change notification, especially before V2.

A privacy notice is not a consent checkbox.
Lootr must ask separately when consent is the chosen basis for optional processing.
Refusal of an optional feature must not block manual ledger use.
Optional features include public feedback, screenshots, voice input, camera access, photo access, and notifications.

## 5. Terms of Use Requirements

The Terms must:

- identify the operator and scope while preserving mandatory consumer rights.
- distinguish official releases from independent AGPL forks.
- state that Lootr is a recordkeeping tool, not a bank, payment service, fiduciary, adviser, accountant, or tax service.
- state that calculations, OCR, voice transcription, forecasts, and suggestions require user verification.
- describe alpha instability, local data-loss risk, and the user's backup responsibility.
- set a clear age boundary.
- cover acceptable use, user content, public feedback, third-party services, termination, disclaimers, liability, governing law, and changes.
- keep AGPL rights separate and avoid adding restrictions to licensed code.
- state that the current alpha has no subscription or in-app purchase.

Paid functionality requires a Terms update before sale.
The update must include the trader identity, physical address, price, taxes, renewal terms, cancellation terms, and refund terms.
It must also include complaint, compatibility, continuity, and store billing rules.

## 6. Consent and Permission Design

Consent must be specific, informed, freely given, recorded when required, and as easy to withdraw as to provide. Lootr uses contextual choice instead of one bundled legal checkbox:

```text
Manual ledger ───────────────────────────── no optional consent
Camera and photo receipt ──────────────── runtime permission
Voice entry ────────────────────────────── mic + speech permission
Public issue text and diagnostics ─────── preview + public confirmation
Public screenshot ──────────────────────── separate screenshot confirmation
Future cloud sync ──────────────────────── separate V2 enrollment and notice
Future marketing and analytics ───────── separate opt-in if ever introduced
```

Permission prompts must explain the immediate feature. Platform strings must not claim stronger privacy properties than the code enforces. Denial must have a manual fallback and neutral copy.

## 7. Retention, Deletion, and Rights

Users exercise V1 rights through local product controls:

- inspect and edit records in the app.
- export a portable, human-readable copy.
- delete records or remove app data through the device.
- remove optional permissions in system settings.
- request action on information controlled by the feedback and website operator.

The operator must keep a private request log.
The operator must use the legal response period.
For Philippine requests, the target is 30 working days.
The operator can use one notified 15-working-day extension when permitted.

Retention rules:

| **Data** | **Retention rule** | **Deletion limit** |
|---|---|---|
| Local ledger | User-controlled | Record deletion, app uninstall, or device storage removal |
| Local diagnostics | Seven days, 512 KiB rotating cap | Included in a report only after preview |
| R2 screenshots | Configured storage lifecycle | Screenshot upload requires a verified 30-day lifecycle |
| GitHub issue content | Indefinite public project history | Users can request correction or removal |
| Relay operational logs | Cloudflare plan and account settings | Never include content, IP, tokens, or attachment keys |

V2 must implement authenticated export, correction, objection, and consent withdrawal.
V2 must also implement account deletion, server-data deletion, backup purge, household ownership, and processor coordination.
These controls must exist before V2 processes real user data.

## 8. Security and Incident Governance

Before public store submission, the operator must:

1. Designate Joashdev as the V1 privacy owner.
2. Publish a private contact.
3. Maintain a data inventory, processing record, retention schedule, and vendor list.
4. Complete a privacy impact assessment for feedback.
5. Complete a privacy impact assessment for receipt and voice processing.
6. Complete a privacy impact assessment for each V2 system.
7. Verify SQLCipher and secure key storage in production artifacts.
8. Keep logs free of financial and authentication content.
9. Document access controls, credential rotation, backup recovery, and secure disposal.
10. Maintain a breach plan, escalation path, evidence log, and notification decision record.

Before V2, processor contracts must define instructions, security, locations,
subprocessors, rights support, deletion, audits, and breach reports.

A qualifying Philippine breach can require notice within 72 hours.
The operator must notify the National Privacy Commission and affected people.

## 9. Children and Sensitive Financial Data

Lootr is intended for adults aged 18 or older. Store metadata, onboarding, Privacy Policy, and Terms must use the same boundary. The app must not intentionally profile or market to children.

Personal finance records can reveal economic circumstances.
Notes or receipts can contain other sensitive details.
The product must minimize the transmission of free-form text.
The product must never request government identifiers or bank credentials.
The product must tell users not to put real financial content in public reports.

If the product later supports minors or family accounts, launch is blocked on a dedicated parental-consent and child-privacy design review.

## 10. App-Store Declarations

The release owner must answer store questionnaires from the shipped binary and enabled services, not from roadmap intent.

### 10.1 Apple

1. Provide the public Privacy Policy URL.
2. Complete App Privacy answers for operator and third-party collection.
3. Include required privacy manifests and required-reason APIs from all SDKs.
4. Verify camera, photo, microphone, speech, and notification purpose strings.
5. State that Apple's standard EULA applies to Apple downloads.
6. If account creation ships, provide in-app account deletion.

### 10.2 Google Play

1. Provide the public Privacy Policy URL in Play Console and in the app.
2. Complete Data safety for the actual feedback, screenshot, speech provider, and future synchronization flows.
3. Complete the content rating, target audience, advertising, financial feature, and app access declarations.
4. If accounts ship, supply a deletion mechanism and a web deletion URL.
5. Keep permission requests limited to visible user-requested features.

The V1 assertion is not simply “no data collected.”
Evaluate optional feedback under each store's current definitions.
Also evaluate third-party speech and Turnstile services.

## 11. V2 and Monetization Launch Gates

| **Capability** | **Required before enablement** | **Initial status** |
|---|---|---|
| Email and one-time-password account | Updated notice, lawful basis map, account deletion, support contact, processor inventory | Blocked |
| Cloud synchronization and backup | PIA, retention schedule, processor contracts, transfer review, encrypted transport and storage, rights workflows | Blocked |
| Household sharing | Member notices, ownership and deletion rules, invitation controls, access audit, child-use decision | Blocked |
| Receipt upload | Purpose and retention notice, access control, deletion, processor and subprocessor inventory | Blocked |
| Push notifications | Token inventory, provider disclosure, permission design, deletion | Blocked |
| Cloud AI | New review, data minimization, provider contract, training prohibition, separate choice | Blocked |
| Subscription and in-app purchase | Trader identity and address, billing disclosures, renewal, cancellation, refund, store terms, tax and receipt handling | Blocked |
| Analytics and crash SDK | PIA, minimization, store declarations, retention, required opt-in, no session replay | Blocked |

No roadmap document may be treated as permission to process V2 data. The release owner must explicitly move each gate to Done with evidence.

## 12. Acceptance Criteria and Open Legal Review

The document baseline is complete when:

- Privacy and Terms pages build as static, readable, mobile-friendly pages.
- the website footer and privacy promise link to the real policies.
- the About screen opens both policies and retains license and third-party notices.
- iOS purpose strings accurately describe camera, photos, microphone, and speech.
- feedback disclosures match the implemented Cloudflare and GitHub flow.
- V1 and V2 practices are clearly separated.
- automated tests verify legal links and the website build.
- the release owner completes store forms from a release data-flow audit.

The following release actions remain:

1. Deploy the Privacy Policy and Terms at the public URLs.
2. Replace the public project name with the legal publisher name.
3. Enter the same legal publisher name in each store.
4. Confirm that the private GitHub contact is monitored.
5. Verify the 30-day R2 lifecycle before screenshot upload starts.
6. Verify the Cloudflare Worker log setting.
7. Complete the Apple and Google declarations for the final binary.
8. Confirm that the app and store use an 18+ audience.
9. Review provider terms before each release.
10. Add the required address before paid sales or a custom EULA.
11. Assess NPC registration before V2 processes user data.

These actions must remain visible in release planning.
Published text does not prove operational compliance.
