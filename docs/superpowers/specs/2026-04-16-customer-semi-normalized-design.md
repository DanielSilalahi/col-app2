# Customer Semi-Normalized Design

## Summary

This design restructures the current P2P `Customer` model into a semi-normalized data model suitable for:

- admin dashboard list views and operational filters
- borrower, contact, address, and loan data with cleaner boundaries
- bulk Excel imports from multiple partners with inconsistent headers and value formats
- future growth without turning `customers` into an oversized catch-all table

The recommended approach keeps `customers` as the operational master record and moves heavy, repetitive, or partner-specific data into category tables.

## Goals

- Keep dashboard queries simple for common collection workflows
- Support multiple phone numbers, addresses, and loans per customer
- Preserve raw import data for auditability and reparsing
- Handle dirty partner data such as combined `lat&lng`, mixed currency strings, and inconsistent headers
- Avoid over-normalizing the schema at the current stage

## Non-Goals

- Full event-sourced history for every field change
- A complete payment ledger replacement
- A full generic ETL engine or partner mapping UI

## Current Problems

The current `customers` table mixes several concerns:

- borrower identity
- address and location
- loan data
- emergency contacts
- collection status

This makes the model harder to extend when:

- one borrower has multiple numbers
- one borrower has more than one useful address
- a partner sends fields in a different shape
- multiple loans or refreshed snapshots must be supported

## Recommended Architecture

### Core tables to implement now

- `customers`
- `customer_contacts`
- `customer_addresses`
- `customer_loans`
- `customer_import_rows`

### Existing related tables to keep using

- `collections`
- `va_requests`
- `activity_log`

### Tables intentionally deferred

- `payments`
- `customer_assignments`
- `customer_documents`
- `customer_tags`
- `customer_import_mappings`

## Data Ownership Model

The design distinguishes between source-of-truth tables and dashboard snapshot fields.

### Source of truth

- contact detail lives in `customer_contacts`
- address detail and coordinates live in `customer_addresses`
- loan and delinquency detail live in `customer_loans`
- raw partner import data lives in `customer_import_rows`

### Dashboard snapshot

`customers` keeps lightweight fields that are frequently used by the admin dashboard, such as:

- primary phone
- primary city
- primary address summary
- current loan pointer
- current DPD
- current total outstanding
- last payment date
- last payment amount
- last contacted timestamp

This is intentional denormalization for list performance and operational simplicity.

## Table Design

### 1. `customers`

Purpose:

- master borrower record
- lightweight dashboard snapshot
- stable identity anchor for related tables

Recommended columns:

- `id`
- `full_name`
- `nick_name`
- `customer_code`
- `external_customer_id`
- `platform_name`
- `partner_name`
- `nik`
- `birth_date`
- `gender`
- `email`
- `primary_phone`
- `primary_city`
- `primary_address_summary`
- `assigned_agent_id`
- `status`
- `sub_status`
- `current_loan_id`
- `current_dpd`
- `current_total_outstanding`
- `last_payment_date`
- `last_payment_amount`
- `last_contacted_at`
- `upload_batch`
- `search_name`
- `search_nik`
- `is_deleted`
- `created_at`
- `updated_at`

Notes:

- `search_name` and `search_nik` are normalized search helper fields
- `current_loan_id` points to the active or primary loan snapshot
- `status` and `sub_status` remain on `customers` for fast dashboard filtering

### 2. `customer_contacts`

Purpose:

- store all borrower and related-party contacts
- support multiple phone numbers and contact roles
- replace fixed emergency contact columns

Recommended columns:

- `id`
- `customer_id`
- `contact_type`
- `contact_role`
- `name`
- `relationship`
- `phone_number`
- `email`
- `is_primary`
- `priority_order`
- `is_whatsapp`
- `is_active`
- `is_verified`
- `is_valid`
- `verification_source`
- `notes`
- `created_at`
- `updated_at`

Suggested controlled values:

- `contact_type`: `phone`, `whatsapp`, `email`
- `contact_role`: `self`, `emergency`, `family`, `guarantor`, `office`

### 3. `customer_addresses`

Purpose:

- store home, office, billing, and other addresses
- keep canonical and raw location values
- support future field collection and mapping flows

Recommended columns:

- `id`
- `customer_id`
- `address_type`
- `label`
- `recipient_name`
- `full_address`
- `street`
- `block`
- `house_number`
- `rt`
- `rw`
- `kelurahan`
- `kecamatan`
- `city`
- `province`
- `postal_code`
- `country`
- `landmark`
- `address_note`
- `residence_status`
- `is_primary`
- `is_active`
- `lat`
- `lng`
- `map_url`
- `coordinate_source`
- `coordinate_accuracy_meters`
- `is_location_verified`
- `raw_lat`
- `raw_lng`
- `raw_lat_lng`
- `raw_map_link`
- `created_at`
- `updated_at`

Suggested controlled values:

- `address_type`: `home`, `office`, `billing`, `emergency`, `other`

Key import behavior:

- canonical values go to `lat` and `lng`
- original Excel or partner values remain in raw coordinate fields
- values like `lat,lng`, `lat&lng`, or map links can be reparsed later without data loss

### 4. `customer_loans`

Purpose:

- store loan contract data and collection-relevant financial snapshots
- support more than one loan per borrower
- become the source of truth for delinquency and outstanding values

Recommended columns:

- `id`
- `customer_id`
- `is_current`
- `application_id`
- `loan_number`
- `contract_number`
- `agreement_number`
- `product_type`
- `product_name`
- `platform_name`
- `disbursement_date`
- `first_due_date`
- `due_date`
- `last_due_date`
- `maturity_date`
- `tenor`
- `installment_number`
- `remaining_installment_count`
- `payment_frequency`
- `loan_amount`
- `principal_amount`
- `interest_amount`
- `admin_fee_amount`
- `penalty_amount`
- `insurance_fee_amount`
- `other_fee_amount`
- `installment_amount`
- `outstanding_principal`
- `outstanding_interest`
- `outstanding_penalty`
- `outstanding_fee`
- `total_outstanding`
- `remaining_balance`
- `overdue_days`
- `days_past_due`
- `dpd_bucket`
- `aging_bucket`
- `bucket_code`
- `loan_status`
- `billing_status`
- `collection_stage`
- `risk_segment`
- `risk_score`
- `last_payment_date`
- `last_payment_amount`
- `last_payment_channel`
- `last_payment_reference`
- `paid_amount_total`
- `payment_status`
- `promise_to_pay_date`
- `promise_to_pay_amount`
- `promise_to_pay_status`
- `broken_ptp_count`
- `settlement_offer_amount`
- `settlement_expiry_date`
- `minimum_payment_amount`
- `created_at`
- `updated_at`

Implementation note:

- money values should use `Numeric(18, 2)`, not `Float`
- `customers.current_loan_id` should reference `customer_loans.id`

### 5. `customer_import_rows`

Purpose:

- preserve raw import rows from Excel or partner files
- support audit, reparsing, debugging, and partner-specific mapping
- isolate dirty import data from normalized operational tables

Recommended columns:

- `id`
- `customer_id`
- `upload_batch`
- `source_partner_name`
- `source_partner_code`
- `source_file_name`
- `source_sheet_name`
- `source_row_number`
- `mapping_profile_name`
- `import_version`
- `import_status`
- `import_error_flag`
- `import_error_message`
- `imported_at`
- `raw_customer_name`
- `raw_nik`
- `raw_phone`
- `raw_phone_2`
- `raw_address`
- `raw_city`
- `raw_due_date`
- `raw_disbursement_date`
- `raw_loan_amount`
- `raw_installment_amount`
- `raw_outstanding_amount`
- `raw_overdue_days`
- `raw_lat`
- `raw_lng`
- `raw_lat_lng`
- `raw_platform_name`
- `raw_status`
- `raw_payload`

Implementation note:

- `raw_payload` should use `JSON` when supported by the active database
- otherwise use `Text` as a fallback

## Relationship Design

- `customers` 1..N `customer_contacts`
- `customers` 1..N `customer_addresses`
- `customers` 1..N `customer_loans`
- `customers` 1..N `customer_import_rows`
- `customers` N..1 `users` through `assigned_agent_id`
- `customers` 1..N `collections`
- `customers` 1..N `va_requests`

## Type Recommendations

- money: `Numeric(18, 2)`
- coordinates: `Float`
- pure dates: `Date`
- activity timestamps: `DateTime`
- short codes and statuses: `String`
- long free-text and raw messages: `Text`
- flags: `Integer` 0 or 1 for cross-DB consistency with the existing codebase
- JSON-like raw row storage: `JSON` or `Text`

## Index Recommendations

### `customers`

- `full_name`
- `search_name`
- `nik`
- `customer_code`
- `external_customer_id`
- `platform_name`
- `status`
- `sub_status`
- `assigned_agent_id`
- `current_loan_id`
- `upload_batch`
- `is_deleted`

### `customer_contacts`

- `customer_id`
- `phone_number`
- `contact_role`
- `is_primary`
- `is_active`

### `customer_addresses`

- `customer_id`
- `address_type`
- `city`
- `province`
- `postal_code`
- `is_primary`

### `customer_loans`

- `customer_id`
- `loan_number`
- `contract_number`
- `application_id`
- `is_current`
- `due_date`
- `overdue_days`
- `loan_status`
- `collection_stage`
- `platform_name`

### `customer_import_rows`

- `customer_id`
- `upload_batch`
- `source_partner_name`
- `source_file_name`
- `source_row_number`
- `import_status`
- `import_error_flag`

## Controlled Values

Recommended `customers.status` values:

- `new`
- `active`
- `contacted`
- `rpc`
- `ptp`
- `paid_partial`
- `paid_full`
- `unreachable`
- `skip`
- `closed`

Recommended `customers.sub_status` values:

- `no_answer`
- `busy`
- `switched_off`
- `wrong_number`
- `invalid_number`
- `customer_moved`
- `address_not_found`
- `refuse_to_pay`
- `need_follow_up`
- `promise_to_pay`
- `settlement_offered`
- `paid_waiting_verification`

Recommended `customer_loans.collection_stage` values:

- `desk_soft`
- `desk_hard`
- `field_visit`
- `supervisor_handling`
- `legal`
- `write_off`

Recommended `customer_import_rows.import_status` values:

- `imported`
- `parsed_with_warning`
- `failed_mapping`
- `failed_validation`

## Migration Strategy

Phase 1:

- update `customers` into a lighter snapshot model
- create `customer_contacts`
- create `customer_addresses`
- create `customer_loans`
- create `customer_import_rows`

Phase 2:

- migrate current `phone` data into `customers.primary_phone` and `customer_contacts`
- migrate current `address`, `lat`, and `lng` into `customer_addresses`
- migrate current loan fields into `customer_loans`
- keep `customers` snapshot values in sync from the selected active loan and primary records

Phase 3:

- optionally introduce payment, assignment, and document tables

## Compatibility Notes

The current fields:

- `name`
- `address`
- `phone`
- `lat`
- `lng`
- `loan_number`
- `platform_name`
- `outstanding_amount`
- `due_date`
- `overdue_days`
- emergency contact fields

should transition as follows:

- `name` becomes `full_name`
- `phone` becomes `primary_phone` plus rows in `customer_contacts`
- `address`, `lat`, and `lng` move to `customer_addresses`
- loan fields move to `customer_loans`
- emergency contacts move to `customer_contacts`
- `platform_name` remains on `customers` as a snapshot and also exists on `customer_loans`

## Risks and Mitigations

Risk:

- snapshot fields may drift from source-of-truth tables

Mitigation:

- define a single sync path during import and update flows

Risk:

- partner formats may exceed the predefined raw columns

Mitigation:

- retain `raw_payload` for the full original row

Risk:

- multi-loan borrowers may complicate dashboard summaries

Mitigation:

- explicitly mark one active row with `customer_loans.is_current`
- store `customers.current_loan_id`

## Final Recommendation

Implement the semi-normalized model now with:

- a lightweight `customers` table
- category tables for contacts, addresses, and loans
- a raw import table for Excel compatibility and auditability

This delivers a cleaner schema without over-engineering the current backend.
