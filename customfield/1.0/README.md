# Customer Custom Fields API — 1.0

Read and write **custom-field (attribute) values** on a customer, and manage the **field** and
**group** definitions behind them. This API is part of the C360 platform but is a **separate contract**
from the C360 3.0 loyalty/order API: it is **JSON** (not XML `XmlInput`), it lives under its own
`/customfield-app/api/attribute/.../v1` path, and it uses a **bearer** token (not `accessTokenKey`).
It is versioned independently; this is `v1`, published here as `1.0`.

These schemas are **documentation-grade**: the runtime validates in code, not against these files, so the
schemas describe both the structural shape and the business rules (response codes, constraints,
conditional requirements). A payload can be schema-valid and still get a code-level rejection.

## Base path & transport

- Every operation is **`POST`** with a JSON body (`Content-Type: application/json`) and a JSON reply.
- Paths are `/<web-app>/customfield-app/api/attribute/<resource>/v1/<operation>`, where `<resource>` is
  `customer`, `group`, or `field`.
- Your real base URL is issued with your credentials; examples here use
  `https://c360.sandbox.example.com`.

## Authentication

`Authorization: Bearer <token>`, where **`token = base64(secretCode)`** and `secretCode` is the value
issued with your credentials. The token is matched against a registered application record and must be
within its valid date window.

> **Enforcement is per-operation and currently partial.** Only `searchCustomerField`,
> `updateCustomerField`, and `searchGroupField` are configured to require the token; the other
> operations do not currently reject an unauthenticated call. Always send the header on every call
> regardless — do not rely on an endpoint being open.

## Response envelope — branch on `response_code`, never HTTP status

Every call returns **HTTP 200** and a body carrying:

| Field | Meaning |
|---|---|
| `response_code` | `S200` on success; otherwise an `E###` code (table below). On `updateCustomerField` only, an unknown field id comes back as the **free-text** string `"<id> is Invalid, "` — detect success by a leading `S`. |
| `response_ref_id` | Opaque per-call trace id; quote it in support tickets. |
| `response_code_desc` | Human-readable description; **empty** for several error codes that have no description row. |

The **only** non-200 is a malformed or empty JSON body, which the JSON layer rejects as **HTTP 500**
before the application runs.

### Error codes

| Code | Meaning |
|---|---|
| `S200` | Success. |
| `E108` | Authorization header missing. |
| `E101` | Bad or unrecognized token (its description text is misleadingly "Provide Xml input"). |
| `E100` | Token expired (outside its valid date window). |
| `E135` | Customer not found or inactive. |
| `E145` | `externalId` matched no identification record. |
| `E151` | `customFields` was empty (`updateCustomerField`). |
| `E152` | `groupType` missing. |
| `E153` | `groupType` not one of `CUSTOM_FIELD` / `SEGMENTATION` / `ECONOMIC_METRIC`. |
| `E154` | `groupId` missing (`searchGroupField`). |
| `E155` | Unknown `groupId`. |
| `E1001` | Invalid data — e.g. unknown id, or an id that already exists on a create. |
| `E1002` | Grouping code not found. |
| `E1004` | A value is outside its allowed vocabulary (LOV). |
| `E1006` | A required parameter is missing. |
| `E1020` | Invalid email. |
| `E1039` | Phone shorter than 10 digits. |

## Two things to know before you integrate

1. **Request key casing is not uniform.** `customer/v1` takes a nested `customerIdentifier` with
   camelCase keys and `searchGroup`/`searchGroupField` take camelCase (`groupType`/`groupId`), but the
   group/field **definition** and per-entity read operations take **snake_case** (`group_id`,
   `custom_field_id`, `grouping_code`, `domain_entity_type`, `domain_entity_id`, `custom_field_format`).
   Send keys exactly as each operation's request schema shows.
2. **Two storage families that do not share storage.** `customer/v1` reads and writes the
   *classification* store; `group/v1` reads the *field-value* store. A value written with
   `updateCustomerField` is **not** visible through `getAttributeGroupData`, and vice versa. **Read a
   value back through the same family you wrote it with.**

## Known issues (current build)

- **`createField` type validation is inverted** — it rejects the intended `custom_field_type` values
  `SINGLE`/`MULTIPLE` with `E1004` and accepts other strings. Prefer creating fields in the admin UI
  until this is fixed. Documented on the `Field/createField` request schema.
- **There is no working API path to write a `group/v1` field value for a customer.** The group-data
  write operation reports success but does not persist, so it is **not published here**; use
  `customer/v1/updateCustomerField` instead.

## Endpoint index

| Resource | Operation | Purpose | Auth enforced |
|---|---|---|---|
| customer | [searchCustomerField](Customer/searchCustomerField/) | Read a customer's values for one group type | yes |
| customer | [updateCustomerField](Customer/updateCustomerField/) | Set values on a customer | yes |
| group | [searchGroup](Group/searchGroup/) | List groups of a type (definitions) | no* |
| group | [searchGroupField](Group/searchGroupField/) | List a group's fields | yes |
| group | [getAttributeGroupData](Group/getAttributeGroupData/) | Read a group's values for a customer | no* |
| group | [getAttributeGroupCodeData](Group/getAttributeGroupCodeData/) | Read all groups under a grouping code for a customer | no* |
| group | [createGroup](Group/createGroup/) | Create a group definition | no* |
| group | [updateGroup](Group/updateGroup/) | Update a group definition | no* |
| group | [deleteGroup](Group/deleteGroup/) | Delete a group definition | no* |
| field | [createField](Field/createField/) | Create a field definition | no* |
| field | [updateField](Field/updateField/) | Update a field definition | no* |
| field | [deleteField](Field/deleteField/) | Delete a field definition | no* |

\* Not currently enforced by the service; see Authentication. Send the token anyway.

Each operation folder holds `{operation}-request.schema.json`, `{operation}-response.schema.json`
(JSON Schema, draft 2020-12), and an `examples/` directory with `request-sample.json` and
`response-sample.json`. Shared definitions are in [`common.schema.json`](common.schema.json). A single
OpenAPI 3.0 view of all operations is in
[`customfield-1.0-openapi.json`](customfield-1.0-openapi.json).
