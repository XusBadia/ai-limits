# CloudKit schema

AI Limits uses the private database in `iCloud.me.badia.ailimits`. The production schema was deployed on 2026-08-15.

## `UsageSnapshot`

| Field | CloudKit type | Purpose |
| --- | --- | --- |
| `schemaVersion` | `Int(64)` | Validates compatibility before decoding. |
| `generatedAt` | `Date/Time` | Exposes snapshot age without reading the payload. |
| `payload` | `Encrypted Bytes` | Stores the normalized `SnapshotEnvelope`. |

The record lives in the private custom zone `AILimitsPrivateV1` with record name `current-snapshot`. CloudKit metadata fields are managed by Apple. No query indexes are required because clients address the record directly by ID.

Never add provider credentials, cookies, authorization headers, prompts, or raw provider responses to this schema. Schema changes must be created in CloudKit's development environment, reviewed, and then deployed to production.
