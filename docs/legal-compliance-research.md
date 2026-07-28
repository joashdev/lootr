# Legal and Compliance Research — Lootr

**Last checked:** 2026-07-28
**Scope:** A Philippine-published, privacy-first personal-finance app distributed through Apple App Store and Google Play. V1 is offline-only with no account, bank connection, or developer-operated sync. V2 may add optional accounts with NestJS and PostgreSQL synchronization and backup. AI is optional and on-device.

> This is product-compliance research, not legal advice. The release owner must
> verify the publisher, target markets, and final product behavior before launch.

## 1. Bottom line

| Area | V1 offline-only | V2 synchronization and backup |
|---|---|---|
| Public documents | Privacy Policy, Terms, and support contact | Update for accounts, processors, transfers, deletion, retention, and subscriptions |
| Consent and lawful basis | Assess each support, purchase, or telemetry use | Document one basis for each purpose |
| User controls | Local edit, export, record deletion, and app-data removal | Add access, correction, export, objection, and account deletion |
| Stores | Apple privacy label, Google Data safety, and age forms | Update all declarations before network features start |
| Governance | Privacy contact, SDK audit, and incident register | Add DPO, registration assessment, PIA, processor contracts, and breach plan |
| International rules | Assess each target store and data flow | Assess EU and UK transfers and CCPA thresholds |

### V1: offline-only launch

Lootr should launch with:

1. Publish a **Privacy Policy** in each store and inside the app.
   Apple and Google require this notice even when the operator collects no user data.
   See [Apple App Review Guidelines §5.1.1](https://developer.apple.com/app-store/review/guidelines/) and [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).
2. **Terms of Use** must define eligibility, user duties, prohibited use,
   disclaimers, data-loss risk, liability, governing law, and support.
   Lootr uses Apple's standard EULA for Apple downloads.
   A future custom EULA must include [Apple's minimum terms](https://www.apple.com/legal/internet-services/itunes/dev/minterms/).
3. Complete accurate **App Store Privacy** and **Google Play Data safety** declarations.
   Base each answer on the shipped binary and every third-party SDK.
   See [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) and [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).
4. Complete the **Google Play Financial features declaration**.
   Select the truthful category for the shipped functions.
   “Other” can fit a bookkeeping tool that does not provide a regulated financial service.
   See the [Google Play Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271?hl=en).
5. Complete accurate **age and target-audience declarations**.
   Do not select child age groups unless the product is designed for children.
   See [Google target audience](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en) and [Apple age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).
6. Provide local record deletion controls.
   Users can remove all app data through their device.
7. Provide local data export controls.
8. Explain that Lootr cannot delete data that it never receives.
9. Add a clear product boundary. Lootr is a recordkeeping and budgeting tool.
   It is not a bank, payment service, lender, fiduciary, or professional adviser.

The V1 privacy claim must be narrow and testable.
Use: “Your financial records remain on this device and are not sent to Lootr.”
Do not claim that no data leaves the device when an app component makes network requests.
Check billing, updates, support, diagnostics, fonts, remote configuration, and all SDKs.

### V2: optional sync and backup

Do not enable V2 until Lootr also has:

- a V2 privacy notice and just-in-time sync disclosure.
- a documented lawful basis for each processing purpose.
- account and server-data deletion paths, including in-app initiation and Google’s external deletion URL.
- access, correction, data export, data portability, objection, consent withdrawal, and complaint handling.
- defined retention and backup-deletion schedules.
- a data protection officer or privacy contact and an NPC registration assessment.
- processor agreements and a subprocessor inventory.
- international-transfer analysis and contractual safeguards.
- a privacy impact assessment.
- a tested personal-data breach response plan.
- server-side security, audit logging, access control, encryption, and restoration controls matching the published promises.

## 2. Privacy Policy: required contents

The Philippine NPC defines the information that a data subject must receive.
This information includes the data, purposes, legal basis, method, recipients, controller contact, retention, and rights.
The notice must also explain automated access and its effects.
See the [NPC right to be informed](https://privacy.gov.ph/the-right-to-be-informed/).

Apple requires disclosure of collection, use, third-party protection, retention, deletion, and consent withdrawal.
See [Apple App Review Guidelines §5.1.1](https://developer.apple.com/app-store/review/guidelines/).

Google requires full disclosure of data access, collection, use, sharing, secure handling, and deletion.
See the [Google User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en).

The notice should therefore contain:

| Section | V1 offline-only | V2 synchronization and backup |
|---|---|---|
| Controller | Joashdev and private contact method | Add any required EU or UK representative |
| Data categories | Local financial entries, preferences, support data, and diagnostics | Add accounts, auth, financial records, IP logs, support, and purchases |
| Collection method | User entry, import, and local processing | Add app upload, API sync, support, and purchase validation |
| Purposes | Local features, support, legal duties, and security | List account, sync, backup, support, billing, and compliance separately |
| Lawful basis | Identify a basis for each online V1 purpose | Use contract, legal duty, assessed interest, or consent as applicable |
| Sharing and processors | Name or group actual SDKs and services | List hosting, email, observability, support, and payment providers |
| International transfers | State only transfers that occur in support and store flows | Countries and regions, transfer mechanism, and access to safeguards |
| Retention | Local data remains until record or app-data removal | Add periods for accounts, backups, logs, support, and legal records |
| Rights and controls | Local edit, export, deletion, and private contact | Add access, correction, objection, portability, complaint, and appeal |
| Children | Intended audience and minimum age | Same, plus parental-consent process if minors are deliberately served |
| Automated processing and AI | Optional on-device suggestions have no legal effect | Disclose server profiling or automation before launch |
| Security | Accurate high-level safeguards without promising absolutes | Encryption, access controls, incident handling, processor safeguards, and backup protections at a truthful level |
| Changes and contact | Effective date, material-change notice method, contact and NPC complaint route | Add EU, UK, and California routes if applicable |

Use a short notice at onboarding or when sync starts.
Keep the complete notice in Settings and at a stable public URL.
A privacy notice is not consent.

## 3. Philippine Data Privacy Act and NPC requirements

The Data Privacy Act applies to the processing of personal information.
It requires transparency, legitimate purpose, proportionality, security, rights, retention limits, and processor accountability.
See [Republic Act No. 10173](https://privacy.gov.ph/data-privacy-act/) and the [implementing rules](https://privacy.gov.ph/implementing-rules-regulations-data-privacy-act-2012/).

Practical implications:

- **V1 local records:** The notice must state when the publisher cannot access the financial database.
  The publisher can still control support messages, account data, website submissions, or received diagnostics.
- **Lawful basis:** consent is not the only basis. A service can process data necessary to perform a contract, comply with law, or pursue a properly assessed legitimate interest. Consent should be specific, informed, freely given, evidenced, time-bounded to the declared purpose, and withdrawable where it is used ([DPA IRR §§18–19](https://privacy.gov.ph/implementing-rules-regulations-data-privacy-act-2012/), [NPC legitimate-interest guidelines](https://privacy.gov.ph/wp-content/uploads/2024/01/NPC-Circular-No.-2023-07_Guidelines-on-Legitimate-Interest_13-December-2023.pdf)).
- **DPO:** the NPC describes appointing a DPO as a legal requirement for personal information controllers and processors. For a small publisher this may be the founder, if properly designated and able to perform the role ([NPC: Appointing a DPO](https://privacy.gov.ph/appointing-a-data-protection-officer/)).
- **Registration:** Registration can be mandatory under NPC Circular 2022-04.
  The thresholds include personnel, sensitive-data scale, and processing risk.
  Always assess an automated decision or profiling system.
  See the [NPC registration FAQ](https://privacy.gov.ph/pips-and-pics/faqs/).
- **Processors and transfers:** Lootr remains accountable for personal data that it sends to processors.
  This duty applies inside and outside the Philippines.
  Contracts or other reasonable controls must provide comparable protection.
  See [DPA §14 and §21](https://privacy.gov.ph/data-privacy-act/) and [NPC outsourcing guidance](https://privacy.gov.ph/wp-content/uploads/2022/01/NPC_AdvisoryOpinionNo._2017-015.pdf).
- **Retention:** Use a clear period when possible.
  Delete data when its purpose ends, unless law or a valid claim requires retention.
  Disposal must prevent more access ([DPA IRR §19](https://privacy.gov.ph/implementing-rules-regulations-data-privacy-act-2012/)).
- **Rights requests:** Provide simple channels for information, objection, consent withdrawal, access, correction, erasure, restriction, portability, complaint, and damages.
  NPC guidance generally requires action within 30 working days after a complete request.
  One notified extension of up to 15 working days can apply.
  A machine-readable JSON or CSV export can support portability.
  See the [NPC data-subject-rights advisory](https://privacy.gov.ph/wp-content/uploads/2026/05/SGD-Advisory-DS-Rights-29-Jan-2021.pdf).
- **Security and privacy by design:** Maintain a processing inventory, privacy impact assessment, risk controls, access restrictions, secure disposal, continuity plan, and staff procedures.
  V2 must follow the current NPC security circular before launch.
  See [NPC Circular 2023-06](https://privacy.gov.ph/wp-content/uploads/2024/03/NPC-Circular-Repeal-16-01-Signed.pdf).
- **Breach response:** The incident plan must support assessment and notification within 72 hours.
  NPC Circular 16-03 defines three conditions for mandatory notice.
  These conditions cover the data, unauthorized acquisition, and risk of serious harm.
  Lootr remains responsible when a processor causes the breach.
  Processor contracts must require immediate escalation.
  See [NPC Circular 16-03](https://privacy.gov.ph/wp-content/uploads/2022/01/sgd-npc-circular-16-03-personal-data-breach-management.pdf) and [NPC Breach Reporting](https://privacy.gov.ph/pips-and-pics/breach-reporting/).

## 4. App-store obligations

### Apple

- Every app needs an accessible in-app privacy-policy link.
  App Store Connect also needs the URL.
  See [App Review Guidelines §5.1.1](https://developer.apple.com/app-store/review/guidelines/).
- App Privacy answers must include data collected by Lootr and third-party SDKs and must be updated when practices change ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)).
- If the app creates accounts, users must be able to initiate complete account deletion inside the app ([Apple account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)).
- If the app has no significant account-based features, Apple says it should work without login. This supports keeping V1 account-free and making V2 sync optional ([App Review Guidelines §5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/)).
- Apple applies special submission rules to financial trading, investing, and money management apps.
  The submitting institution must hold required licenses.
  This rule creates an **App Review risk that requires pre-submission clarification**.
  Review notes must describe Lootr as local recordkeeping if that description stays accurate.
  See [App Review Guidelines §3.2.1(viii)](https://developer.apple.com/app-store/review/guidelines/).

### Google Play

- All published apps must complete Data safety and link a privacy policy, even if no data is collected. SDK collection is the developer’s responsibility ([Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)).
- Personal and financial information is “personal and sensitive user data” under Play policy. Collection and use must be expected, minimized, disclosed, secured in transit, and not sold ([Google User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)).
- If account creation exists, provide both an in-app deletion path and an external web resource, delete associated data, and disclose any legitimate retention ([Google account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN)).
- Complete the Financial features declaration for every release track in scope and update it when the product changes ([Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271?hl=en)).
- Google defines financial services broadly as management or investment of money and requires compliance with regional rules. Lootr is not a loan app on the stated scope, so loan-specific APR and licensing rules do not apply unless the product changes ([Google Financial Services policy](https://support.google.com/googleplay/android-developer/answer/9876821?hl=en-GB)).

## 5. GDPR, UK GDPR, and California

### European Union and European Economic Area

GDPR can apply to a non-EU publisher that offers services to people in the EU.
Assess EU store availability and EU-directed activity before launch.
Small size does not give a general exemption.

For V2 EU users, implement:

- an Article 13 or 14 notice with all required information.
  See [European Commission obligations](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/obligations_en).
- a recorded basis for each purpose.
  Optional analytics or marketing can require consent.
- processor agreements, data protection by design and default, risk-based security, rights handling, erasure, and portable export.
- EU transfer safeguards for Philippine or other non-EEA processing.
- an EU representative assessment under Article 27 when the extra-territorial exemption is not available.

GDPR can require regulator notice within 72 hours when a breach risks individual rights.
High risk can also require notice to affected people.
Keep a breach log even when no notice is required.
See [European Commission GDPR obligations](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/obligations_en).

### United Kingdom

If Lootr targets UK users, complete a separate UK assessment.
Restricted transfers can require a UK transfer mechanism.
See [ICO privacy information](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/) and [ICO international transfers](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/international-transfers/).
UK rules changed under the Data (Use and Access) Act 2025.
Do not copy an EU clause set without a UK review.

### California

CCPA and CPRA are unlikely to apply to an early-stage Lootr.
The laws use revenue, data-volume, and data-sale thresholds.
See the [California Attorney General CCPA FAQ](https://oag.ca.gov/privacy/ccpa).
Reassess the thresholds each year.

If CCPA applies, provide the required notices and rights controls.
These controls include requests to know, delete, correct, and opt out.
Lootr plans no sale or sharing for cross-context behavioral advertising.
This claim must cover all SDKs and website trackers.
See [California AG CCPA](https://oag.ca.gov/privacy/ccpa) and [CPPA notice guidance](https://cppa.ca.gov/pdf/general_notices.pdf).

## 6. Children and age

COPPA applies to covered online services that collect personal information from children under 13.
It can also apply when a general service has actual knowledge of such collection.
Covered operators need a child-specific notice and verified parental consent.
They also need parental controls, data minimization, and security.
See the [FTC COPPA overview](https://www.ftc.gov/legal-library/browse/statutes/childrens-online-privacy-protection-act) and [FTC applicability guidance](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-not-just-kids-sites).

Market Lootr to adults.
Do not select children in store target-audience forms.
Align the 18+ Terms rule with Apple and Google settings.
If Lootr supports minors, add parental controls before collection.

## 7. Terms, financial boundary, and monetization

### Terms and EULA

The Terms should:

- identify the legal publisher and support contact.
- apply Apple's standard EULA to Apple downloads.
- state eligibility and minimum age.
- prohibit unlawful use, tampering, credential abuse, and interference.
- state that users own their entered financial data.
- explain local-only storage and user-controlled backups and exports.
- explain the risk of loss from device loss, uninstall, forgotten keys, corruption, or failed backup.
- separate the Terms from the Privacy Policy.
- define paid features and renewal, cancellation, and refund handling if applicable.
- set the no-advice and no-financial-service boundary.
- disclaim warranties and limit liability only to the extent permitted by mandatory consumer law.
- preserve statutory consumer rights rather than purporting to waive them.
- explain suspension, termination, and V2 account deletion.
- state governing law and dispute terms.
- include Apple's required clauses if a custom EULA replaces its standard EULA.

### Financial disclaimer and feature boundary

No primary source reviewed imposes a universal magic-word disclaimer on a local budgeting ledger. The safer control is keeping the product out of regulated activity:

- no custody or movement of money.
- no bank impersonation or bank connection.
- no lending, credit brokering, insurance, securities, crypto, or payments.
- no personalized investment, tax, accounting, or professional financial advice.
- no claims that forecasts are guaranteed or suitable for a user’s circumstances.
- no AI output that automatically changes records or makes decisions with legal or similarly significant effects.

A disclaimer supports this boundary but does not change actual functions.
Use review notes to explain Lootr's local recordkeeping scope to Apple.

### Subscriptions, purchases, cancellations, and refunds

V1 is free and has no purchases.
Assess these provisions before Lootr charges for digital features or cloud synchronization:

- Apple generally requires In-App Purchase for digital features and subscriptions.
  It also requires clear subscription information and ongoing value.
  See [Apple App Review Guidelines §3.1.2](https://developer.apple.com/app-store/review/guidelines/).
- Google generally requires Play Billing for paid in-app functionality, including cloud storage and financial-management software ([Google Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)).
- Google requires clear price, billing frequency, renewal, trial, and cancellation terms.
  Refunds must follow store policy and applicable law.

Keep **subscription cancellation** separate from **account deletion**.
Subscription cancellation must not delete financial records without clear notice.
Account deletion must explain what happens to an active store subscription.

Before Philippine online sales, show the legal trader identity and address.
Also show contact, price, service functions, complaint route, and receipt terms.
Preserve mandatory consumer remedies.
Verify current DTI Trustmark duties before paid subscriptions.

## 8. Required implementation and documentation backlog

### Before V1 public release

1. [ ] Confirm the store developer identity, privacy contact, and storefront countries.
2. [ ] Inventory all Flutter packages, native SDKs, permissions, network endpoints, diagnostic tools, fonts, and support flows.
3. [ ] Inspect network traffic from the release build.
4. [ ] Use the inspection result for the store data declarations.
5. [ ] Publish the V1 Privacy Policy at a stable HTTPS URL.
6. [ ] Show the Privacy Policy in Settings.
7. [ ] Publish the Terms.
8. [ ] Show the Terms in Settings.
9. [ ] State that Apple's standard EULA applies to Apple downloads.
10. [ ] Verify local export, record deletion, and device app-data removal guidance.
11. [ ] Complete all Apple and Google privacy, financial, audience, rating, and advertising declarations.
12. [ ] Prepare Apple App Review notes for the offline recordkeeping scope.
13. [ ] Apply the 18+ policy in the app and store.
14. [ ] Add a “not a bank or adviser” notice near advice-like features.
15. [ ] Keep a private register for privacy requests and incidents.
16. [ ] Verify the final product boundary against Apple §3.2.1(viii).

### Before enabling V2 for any user

1. [ ] Complete a data-flow inventory.
2. [ ] Complete a privacy impact assessment.
3. [ ] Choose and document the legal basis for every purpose.
4. [ ] Keep optional analytics and marketing separate from synchronization.
5. [ ] Designate the data protection officer or privacy owner.
6. [ ] Assess NPC registration or sworn-exemption filing.
7. [ ] Sign processor agreements.
8. [ ] Keep a current subprocessor list.
9. [ ] Assess international transfers for each processor location.
10. [ ] Define retention periods for accounts, deletion queues, backups, logs, one-time-password records, support, and purchases.
11. [ ] Implement in-app account deletion and Google's external deletion page.
12. [ ] Implement server erasure, backup expiry, and a retained-data exception record.
13. [ ] Implement authenticated access, correction, data export, objection, consent withdrawal, and request tracking.
14. [ ] Write and test the 72-hour breach notification runbook.
15. [ ] Update all legal notices, store forms, declarations, and review notes before the V2 release.
16. [ ] Reassess representation, privacy-law thresholds, and child-privacy duties for the launch territories.

## 9. Facts to verify before the related feature starts

1. Store developer identity and private support contact.
2. Exact V1 storefront countries and whether EU, UK, or California users will be actively targeted.
3. Final SDK and dependency inventory, permissions, diagnostics, analytics, remote configuration, fonts, and support tools.
4. Android disables app backup.
   iOS can include encrypted app data in an Apple backup under the user's settings.
5. Any future monetization model.
6. Minimum age and product audience decision.
7. Exact on-device AI model, inputs, outputs, logging, and whether any model or prompt is downloaded remotely.
8. For V2: hosting region, subprocessors, authentication provider, logging, observability, backup lifecycle, deletion design, and support system.
9. Whether any feature could be characterized as personalized financial advice or “money management” performed for users rather than a user-operated ledger.
