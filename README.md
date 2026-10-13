# TransactionTree Integration Schemas

Public XML Schema Definitions (XSDs) and OpenAPI descriptions for
TransactionTree's customer-facing services. Integrators use this repo to
generate XML payloads, validate them locally before submitting, and stub
client SDKs.

Two product families are published here:

| Family | Path | What it describes |
|---|---|---|
| **C360** (formerly BORMC — Business Office Receipt Management Center) — loyalty + order API | `c360/3.0/` | Form-encoded POST endpoints under `/loyalty-app/control/*` that exchange XML inside the `XmlInput` form field. |
| **VRG / TTDR** (TransactionTree Digital Receipt — VRG ingest) | `vrg/3.2.2/`, `vrg/3.3.0/` | Versioned Digital Receipt envelopes POSTed to `vrgs.io` (prod) and `receiptx.com` (dev/test) for retailer receipt ingest. |

These schemas are documentation-grade — the runtime services validate input
in code rather than against the XSDs, so the schemas describe both the
structural shape **and** the business rules enforced downstream (response
codes, format constraints, conditional requirements). Keep that distinction
in mind: an XML payload can be XSD-valid and still get a code-level
rejection.

---

## Publication policy (public repository)

This repository publishes **contracts only**: schemas, generic value vocabularies and
sanitized synthetic examples. Merchant/tenant identities, company codes, store numbers,
internal hostnames/IPs, and production volumes must never appear here. Examples are
synthetic: structure and formats are real, every value is fabricated. CI rejects known
internal identifiers.

## Repository layout

```
.
├── c360/
│   └── 3.0/                              # C360 API version 3.0
│       ├── Customer/
│       │   ├── findCustomersB/
│       │   │   ├── findCustomersB-request.xsd
│       │   │   ├── findCustomersB-response.xsd
│       │   │   └── examples/
│       │   │       └── request-sample.xml
│       │   ├── getPersonCompleteDetailsB/
│       │   │   ├── getPersonCompleteDetailsB-request.xsd
│       │   │   ├── getPersonCompleteDetailsB-response.xsd
│       │   │   └── getPersonCompleteDetailsB-openapi.json
│       │   └── updateCustomerB/
│       │       ├── updateCustomerB-request.xsd
│       │       ├── updateCustomerB-response.xsd
│       │       └── examples/
│       │           └── request-sample.xml
│       └── Order/
│           ├── getOrderDetailsC/
│           │   ├── getOrderDetailsC-request.xsd
│           │   └── getOrderDetailsC-response.xsd
│           └── getOrderHeaderDetailsB/
│               ├── getOrderHeaderDetailsB-request.xsd
│               └── getOrderHeaderDetailsB-response.xsd
├── vrg/
│   ├── 3.2.2/                            # frozen, supported TTDR release
│   │   ├── TTDR-3.2.2.xsd
│   │   └── TTDRsimpleTypes-3.2.2.xsd
│   └── 3.3.0/                            # convenience-retail sibling release
│       ├── TTDR-3.3.0.xsd
│       ├── TTDRsimpleTypes-3.3.0.xsd
│       ├── TTDR-CStoreProfile-1.0.xsd
│       ├── README.md
│       ├── MIGRATION.md
│       ├── SECURITY.md
│       └── examples/
├── CHANGELOG.md
├── LICENSE
└── README.md
```

**Conventions:**

- Top-level directory is the **product / API family** in lowercase
  (`c360`, `vrg`).
- Second level is the **published schema version** of that family (`3.0`,
  `3.2.2`, `3.3.0`).
- Inside `c360/3.0/`, the next level is the **resource group** in
  PascalCase (`Customer`, `Order`); this mirrors how the service code is
  organized.
- Each endpoint gets its own folder named exactly after the endpoint
  (e.g. `findCustomersB/`).
- Files inside an endpoint folder use the pattern
  `{endpoint}-{request|response}.xsd` and `{endpoint}-openapi.json`.
- Sample payloads live under `{endpoint}/examples/` named by their role
  (`request-sample.xml`).

---

## C360 3.0 endpoint index

> **Naming note:** C360 is the current product name for what was previously
> called **BORMC** (Business Office Receipt Management Center). The two
> names refer to the same loyalty / order / customer API. Endpoint URLs,
> namespaces, and request shapes are unchanged by the rename — only the
> product/family name has flipped. Internal references and older
> documentation may still use "BORMC"; treat them as synonymous.

All C360 endpoints take their XML payload as form field `XmlInput` on a
POST to `/{web-app}/control/{endpoint}`. Requests carry an `accessTokenKey`
header (a missing or invalid token returns `RESPONSE_CODE` `E899`);
multi-tenant deployments also require `X-tenant-Key` (`E888` when missing).
Errors are returned with HTTP 200 inside the XML document. Element names in
requests are matched case-insensitively, in any order, and unknown elements
are ignored. No C360 schema uses a target namespace: the services emit plain
un-namespaced XML.

Two service generations are in production. They share these contracts; where
they differ, the schema annotations say so (for example, "not found" on
`findCustomersB` is `E163` on the loyalty-app generation and `E105` on the
older one).

### Verification status

Each operation's schema is checked against the service implementation, and
its examples are validated in CI on every change.

| Operation | Status | Basis |
|---|---|---|
| `findCustomersB` | Verified 2026-10 | Source of both service generations |
| `getPersonCompleteDetailsB` | Verified 2026-10 | Source of both service generations |
| `updateCustomerB` | Verified 2026-10 | Source of both service generations |
| `getOrderDetailsC` | Verified 2026-10 | Response: source plus production responses. Request: source of the loyalty-app generation |
| `getOrderHeaderDetailsC` | Verified 2026-10 | Source plus production responses |
| `getOrderHeaderDetailsB` | Verified 2026-10 | Source |
| `getOrderDetailsB` | Verified 2026-10 | Source (same implementation as `getOrderDetailsC`) |
| `couponAuthentication` | Verified 2026-10 | Source of the loyalty-app generation only |
| `couponPost` | Verified 2026-10 | Source of the loyalty-app generation only |
| `customerCertificateSearch` | Verified 2026-10 | Source of the loyalty-app generation only |
| `customerCertificateSearchGC` | **Unverified / legacy** | Not implemented in the loyalty-app generation; use `customerCertificateSearch` |

### Customer

#### `findCustomersB` — search for customers
- **Files:** `c360/3.0/Customer/findCustomersB/` — request and response XSD, `examples/`
- **Behavior:** at least one counting filter must be supplied inside
  `CRITERIA` (otherwise `E105`); `PROVINCE` alone does not count. Filters
  are applied in a fixed precedence: address, then phone, then e-mail, then
  cross-reference (`SYSTEM_REFERENCE` + `SYSTEM_REFERENCE_ID`, an exact
  match). `STORE_ID`, when given, must exist (`E127`). Each match is one
  `CUSTOMER` block; on the loyalty-app generation at most 50 are returned
  and `RECORDS_LIMIT` is accepted but not applied. A successful response
  carries no `RESPONSE_CODE`.

#### `getPersonCompleteDetailsB` — fetch full customer profiles
- **Files:** `c360/3.0/Customer/getPersonCompleteDetailsB/` — request and response XSD, `getPersonCompleteDetailsB-openapi.json`, `examples/`
- **Behavior:** a `CRITERIA` search by customer id, cross-reference,
  e-mail, phone, name or address. Returns one `CUSTOMER` block per match with nested
  `POSTAL_CONTACTS` / `EMAIL_CONTACTS` / `PHONE_CONTACTS`, cross-references
  and marketing segments. `E105` means either no usable filter or no match.
  The service does not validate e-mail, phone or postal formats on this
  operation. A successful response carries no `RESPONSE_CODE`.

#### `updateCustomerB` — create or update a customer record
- **Files:** `c360/3.0/Customer/updateCustomerB/` — request and response XSD, `examples/`
- **Behavior:** a single `CUSTOMER` with optional identity, store, loyalty,
  cross-reference and contact collections. Returns `S102` (updated) or
  `S103` (created) with the `CUSTOMER_ID`. **An update fully replaces
  `FIRST_NAME`, `LAST_NAME`, `GENDER`, `BIRTHDAY` and `CASHIER`: omitting
  one clears it.** The response is a flat, order-free list and may carry
  more than one `RESPONSE_CODE`; the last one is the final outcome.

### Order

#### `getOrderDetailsC` — full order detail (lines, payments, tender, taxes)
- **Files:** `c360/3.0/Order/getOrderDetailsC/` — request XSD, response XSD, `getOrderDetailsC-response-ttdr-layaway.xsd`, `examples/`
- **Behavior:** on the loyalty-app generation the service requires
  `STORE_ID` (`E127`) except on the LayAway branch; every other filter is
  optional and filters combine with AND: `ORDER_ID`, `CUSTOMER_ID` (or a
  cross-reference pair), `REGISTER_NUMBER`, `FROM_DATE` / `THRU_DATE`,
  `ORDER_STATUS`, `PRODUCTS`, and the tender-token filters. `E126` means
  no order matched.
- **LayAway alternate response:** when `TRANSACTION_TYPE=LayAway` the service bypasses the
  standard `RESPONSE` envelope and returns a `Transactions` document instead — see
  `getOrderDetailsC-response-ttdr-layaway.xsd`.

#### `getOrderDetailsB` — full order detail, customer required
- **Files:** `c360/3.0/Order/getOrderDetailsB/` — request and response XSD, `examples/`
- **Behavior:** the same implementation and response as `getOrderDetailsC`.
  The only difference is that the service requires `CUSTOMER_ID` (`E110`). New
  integrations should use `getOrderDetailsC`.

#### `getOrderHeaderDetailsC` — order lookup by product or order
- **Files:** `c360/3.0/Order/getOrderHeaderDetailsC/` — request and response XSD, `examples/`
- **Behavior:** returns order headers with their line items. See
  `c360/3.0/Order/field-value-domains.md` for value vocabularies.

#### `getOrderHeaderDetailsB` — order header summary
- **Files:** `c360/3.0/Order/getOrderHeaderDetailsB/` — request and response XSD, `examples/`
- **Behavior:** filter-driven header lookup; all request filters are
  optional. Monetary fields in the response may be empty strings.

### Coupon

#### `couponAuthentication` — check whether a coupon can be used
- **Files:** `c360/3.0/Coupon/couponAuthentication/` — request and response XSD, `examples/`
- **Behavior:** read-only. `REQ_COUPON_TYPE` must be `SERIALIZE` or
  `NONSERIALIZE` and must match the coupon (`E842`). A positive answer
  carries `RESP_STATUS_CODE` and no `RESPONSE_CODE`.

#### `couponPost` — redeem a coupon
- **Files:** `c360/3.0/Coupon/couponPost/` — request and response XSD, `examples/`
- **Behavior:** marks the coupon as used. Success is `RESPONSE_CODE`
  `S104` with `RESP_STATUS_CODE` `COUPON_AVAILABLE`. An optional
  `CUSTOMER_ID` links the coupon to a customer (`E855` if unknown).

#### `customerCertificateSearch` — list a customer's coupons
- **Files:** `c360/3.0/Coupon/customerCertificateSearch/` — request and response XSD, `examples/`
- **Behavior:** `CUSTOMER_ID` is required (`E110` / `E111`). Results are
  grouped under `LOYALTY_COUPONS` and `MARKETING_COUPONS`. Optional
  filters: date range, `STORE_ID`, `COUPON_PROMO_TYPE`, `COUPON_STATUS`;
  `RECORD_LIMIT` defaults to 100 per group. The same operation is also
  reachable as `customerCertificateSearchB`.

### Gift card

#### `customerCertificateSearchGC` — unverified / legacy
- **Files:** `c360/3.0/GiftCard/customerCertificateSearchGC/` — request and response XSD
- **Status:** no operation of this name is implemented in the loyalty-app
  service generation. The schema is retained unchanged for reference and has
  no examples. Use `customerCertificateSearch`.

---

## VRG / TTDR 3.3.0 and 3.2.2

The **TransactionTree Digital Receipt (TTDR)** schema describes the
receipt envelope retailers POST to TransactionTree's ingest endpoint:

| Environment | Endpoint pattern | Path |
|---|---|---|
| Production | `https://{merchant}.vrgs.io/` | `/VRG/file/loginupload` |
| DevTest    | `https://receiptx.com/`      | `/VRG/file/loginupload` |

TTDR 3.3.0 is the current convenience-retail-capable sibling release. It adds
optional outcome projections for fuel, EV charging, car wash and other
service entitlements, age verification, offers, stored value, mobile payment,
fleet evidence, provenance, and audit evidence. See
[`vrg/3.3.0/README.md`](vrg/3.3.0/README.md).

TTDR 3.2.2 remains supported and is not deprecated. Its files and namespace
are unchanged. Producers must continue to emit 3.2.2 for consumers that have
not negotiated 3.3.0.

Each release's XSD files must be served or supplied together because the
top-level envelope uses relative `xs:include` paths.

Notable additions in the current 3.2.2 cut (versus the older 2025-09-08
revision that previously lived in `general/`):

- `LayawayData` element on the transaction (layaway + special-order
  payment schedules; mapped to `/POS/TRADE/ORDER`).
- `PostVoidSale` / `PostVoidReturn` transaction-type enumerations
  (same-day full void of an original transaction).
- `PRINT_SMS` delivery method (SMS-and-print).
- `TransactionHistory` defaults to `N` when unspecified.
- `RegisterType` defaults to `POS` when unspecified.

See [`CHANGELOG.md`](CHANGELOG.md) for the full timeline.

---

## Validating a payload against the schemas

The services do not XSD-validate input at runtime, but you should — local
XSD validation catches structural and enum mistakes before you spend a
round trip.

### Using `xmllint` (libxml2; macOS / Linux / WSL)

```bash
# C360 request payload
xmllint --noout \
        --schema c360/3.0/Customer/findCustomersB/findCustomersB-request.xsd \
        my-findCustomersB-request.xml

# TTDR 3.3.0 receipt envelope
xmllint --noout \
        --schema vrg/3.3.0/TTDR-3.3.0.xsd \
        my-receipt.xml
```

### Using Python (`xmlschema`)

```bash
pip install xmlschema
```

```python
import xmlschema

schema = xmlschema.XMLSchema("vrg/3.3.0/TTDR-3.3.0.xsd")
schema.validate("my-receipt.xml")           # raises XMLSchemaException on failure
print(schema.is_valid("my-receipt.xml"))    # bool variant
```

### Using XMLSpy / Oxygen / IntelliJ

Open the XSD in the editor and drag the payload XML onto it (or
right-click → "Validate against schema"). The sample payloads under
`examples/` already declare `xsi:schemaLocation` so they validate when
opened directly.

---

## Schema-level versioning

Versioning is **per schema**, not per repo. Each `<xs:schema>` declares a
`version` attribute (or — for older files — carries the version in a
top-of-file comment). When we change a schema in a way that affects
clients, we bump the version inside the file and add a `CHANGELOG.md`
entry.

| Family | Current major | Notes |
|---|---|---|
| C360 (fka BORMC) | `3.0` | No C360 schema uses a `targetNamespace`; the services emit and accept un-namespaced XML. |
| TTDR / VRG | `3.3.0` | Convenience-retail sibling release. TTDR 3.2.2 remains supported and is not deprecated. |

A new contract version will live in a new sibling directory rather than
overwriting an existing published schema. Corrections are different: when a
published schema is found to disagree with what the service actually accepts
or returns, it is corrected in place and the change is recorded in
[`CHANGELOG.md`](CHANGELOG.md), including any correction that is breaking for
consumers who validated against the earlier file.

---

## Conventions and gotchas

- **Form field, not raw body.** C360 endpoints take the XML inside a
  form field named `XmlInput` on an `application/x-www-form-urlencoded`
  POST. The XML itself must be URL-encoded.
- **Headers carry tenancy.** `X-tenant-Key` is required on C360 calls;
  the access-token header may also be required depending on tenant
  configuration. Missing or invalid tenant → `RESPONSE_CODE` `E888`.
  Auth failure → `E899`.
- **Response codes are documented in the schema.** Where a response XSD
  defines a `ResponseCodeType` simpleType, the annotation block holds the
  full code table observed for that endpoint family. Treat the schema as
  the source of truth for valid codes.
- **Some monetary fields permit empty strings.** Older response schemas
  define an `EmptyString` simpleType used in unions for fields like
  `TOTAL_TAX` — this matches what live services actually return.
- **Namespace inconsistency is intentional (for now).** Older C360
  endpoints (`findCustomersB`, `updateCustomerB`) declare a
  `targetNamespace`; newer ones do not. New schemas added to this repo
  should follow the **no-namespace** convention unless there's a
  compelling reason to namespace them.
- **`examples/request-sample.xml` files are illustrative.** They were
  initially generated by XMLSpy and contain placeholder data
  (`"String"`, regex-looking values for pattern fields). Replace the
  placeholders with realistic values before sending to a live tenant.

---

## Contributing

Contributions are expected to come from the TransactionTree engineering
team and contracted integration partners. Outside contributions are
accepted on a case-by-case basis — open an issue first.

**For a schema change:**

1. Branch from `main`.
2. Update the XSD inline. Bump the `version` attribute on `<xs:schema>`
   if the change is observable to clients (added element, changed
   enumeration, tightened occurrence constraint, etc.). Cosmetic edits
   (typo in `<xs:documentation>`, whitespace) don't need a version bump.
3. Update `CHANGELOG.md`.
4. Regenerate or update the matching `examples/request-sample.xml` if
   the structural change affects it.
5. Validate every existing example against the updated schema (see
   *Validating a payload* above).
6. Open a PR; tag the relevant integration owner.

**For a new endpoint:**

1. Create `c360/{version}/{ResourceGroup}/{endpointName}/`.
2. Drop in `{endpointName}-request.xsd`, `{endpointName}-response.xsd`,
   and (optionally) `{endpointName}-openapi.json`.
3. Add a sample under `{endpointName}/examples/request-sample.xml`.
4. Add an entry under "C360 3.0 endpoint index" in this README.

---

## License

[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) — see [`LICENSE`](LICENSE).

Copyright (c) 2021-2026 TransactionTree, Inc. You may copy, embed and
redistribute these schemas and documents, including in commercial
integrations, with attribution to TransactionTree, Inc.

For integration questions: **support@transactiontree.com**
