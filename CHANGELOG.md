# Changelog

All notable changes to the published schemas are recorded here. Schema-level
revisions are tracked in the `<xs:schema version="...">` attribute on each
file; this file captures the human-readable history.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/),
and the repository follows [Semantic Versioning](https://semver.org/) at the
**per-schema** level (C360 3.0, VRG / TTDR 3.3.0). The repo itself is not
versioned.

## 2026-10-13 — gate-error envelope, header-operation requests, discounts

Found by validating the request bodies and saved examples of the published API portal against
these schemas, then confirming each difference in the code of both service generations.

### Corrected
- **Gate errors (`E888` / `E899`) in every response schema.** The older service generation
  returns `<WEBSERVICE><RESPONSE><RESPONSE_CODE>` alone (no `RESPONSE_DATE`, no `ResponseId`);
  the loyalty-app generation returns a bare `RESPONSE` with `RESPONSE_DATE` and
  `RESPONSE_CODE`. Six schemas rejected the older form; all now accept both.
- **`getOrderHeaderDetailsC` response:** per-line `ITEM_DISCOUNT` / `DISCOUNT` block declared
  (emitted by both generations, previously undeclared).
- **`getOrderHeaderDetailsB` response:** `PRIMARY_PHONE` declared.
- **`getOrderHeaderDetailsB` and `getOrderHeaderDetailsC` requests** rebuilt from the code:
  order-free, `ORDER_STATUS` and (B) `ORDER_ID` added, `SYSTEM_REFERENCE` is an open value,
  dates and limit are strings (`RECORD_LIMIT` default 25, capped at 100).
- **`findCustomersB` request:** empty filter elements (for example `<ZIP_CODE/>`) validate.
- **`updateCustomerB` request:** elements may appear in any order within `CUSTOMER`, `CONTACT`
  and `CROSS_REFERENCE`, as the service accepts. The fixed order rejected valid requests.

### Behaviour now documented correctly
- **The `PRODUCTS` wrapper is not read.** Only direct children of the request root are read, so
  a `PRODUCT_ID` nested inside `PRODUCTS` is ignored. Send a bare `PRODUCT_ID`
  (`getOrderHeaderDetailsC`). An earlier revision described the wrapper as accepted.
- **`getOrderHeaderDetailsB` requires a customer** (`E110`) and has no product filter. Its
  request example that searched by product was wrong and is replaced.

### Added
- A gate-error example per operation and three `getOrderHeaderDetailsB` request examples.

## 2026-10-12 — customer, coupon and getOrderDetailsB audit

Every schema below was checked against the service implementation. Before this change the
published files rejected real traffic; the changes are corrections, not new behaviour.

### Breaking for anyone validating against the earlier files
- **`findCustomersB` and `updateCustomerB` no longer declare a `targetNamespace`.** The
  services emit un-namespaced XML and match request elements by local name only, so the
  namespaced schemas could not validate any real response.
- **Coupon type value corrected to `NONSERIALIZE`** in `couponAuthentication` and
  `couponPost` requests. The previously published `NON-SERIALIZE` is rejected by the
  service (`E842`).
- **`customerCertificateSearch` response restructured**: rows are grouped under
  `LOYALTY_COUPONS` and `MARKETING_COUPONS`; the date element is `COUPON_REDEEMED_DATE`.
- **`getOrderDetailsC` request**: no element is schema-required. The service requires
  `STORE_ID` except on the LayAway branch; `ORDER_ID`, `REQUEST_DATE`, the date range and
  `REGISTER_NUMBER` are optional. Added `ORDER_STATUS`,
  `LAYAWAY_NUMBER` and the three tender-token filters.

### Corrected
- `findCustomersB` response: declares the `ResponseId` attribute and the per-customer
  `CUSTOMER` block (previously inexpressible). "Not found" is `E163` on the loyalty-app
  generation and `E105` on the older one; both are documented.
- `getPersonCompleteDetailsB`: a success response (no `RESPONSE_CODE`) is now expressible;
  multiple `CUSTOMER` blocks allowed; request patterns that rejected every real e-mail,
  phone and postal value removed; request fields `PROVINCE`, `STORE_ID` and
  `REQUEST_DATE` added; the unread `CUSTOMER` anchor form removed.
- `updateCustomerB` response: `ResponseId`, `RESPONSE_DATA`, order-free and repeatable
  content, complete code catalog. Request: e-mail pattern fixed; documents that an update
  fully replaces name, gender, birthday and cashier.
- `couponAuthentication` / `couponPost` responses: success responses now validate;
  undeclared emitted elements added; status codes are open strings with the value domain
  documented.
- `getOrderDetailsB`: documented as the same implementation as `getOrderDetailsC` with
  `CUSTOMER_ID` required; schemas rebuilt to match.
- `getPersonCompleteDetailsB-openapi.json`: header names and examples corrected.

### Added
- 97 synthetic examples across these seven operations, covering each request pattern,
  full and sparse success responses, and each distinct error envelope.
- Verification-status table in the README.

### Status change
- `customerCertificateSearchGC` marked **unverified / legacy**: no operation of that name
  exists in the loyalty-app service generation. Retained unchanged for reference.

### Hygiene
- Removed internal source-file, class and module names and brand-specific identifier
  names from annotations and examples. The CI identifier guard now rejects them and also
  scans `.json` files.

## 2026-10-12

- Order family response schemas rebuilt/verified against live production responses across
  every deployed service generation (PRs #7–#11): error envelopes (RESPONSE_CODE /
  RESPONSE_MESSAGE / RESPONSE_DATA), WEBSERVICE gate-error root, unordered repeat-tolerant
  content models, missing elements (CONTACT block, CUSTOMER_ID, TERMINAL_ID, LEVEL_5 set,
  PLU_NUMBER, EMAIL_ID, per-line ITEM_TAX), corrected element names and types.
- New: getOrderDetailsC layaway alternate-response schema; field-value-domains.md
  (production-observed value vocabularies, generation superset chain, ItemAttributes
  ingestion mapping and per-POS-family vocabularies).
- Hygiene: de-identified annotations and examples for public publication; CI validation
  workflow added (XSD compile + example validation + internal-identifier guard);
  SECURITY.md at root.

## TTDR / VRG 3.3.0 — 2026-10-02

### Added
- Published TTDR 3.3.0 as a sibling of the unchanged TTDR 3.2.2 release with
  a new namespace and fixed `TTDRVersion` value `TTDRV330`.
- Added optional `CStoreLineProfile` line outcomes for motor fuel, EV
  charging, and service entitlements such as car wash.
- Added optional transaction-level `CStoreData` for source provenance,
  privacy-minimized age verification, offers, stored value, service
  entitlements, normalized tender results, mobile-payment context, fleet
  evidence, and audit evidence.
- Added exact decimal quantity and money types for fuel and EV values that
  cannot be represented faithfully by legacy integer fields.
- Added four validating examples, migration and security guidance, and a
  PowerShell validation gate.

### Compatibility and security
- TTDR 3.2.2 remains supported and is not deprecated. Producers must emit the
  namespace and fixed version value negotiated with each consumer.
- The new profile is an outcome projection, not a device, payment, stored
  value, identity, or forecourt control protocol.
- PAN, track/CVV/PIN data, raw EMV cryptograms, date of birth,
  government-ID data, credentials, and reusable plaintext tokens are
  prohibited.

## [Unreleased] — 2026-05-14

### Schema fix
- `findCustomersB-response.xsd`: tightened `<xs:any>` from default namespace
  to `namespace="##other"`. Resolves a Unique Particle Attribution (UPA)
  violation between the optional `STORE_ID` / `CUSTOMER_ID` echoes and the
  trailing wildcard. The schema now loads cleanly in strict XSD parsers
  (xmlschema, libxml2, XMLSpy). Tenant extensions must use a namespace
  other than the response target namespace.

### Product rename
- **BORMC is now C360.** Renamed the top-level directory `BORMC/3.0/` to
  `c360/3.0/`. The product name in README, CHANGELOG, and LICENSE now
  reads "C360" (with "formerly BORMC" notes for searchability). Endpoint
  URLs (`/loyalty-app/control/*`), endpoint names (`findCustomersB`,
  `getPersonCompleteDetailsB`, etc.), and target namespaces are
  unchanged — only the family/marketing name flipped.

### Repository cleanup
- Restructured top-level layout: flattened `BORMC/3.0/` → `c360/3.0/` and
  `schemas/vrg/3.2.2/` → `vrg/3.2.2/`. Removed the redundant `schemas/`
  wrapper.
- Removed the stale `general/` directory; it held an older copy of the TTDR
  schema (last touched 2025-09-08). The authoritative TTDR 3.2.2 schema lives
  at `vrg/3.2.2/TTDR-3.2.2.xsd`.
- Standardized endpoint file naming to `{endpoint}-request.xsd` /
  `{endpoint}-response.xsd` / `{endpoint}-openapi.json` across all C360
  endpoints.
- Moved sample request XML payloads from autogenerated `Untitled*.xml` files
  into per-endpoint `examples/request-sample.xml`.
- Replaced the `getPersonCompleteDetailsB_response.xsd` (incomplete subset,
  ChatGPT-drafted) with the production-bound v3.1 response schema, and folded
  the RESPONSE_CODE documentation block from the deleted file back in.
- Removed the older `getPersonCompleteDetailsB_openapi.json` (broken
  `/mnt/data/` references); the openapi specification now lives at
  `c360/3.0/Customer/getPersonCompleteDetailsB/getPersonCompleteDetailsB-openapi.json`.
- Added `LICENSE`, `.gitignore`, `CHANGELOG.md`, and a full `README.md`.

## TTDR / VRG 3.2.2

### 2025-12-12
- Added `LayawayData` element to the transaction schema (layaway and special
  order information; mapped to `/POS/TRADE/ORDER`).
- Added `PostVoidSale` and `PostVoidReturn` transaction-type enumerations
  (same-day full void of a sale or return; added 2025-11-11).
- Added `PRINT_SMS` delivery method enumeration (message sent via SMS and
  printed).
- `TransactionHistory` element now defaults to `"N"` when unspecified.
- `RegisterType` element now defaults to `"POS"` when unspecified.
- `StoreNumber` element marked `minOccurs="1"`.

### 2025-09-08
- Earlier 3.2.2 revision (now superseded by the 2025-12-12 cut). Retained in
  git history; the file is no longer carried in the repo.

### 2021-03-16
- Original TTDR 3.2.2 cut.

## C360 3.0 (formerly BORMC 3.0)

### 2026-05-14
- `OutputLanguage` element `minOccurs` made optional in the transaction
  schema.
- `PennyRounding` enumeration added.

### 2026-05-13
- `LayawayData` element added to `getOrderDetailsC` with detailed
  documentation.

### 2026-05-12
- `TRANSACTION_TYPE` element added to `getOrderDetailsC`; documentation
  refreshed.

### 2026-05-11
- `OriginalTransactionDate` documentation clarified (date format).

### 2026-05-10
- `LayawayData` element added; transaction schema updated.

### 2026-05-09
- `REQUEST_DATE` and `STORE_ID` `minOccurs` updated.
- XSD schemas for `getOrderHeaderDetailsB` added.

### 2026-05-08
- `getOrderDetailsC` response XSD schema added.

### 2026-05-07
- `FROM_DATE` and `THRU_DATE` typed as `xs:date`.

### 2026-05-06
- `getOrderDetailsC` request XSD schema added.

### Earlier 2026
- Initial set of BORMC 3.0 endpoint schemas (`findCustomersB`,
  `updateCustomerB`, `getPersonCompleteDetailsB`) committed. (BORMC was
  later renamed to C360.)
