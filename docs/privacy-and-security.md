# Privacy and security

AI Limits follows a collector-and-snapshot design. Provider authentication remains in the provider's own local storage on the Mac. The collector reads it only to perform the requested usage query.

## Allowed snapshot data

- provider identifier and display name
- opaque account identifier
- plan label
- usage percentages, numeric balances and reset timestamps
- estimated token/cost history
- typed, credential-free error category
- generated and last-updated timestamps

## Prohibited snapshot data

- access or refresh tokens, API keys and cookies
- authorization headers and raw HTTP bodies
- prompts, responses, filenames and repository paths
- personal email addresses by default

CloudKit uses the private database. Local files are written atomically. Logging must redact secrets before interpolation.

