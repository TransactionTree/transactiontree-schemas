# TTDR 3.3.0 Convenience-Retail Security Profile

The XSD defines structure, not complete data-loss-prevention policy. A value
can be syntactically valid `xs:string` and still be prohibited. Producers and
ingest services must enforce the rules below in addition to XSD validation.

## Never include

- Primary account numbers (PAN), even when labelled as a token
- Magnetic-stripe track data
- CVV/CVC/CID values
- PINs or PIN blocks
- Raw EMV cryptograms, ARQC/TC/AAC values, or complete EMV tag dumps
- Dates of birth
- Government identity document numbers, images, barcode payloads, or full
  identity-verification responses
- Passwords, API keys, client secrets, private keys, session credentials, or
  authentication headers
- Reusable plaintext car-wash, fleet, stored-value, or offer credentials
- Complete payment, dispenser, forecourt, charger, car-wash, or identity
  provider protocol messages

## Use instead

- Opaque, scoped, non-reversible tokens
- Display-safe masked values, normally only the final four digits
- Normalized approval/decline/error outcomes and response/reason codes
- SHA-256 digests or authorized evidence-store references
- Typed fleet prompt evidence rather than free text
- Threshold outcome, method, policy version, and event time for age checks
- Source standard, representation, version, record ID, and mapping-profile
  provenance

Tokens must be scoped to the minimum required purpose, non-reusable outside
that context, and protected by access control and retention policy. A token
must never be a renamed PAN, driver ID, document number, wash code, or gift
card number.

## Data minimization

`AgeVerification` proves that a policy was evaluated. It must not identify
the person or reproduce source document data. `TenderEvidence` records a safe
processing outcome; the payment processor remains the system of record for
payment protocol evidence. `AuditEvidence` records a normalized audit fact;
full journals and movement feeds belong in a dedicated audit-event contract
such as ORAE.

## Operational controls

- Validate against `TTDR-3.3.0.xsd` before ingest.
- Apply DLP/security-policy validation after XSD validation.
- Encrypt in transit and at rest.
- Restrict evidence resolution to authorized services and operators.
- Log references and outcomes, not raw credentials or source messages.
- Establish retention independently for receipts, age outcomes, payment
  evidence, and audit records.
- Reject or quarantine a payload containing prohibited data; do not merely
  redact it after downstream distribution.

The included `validate.ps1` applies a conservative policy to repository
examples. Production controls should add provider-specific token formats and
organization DLP rules.
