# Production Payments domain policy
# Bound only to production Payments workload identities.

path "secret/data/prod/payments/*" {
  capabilities = ["read"]
}

path "secret/metadata/prod/payments/*" {
  capabilities = ["read", "list"]
}

path "database/creds/prod-payments-app" {
  capabilities = ["read"]
}

path "transit/encrypt/cardholder-data" {
  capabilities = ["update"]
}

path "transit/decrypt/cardholder-data" {
  capabilities = ["update"]
}
