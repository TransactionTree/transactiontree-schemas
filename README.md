# transactiontree-schemas

Public XML Schema Definitions (XSDs) and OpenAPI descriptions for
TransactionTree's customer-facing services. Integrators use this repo to
generate XML payloads, validate them locally before submitting, and stub
client SDKs.

Two product families are published here:

| Family | Path | What it describes |
|---|---|---|
| **BORMC** (Business Office Receipt Management Center) — loyalty + order API | `bormc/3.0/` | Form-encoded POST endpoints under `/loyalty-app/control/*` that exchange XML inside the `XmlInput` form field. |
| **VRG / TTDR** (TransactionTree Digital Receipt — VRG ingest) | `vrg/3.2.2/` | The Digital Receipt envelope POSTed to `vrgs.io` (prod) and `receiptx.com` (dev/test) for retailer receipt ingest. |

These schemas are documentation-grade — the runtime services validate input
in code rather than against the XSDs, so the schemas describe both the
structural shape **and** the business rules enforced downstream (response
codes, format constraints, conditional requirements). Keep that distinction
in mind: an XML payload can be XSD-valid and still get a code-level
rejection.

---

## Repository layout

```
.
├── bormc/
│   └── 3.0/                              # BORMC API version 3.0
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
│   └── 3.2.2/                            # TTDR / VRG schema version 3.2.2
│       ├── TTDR-3.2.2.xsd                # the receipt envelope (includes TTDRsimpleTypes-3.2.2.xsd)
│       └── TTDRsimpleTypes-3.2.2.xsd     # shared simple types and enumerations
├── CHANGELOG.md
├── LICENSE
└── README.md
```

**Conventions:**

- Top-level directory is the **product / API family** in lowercase
  (`bormc`, `vrg`).
- Second level is the **major version** of that family (`3.0`, `3.2.2`).
- Inside `bormc/3.0/`, the next level is the **resource group** in
  PascalCase (`Customer`, `Order`); this mirrors how the service code is
  organized.
- Each endpoint gets its own folder named exactly after the endpoint
  (e.g. `findCustomersB/`).
- Files inside an endpoint folder use the pattern
  `{endpoint}-{request|response}.xsd` and `{endpoint}-openapi.json`.
- Sample payloads live under `{endpoint}/examples/` named by their role
  (`request-sample.xml`).

---

## BORMC 3.0 endpoint index

All BORMC endpoints take their XML payload as form field `XmlInput` on a
POST to `/loyalty-app/control/{endpoint}`. Required headers vary by tenant
but typically include `X-tenant-Key` and an `Authorization` token.

### Customer

#### `findCustomersB` — search for customers
- **Files:** `bormc/3.0/Customer/findCustomersB/findCustomersB-request.xsd`, `findCustomersB-response.xsd`, `examples/request-sample.xml`
- **Request namespace:** `https://www.transactiontree.com/schema/loyalty/findCustomersB/1.0`
- **Response namespace:** `https://www.transactiontree.com/schema/loyalty/findCustomersB/response/1.0`
- **Behavior:** at least one filter must be supplied inside `CRITERIA`
  (otherwise `RESPONSE_CODE` `E105`). `STORE_ID`, when given, must exist
  (`E127`). `PHONE_NUMBER` is split into area-code (first three chars) +
  remainder when length > 7. `ZIP_CODE` drives multiple lookup paths
  depending on length. `SYSTEM_REFERENCE` + `SYSTEM_REFERENCE_ID` can
  short-circuit to an exact match. `RECORDS_LIMIT` caps the result window.

#### `getPersonCompleteDetailsB` — fetch a single customer's full profile
- **Files:** `bormc/3.0/Customer/getPersonCompleteDetailsB/getPersonCompleteDetailsB-request.xsd`, `getPersonCompleteDetailsB-response.xsd`, `getPersonCompleteDetailsB-openapi.json`
- **No `targetNamespace`** (schema-version `1.0`).
- **Behavior:** accepts either a `CRITERIA` search (typical) or a
  `CUSTOMER` anchor. Empty filters trigger `E101` / `E105`. Email format,
  Canadian postal rules, and state/country pairing are validated by the
  service code (`E222`, `E166`, `E106`, `E107` respectively). Response
  returns nested `POSTAL_CONTACTS` / `EMAIL_CONTACTS` / `PHONE_CONTACTS`
  collections along with cross-references and market segments. See the
  `ResponseCodeType` annotation in the response XSD for the full code
  table.

#### `updateCustomerB` — create or update a customer record
- **Files:** `bormc/3.0/Customer/updateCustomerB/updateCustomerB-request.xsd`, `updateCustomerB-response.xsd`, `examples/request-sample.xml`
- **Request namespace:** `https://www.transactiontree.com/schema/loyalty/updateCustomerB/1.0`
- **Behavior:** a single `CUSTOMER` with optional identity, store/loyalty,
  cross-references, and contact collections (postal, email, phone).
  Collections are repeatable (0..n). Most scalar fields are optional
  unless tenant policy says otherwise. Business rules (store existence,
  email format, date parsing) are enforced in code and reported via
  `RESPONSE_CODE`.

### Order

#### `getOrderDetailsC` — full order detail (lines, payments, tender, etc.)
- **Files:** `bormc/3.0/Order/getOrderDetailsC/getOrderDetailsC-request.xsd`, `getOrderDetailsC-response.xsd`
- **No `targetNamespace`.**
- **Behavior:** keyed by `ORDER_ID` (required); `CUSTOMER_ID` scopes the
  search to a bill-to / placing customer. `FROM_DATE` / `THRU_DATE` are
  `xs:date`. Response includes the `LayawayData` block when applicable.

#### `getOrderHeaderDetailsB` — order header summary
- **Files:** `bormc/3.0/Order/getOrderHeaderDetailsB/getOrderHeaderDetailsB-request.xsd`, `getOrderHeaderDetailsB-response.xsd`
- **No `targetNamespace`.**
- **Behavior:** filter-driven header lookup; all request filters are
  optional. Monetary fields in the response may be empty strings (the
  schema explicitly permits this to match live output).

---

## VRG / TTDR 3.2.2

The **TransactionTree Digital Receipt (TTDR)** schema describes the
receipt envelope retailers POST to TransactionTree's ingest endpoint:

| Environment | Endpoint pattern | Path |
|---|---|---|
| Production | `https://{merchant}.vrgs.io/` | `/VRG/file/loginupload` |
| DevTest    | `https://receiptx.com/`      | `/VRG/file/loginupload` |

`TTDR-3.2.2.xsd` is the top-level envelope and includes
`TTDRsimpleTypes-3.2.2.xsd` (shared enumerations and constrained types).
Both files must be served / supplied together; the `xs:include` uses a
relative path inside `vrg/3.2.2/`.

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
# BORMC request payload
xmllint --noout \
        --schema bormc/3.0/Customer/findCustomersB/findCustomersB-request.xsd \
        my-findCustomersB-request.xml

# TTDR receipt envelope
xmllint --noout \
        --schema vrg/3.2.2/TTDR-3.2.2.xsd \
        my-receipt.xml
```

### Using Python (`xmlschema`)

```bash
pip install xmlschema
```

```python
import xmlschema

schema = xmlschema.XMLSchema("vrg/3.2.2/TTDR-3.2.2.xsd")
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
| BORMC | `3.0` | Endpoints carry their own `1.0` request/response namespaces where namespaced; newer endpoints (`getPersonComplete*`, `getOrder*`) use no `targetNamespace`. |
| TTDR / VRG | `3.2.2` | Last full revision shipped 2025-12-12. Schema attribute remains `3.2.2`; intra-version edits are tracked in CHANGELOG. |

A future major version (e.g. `bormc/3.1/`, `vrg/3.3/`) will live in a new
sibling directory rather than overwriting `3.0/` or `3.2.2/`.

---

## Conventions and gotchas

- **Form field, not raw body.** BORMC endpoints take the XML inside a
  form field named `XmlInput` on an `application/x-www-form-urlencoded`
  POST. The XML itself must be URL-encoded.
- **Headers carry tenancy.** `X-tenant-Key` is required on BORMC calls;
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
- **Namespace inconsistency is intentional (for now).** Older BORMC
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

1. Create `bormc/{version}/{ResourceGroup}/{endpointName}/`.
2. Drop in `{endpointName}-request.xsd`, `{endpointName}-response.xsd`,
   and (optionally) `{endpointName}-openapi.json`.
3. Add a sample under `{endpointName}/examples/request-sample.xml`.
4. Add an entry under "BORMC endpoint index" in this README.

---

## License

Proprietary. See [`LICENSE`](LICENSE).

Copyright (c) 2021-2026 TransactionTree, Inc. Permission is granted to
customers, partners, and integrators to use these schemas to build
clients against TransactionTree services under an applicable subscription
or integration agreement.

For integration questions: **support@transactiontree.com**
