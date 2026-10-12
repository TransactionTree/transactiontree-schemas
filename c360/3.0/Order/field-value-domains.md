# Order API — Field Value Domains

What the Order lookup responses (`getOrderDetailsC`, `getOrderHeaderDetailsC`, B-variants)
actually carry in each bounded-vocabulary field, so an integrating system knows what to
expect. Evidence: production observation windows (30 days of transaction lines, 14 days of
tax lines) plus service source across all deployed generations. Values below are platform
vocabulary; tenant-identifying literals are generalized.

## Deployment generations (why responses differ between systems)

Response element sets form a strict superset chain across the deployed service generations —
newer generations only **add** elements, none conflict:

| Generation | Elements emitted | Distinguishing additions |
|---|---|---|
| legacy (`lmsServices`, 2014-era) | 40 | the original core |
| current `lmsServices` lmsServices-v2 | 105 | CONTACT blocks, LEVEL_5 merchandising, ITEM_TAX detail, discounts, tenders |
| loyalty-app | 132–133 | `ORIGINAL_*` return linkage, tender tokens, `ATTRIBUTE` blocks, `BALANCE`/`CHANGE`/`CASH_BACK_AMOUNT`, `DEPARTMENT_CODE`, `REGISTER_TYPE`, `WORKDAY_ID`, `TRANSACTION_HISTORY`, `IS_*` flags; one deployment adds `RESPONSE_DATA` (exception detail, sibling of `RESPONSE_MESSAGE`) |

A consumer written against the superset handles every system; absent fields simply don't appear.

## Envelope

| Field | Values | Notes |
|---|---|---|
| `RESPONSE_CODE` | absent on success; `E101–E104` input parse; `E110`/`E111` customer; `E122` date format; `E124` status length; `E126` no orders matched; `E127` store unknown; `E129` transaction not found; `E300` product unknown; `E888` unknown tenant key; `E899` token validation failed; `E999` exception | Every response is HTTP 200. `E888`/`E899` arrive wrapped in `WEBSERVICE`. |
| `RESPONSE_MESSAGE` / `RESPONSE_DATA` | free text | exception detail with `E999`; element name differs by generation |
| `RESPONSE_DATE` | `yyyy-MM-dd HH:mm:ss.S` | not ISO 8601 |

## Transaction header

| Field | Observed values | Notes |
|---|---|---|
| `TRANSACTION_TYPE` | `SaleTransaction`, `ReturnTransaction`, `LayAway`, … | storage uses numeric codes (`01` = sale); the service emits names. `LayAway` triggers the alternate response contract (see layaway schema). |
| `ORDER_STATUS` | `ORDER_COMPLETED` (universally), `ORDER_APPROVED`, `ORDER_CREATED`, `ORDER_REJECTED` | request filter accepts the un-prefixed form |
| `STORE_ID` / `CASH_REGISTER_ID` / `TERMINAL_ID` | zero-padded numeric strings | padding width is tenant-configured |
| `CONTACT_TYPE` | `BILLING`, `SHIPPING` | one CONTACT block per address |
| `SYSTEM_REFERENCE` (cross-references) | `POS_ID` (till customer id — dominant), loyalty/affinity program ids, e-commerce customer ids, enrollment-status markers, dedup markers (`*_DEDUPED`, `DEDUP_PRE`) | per-tenant key names; consumers should treat the set as open |
| `TAX_EXEMPT` / `TAX_ID` | flag + exemption id | populated only for exempt customers |

## Line items

| Field | Observed values | Notes |
|---|---|---|
| `LINE_TYPE` | `PLU_SALE` (barcode-scanned, ~54% of volume), `KNOWN_ITEM_SALE` (keyed SKU, ~45%), `TXN_LEVEL_SERVICE`, `LINE_LEVEL_SERVICE`, `GIFT_CARD_SALE`, `GIFT_CARD_TOPUP_CREDIT`, `DEPARTMENT_SALE`, `UNKNOWN_ITEM_SALE` | |
| `SKU_ITEM_TYPE` | numeric, correlates 1:1 with LINE_TYPE: `6`=PLU_SALE, `1`=KNOWN_ITEM_SALE, `19`=TXN_LEVEL_SERVICE, `20`=LINE_LEVEL_SERVICE, `57`=GIFT_CARD_SALE, `58`=GIFT_CARD_TOPUP_CREDIT, `2`=DEPARTMENT_SALE, `3`=UNKNOWN_ITEM_SALE | |
| `SKU_OWNER` / `SKU_OWNER_TYPE` | tenant company code / `1` | |
| `SKU` | tenant SKU (numeric where the merch system is numeric) | |
| `PLU_NUMBER` | scanned barcode (UPC-A/EAN) on scanned lines; empty on keyed lines | emitted by POS feeds that carry scan codes |
| `LEVEL_5_LEVEL_5_ID` | merchandising path code, format `A<div>B<dept>C<class>D<subclass>` | 4-level hierarchy; `LEVEL_5_PRODUCT_GROUP_TYPE`=`3`, `LEVEL_5_STRUCTURE_TYPE`=`1` on merch lines (`0`/`0` on non-merch) |
| `RETURNED_STATUS` | empty, or `1` when the line has been returned against | `RECORD_TYPE` in storage: `02` sale line, `15` return line |
| `PRICE_OVERRIDE` | `Y`/`N` or `true`/`false` (generation-dependent); storage flag `1` | flag, not an amount |
| `ITEM_STATUS` | `Pickedup` (sale lines), `1` (return lines) | legacy vocabulary |
| `IMAGE` | retailer CDN product-image URL at response time | |

## Tenders (full-detail service)

| Field | Observed values |
|---|---|
| `TENDER_TYPE` | `CASH`, `CHECK`, `CREDIT-VISA`, `CREDIT-MC`, `CREDIT-AMEX`, `DEBIT-OTHER`, `GIFT-CARD`, `Coupon`, `Voucher`, `HouseAccount`, `MoneyOrder`, `ForeignCurrency`, `SpecialTender`, `None`, plus legacy numeric codes (`3`, `45`, `121`, `388`, `440`) |
| `TENDER_MEDIA_TYPE` | `10` (dominant), `11` |
| `TENDER_TOKEN` / `TENDER_SHORTTOKEN` / `TENDER_LONGTOKEN` | payment tokens (loyalty-app generation; used by token-based receipt lookup) |

## Taxes

| Field | Observed values | Notes |
|---|---|---|
| `TAX_TYPE` | `StateOrProvince` (line level), `ORDER_TAX` (header level), `GST`, `PST` variants by tenant | |
| `TAX_RULE_CODE` | `G` (federal/GST-class), `P` (provincial/state-class), `F`, `N` (none), `Q` | single-letter POS rule codes |
| `TAX_AUTHORITY` | two-letter province/state codes (`ON`, `QC`, `BC`, `AB`, `SK`, `MB`, `MB1`, `NB`, `NS`, `NL`, `PE`, …) | per-tenant jurisdiction set; `MB1`-style variants occur |
| `TAX_FLAG` | `true` or absent | |

## Request-side keys the lookups accept

Authoritative per-operation contracts are the four `*-request.xsd` files — key names,
required/optional status and **date types differ per operation** (some take `yyyy-MM-dd`
strings, `getOrderHeaderDetailsB` takes `xs:dateTime`; some declare filters such as
`TRANSACTION_TYPE` and `REGISTER_NUMBER`; `ORDER_STATUS` appears in some request
payloads historically but is not declared by the current request schemas). Common keys:
`PRODUCT_ID` (catalog SKU — scanned barcodes sent here only resolve on systems with a
barcode-to-SKU cross-reference), `ORDER_ID`/transaction number, `CUSTOMER_ID`,
`SYSTEM_REFERENCE`+`SYSTEM_REFERENCE_ID`, `STORE_ID`, `FROM_DATE`/`THRU_DATE`,
`RECORD_LIMIT`.

## Ingestion-side: per-line ItemAttributes (how the non-standard line fields travel)

POS feeds deliver the generation/POS-specific line fields as generic TTDR
`ItemAttributes` name/value pairs; ingestion maps each known name to a dedicated
column, and the lookups emit them back as first-class elements:

| Inbound attribute name | Response element |
|---|---|
| `detailNumber` / `parentNumber` | `DETAIL_NUMBER` / `PARENT_NUMBER` |
| `SKU_OWNER` / `SKU_OWNER_TYPE` / `SKU_ITEM_TYPE` | same names |
| `LineType` | `LINE_TYPE` |
| `Image` | `IMAGE` |
| `level5CompanyCode` / `level5Level5ID` / `level5ProductGroupType` / `level5StructureType` | `LEVEL_5_COMPANY_CODE` / `LEVEL_5_LEVEL_5_ID` / `LEVEL_5_PRODUCT_GROUP_TYPE` / `LEVEL_5_STRUCTURE_TYPE` |
| `pluNumber` | `PLU_NUMBER` |
| `priceOverridden` | `PRICE_OVERRIDE` |

Worked examples with every Flooid-fed attribute populated, in production element order:
`getOrderHeaderDetailsC/examples/responses/success-flooid-fed-item-attributes.xml` and
`getOrderDetailsC/examples/responses/success-flooid-fed-item-attributes.xml` (scanned line,
keyed line with price override, and an attached child line). A child line carries
`PARENT_NUMBER` = the parent's `DETAIL_NUMBER` and `ITEM_LEVEL` = `1`; top-level lines are `0`.

### Observed attribute vocabularies by POS family

| POS family | ItemAttributes observed inbound |
|---|---|
| Flooid-fed | `detailNumber`, `parentNumber`, `SKU_OWNER`, `SKU_OWNER_TYPE`, `SKU_ITEM_TYPE`, `LineType`, `Image`, `level5CompanyCode`, `level5Level5ID`, `level5ProductGroupType`, `level5StructureType`, `pluNumber`, `priceOverridden` |
| Aptos-fed (apparel) | `detailNumber`, `priceOverridden`, `ProductUPC`, `ProductID`, `ProductStyle`, `Color`, `Size`, `ProductClass`, `ProductDivision`, `ProductDeptGroup`, `ProductOrderNumber` |
| Aptos-fed (minimal profile) | `detailNumber`, `ImageURL` |
| Toshiba-RBI-fed | `detailNumber`, `SKU_ITEM_TYPE`, `priceOverridden` |
| Retail-Pro-fed (mapping in progress) | `detailNumber`, `ProductUPC`, `Size`, `ProductName`, `ProductShortDescription` |

`detailNumber` is the universal spine; `priceOverridden` appears in three of the five profiles. Apparel feeds
carry merchandising facets (Color/Size/Style/Division) as attributes where hardgoods feeds
use the level5 hierarchy codes. Note Aptos-family feeds deliver `ProductUPC` per line —
systems ingesting those feeds have per-line barcode data; Flooid feeds carry `pluNumber`
only on scanned lines.

How the name travels: when the TTDR `AttributeType` enumeration has a member for the
facet (`Color`, `Size`, `ProductUPC`, `ProductClass`, `ProductOrderNumber`,
`detailNumber`, `priceOverridden`), feeds send it as the AttributeType; names without an
enum member (`Image`, `ProductID`, `ProductStyle`, `ProductDivision`,
`ProductDeptGroup`, the `level5*` set, …) travel as `AttributeType=Other` with the name
in `AttributeDescription` — an open string, so this route is contract-clean. All observed
feeds stay within the published TTDR contract by one of these two routes.

Persistence differs by generation: the lmsServices generation persists only the recognized
names above (unrecognized names are dropped); the loyalty-app generation additionally stores
attributes generically (name/value) and can emit them via `ATTRIBUTE_TYPE`/`ATTRIBUTE_DESCRIPTION`/`ATTRIBUTE_DATA` blocks.
