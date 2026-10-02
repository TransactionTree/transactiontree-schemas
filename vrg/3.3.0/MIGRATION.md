# Migrating from TTDR 3.2.2 to 3.3.0

## Compatibility model

TTDR 3.3.0 is a sibling schema, not an in-place modification of TTDR 3.2.2.
The 3.2.2 XSDs remain unchanged under `vrg/3.2.2/` and continue to be
supported.

Instances are namespace-versioned:

- A 3.2.2 document remains a 3.2.2 document and uses `TTDRV322`.
- A 3.3.0 document uses the 3.3.0 namespace and `TTDRV330`.
- A strict 3.2.2 consumer will not accept a 3.3.0 namespace without an
  explicit upgrade, even when `CStoreData` is absent.

Do not rewrite historical 3.2.2 documents merely to add a newer version
label. Preserve the schema identity under which each receipt was produced.

## Producer migration

1. Confirm that every downstream consumer accepts TTDR 3.3.0.
2. Change the root namespace and `xsi:schemaLocation` to the 3.3.0 URI/XSD.
3. Change `TTDRVersion` from `TTDRV322` to `TTDRV330`.
4. Keep all existing legacy TTDR lines, tenders, taxes, and totals.
5. Add `CStoreLineProfile` only to a detail line representing fuel, EV
   charging, or a service entitlement.
6. Add transaction-level `CStoreData` only when the receipt has applicable
   outcome evidence.
7. Preserve exact decimal profile values. Do not derive them back from
   rounded legacy integer fields.
8. Validate against the XSD and apply the security policy before delivery.

For mixed estates, negotiate a version per destination and emit 3.2.2 or
3.3.0 from the same canonical transaction model. Do not place 3.3.0 profile
elements in the 3.2.2 namespace.

## Consumer migration

1. Route by the root namespace, then verify the fixed `TTDRVersion` value.
2. Continue parsing all legacy TTDR fields exactly as before.
3. Treat both profile attachment points as optional.
4. Preserve unknown code values together with `Scheme` and `SchemeVersion`;
   do not silently coerce them into an unrelated local enumeration.
5. Use decimal arithmetic for `CStoreExactDecimalType` and
   `CStoreExactMoneyType`; never binary floating point for audit totals.
6. Resolve `TenderEvidence/TenderReference` against the legacy
   `TenderTypeData/TenderReference` when present.
7. Resolve profile line references against
   `DetailedTransactionData/LineReference`. Producers must populate a value
   that is unique within the transaction whenever profile data references a
   line; `ProductId` is not a line identifier and may repeat.
8. Enforce authorization and retention controls before following evidence
   references or storing privacy-sensitive outcomes.

## Authoritative-value rules

- Legacy TTDR monetary totals remain cents-as-integer receipt totals.
- Profile money uses exact decimal major-currency units.
- Profile fuel volume, EV energy, meter readings, tariff quantities, and
  unit rates are authoritative when a legacy field loses precision.
- A profile does not authorize recomputing or changing the charged total.
  Any disagreement is an audit exception to investigate.
- `ProcessingResult`, fleet, mobile, offer, and stored-value structures are
  normalized outcomes. They are not substitutes for complete provider
  protocol messages.

## Deprecation guidance

TTDR 3.2.2 is **supported and not deprecated**. New integrations that need
the convenience-retail profile should choose 3.3.0. Existing 3.2.2
integrations may remain on 3.2.2 until both producer and consumer schedule an
upgrade. A future deprecation, if any, requires a separately published notice
and support timeline; this release does not establish one.
