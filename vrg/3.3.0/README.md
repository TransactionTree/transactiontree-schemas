# TTDR 3.3.0

TTDR 3.3.0 is a sibling release of the TransactionTree Digital Receipt
schema. It preserves the complete TTDR 3.2.2 receipt model and adds optional
convenience-retail outcome data for fuel, EV charging, service entitlements,
age verification, offers, stored value, mobile payment, fleet processing,
source provenance, and audit evidence.

TTDR is a receipt and audit projection. It is not a control protocol for a
dispenser, forecourt controller, tank system, price pole, EV charger, car-wash
controller, payment terminal, stored-value host, or identity-verification
provider.

## Files

| File | Purpose |
|---|---|
| `TTDR-3.3.0.xsd` | TTDR 3.3.0 envelope and optional profile attachment points. |
| `TTDRsimpleTypes-3.3.0.xsd` | Versioned copy of the legacy TTDR shared types. |
| `TTDR-CStoreProfile-1.0.xsd` | Convenience-retail outcome types included by the envelope. |
| `examples/*.xml` | XSD-valid illustrative transactions. |
| `validate.ps1` | Local schema, example, policy, negative-security, and compatibility checks. |
| `MIGRATION.md` | Upgrade and coexistence guidance for TTDR 3.2.2 producers and consumers. |
| `SECURITY.md` | Prohibited data and safe projection rules. |

All three XSD files must remain in the same directory because the envelope
uses relative `xs:include` references.

## Version identity

| Version | Namespace | `TTDRVersion` |
|---|---|---|
| 3.2.2 | `https://www.transactiontree.com/framework/schema/vrg/3.2.2/TTDR3.2.2.xsd` | `TTDRV322` |
| 3.3.0 | `https://www.transactiontree.com/framework/schema/vrg/3.3.0/TTDR3.3.0.xsd` | `TTDRV330` |

The namespace and fixed version value must agree. Changing only
`TTDRVersion` is not a migration.

TTDR 3.2.2 remains supported and is **not deprecated** by this release. Keep
emitting 3.2.2 for consumers that have not negotiated 3.3.0. New
convenience-retail fields are available only in 3.3.0.

## Attachment points

TTDR 3.3.0 adds two optional elements:

- `Transaction/TransactionData/DetailedTransactionData/CStoreLineProfile`
  attaches exactly one fuel, EV charging, or service-entitlement outcome to a
  legacy TTDR detail line.
- `Transaction/CStoreData` carries transaction-level provenance, age
  verification, offer redemption, stored-value activity, service
  entitlements, tender evidence, and audit evidence.

All existing receipt elements retain their TTDR 3.2.2 definitions. The
profile supplements rather than replaces legacy line, tender, and total
fields. For fuel and EV quantities or rates, the profile's exact decimal
values are authoritative when legacy integer fields require rounding or
scaling.

`DetailedTransactionData/LineReference` is the producer-stable, unique line
identifier used by transaction-level profile references. Populate it whenever
an age, offer, stored-value, or audit outcome points to a line. Do not use
`ProductId` as a line key because the same product can occur on multiple
receipt lines.

`CStoreData` uses this fixed sequence:

1. `SourceProvenance`
2. `AgeVerification`
3. `OfferRedemption`
4. `StoredValueActivity`
5. `ServiceEntitlement`
6. `TenderEvidence`
7. `AuditEvidence`

Repeatable elements may appear more than once, but groups must remain in that
order.

## Examples

| Example | Coverage |
|---|---|
| `fuel-fleet-sample.xml` | Exact fuel volume/unit price, Conexxus-qualified codes, fleet authorization and typed prompt evidence. |
| `ev-mobile-sample.xml` | EV energy, meter readings, tariff/pricing component, mobile-payment context, and OCPI provenance. |
| `car-wash-entitlement-sample.xml` | Tokenized car-wash entitlement issuance at line and transaction level. |
| `restricted-offer-stored-value-sample.xml` | Privacy-minimized age decision, offer allocation, stored-value redemption, tender result, and audit evidence. |

Code-scheme and source-standard names in examples are illustrative mapping
profiles, not claims of Conexxus, OCPI, or provider certification. Pin the
actual source contract and code-list version used by each implementation.

## Validation

On Windows or PowerShell 7+:

```powershell
pwsh ./vrg/3.3.0/validate.ps1
```

The script compiles both TTDR 3.3.0 and the frozen TTDR 3.2.2 release,
validates every 3.3.0 example, verifies that the 3.3.0 shared legacy types are
structurally unchanged from 3.2.2 apart from comments, applies the example
security policy, and proves that the synthetic prohibited-data fixtures under
`tests/security-invalid/` are rejected while valid opaque tokens under
`tests/security-valid/` pass. It also proves that blank, duplicate, and
dangling convenience-retail line references, blank code qualifiers, and
over-wide exact decimals are rejected by the XSD. Audit evidence uses its
dedicated `LineReference` for receipt-line subjects; generic `SubjectType` and
`SubjectId` pairs are reserved for non-line subjects.

With `xmllint`:

```bash
xmllint --noout --schema vrg/3.3.0/TTDR-3.3.0.xsd \
  vrg/3.3.0/examples/fuel-fleet-sample.xml
```

XSD validity does not prove business-policy or privacy compliance. Apply the
rules in [`SECURITY.md`](SECURITY.md) before accepting a producer.
