#!/bin/bash

# Vault Initialisierung fuer Supabase
# Verwendung: ./vault-init.sh

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Vault Adresse
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"

log "${GREEN}=== Vault Initialisierung fuer Supabase ===${NC}"
log "Vault Adresse: ${VAULT_ADDR}"

# Pruefen ob Vault erreichbar ist
if ! curl -s "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
    log "${RED}Fehler: Vault ist nicht erreichbar unter ${VAULT_ADDR}${NC}"
    log "Stelle sicher dass Vault laeuft: docker compose -f docker-compose.yml -f docker-compose.production.yml up -d vault"
    exit 1
fi

# Token pruefen
if [ -z "$VAULT_TOKEN" ]; then
    log "${YELLOW}VAULT_TOKEN nicht gesetzt. Verwende Root-Token aus .env${NC}"
    if [ -f ".env" ]; then
        export VAULT_TOKEN=$(grep VAULT_ROOT_TOKEN .env | cut -d '=' -f2)
    fi
fi

if [ -z "$VAULT_TOKEN" ]; then
    log "${RED}Fehler: VAULT_TOKEN nicht gefunden${NC}"
    exit 1
fi

export VAULT_ADDR
export VAULT_TOKEN

# KV Secrets Engine aktivieren
log "Aktiviere KV Secrets Engine..."
vault secrets enable -path=supabase kv-v2 2>/dev/null || log "${YELLOW}KV Engine bereits aktiviert${NC}"

# Secrets aus .env lesen und in Vault speichern
if [ -f ".env" ]; then
    log "Lese Secrets aus .env..."

    # PostgreSQL Secrets
    POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d '=' -f2)
    vault kv put supabase/database \
        password="${POSTGRES_PASSWORD}" \
        host="db" \
        port="5432" \
        database="postgres"
    log "${GREEN}PostgreSQL Secrets gespeichert${NC}"

    # JWT Secrets
    JWT_SECRET=$(grep JWT_SECRET .env | cut -d '=' -f2)
    ANON_KEY=$(grep ANON_KEY .env | cut -d '=' -f2)
    SERVICE_ROLE_KEY=$(grep SERVICE_ROLE_KEY .env | cut -d '=' -f2)
    vault kv put supabase/jwt \
        secret="${JWT_SECRET}" \
        anon_key="${ANON_KEY}" \
        service_role_key="${SERVICE_ROLE_KEY}"
    log "${GREEN}JWT Secrets gespeichert${NC}"

    # SMTP Secrets (falls vorhanden)
    SMTP_USER=$(grep SMTP_USER .env 2>/dev/null | cut -d '=' -f2 || echo "")
    SMTP_PASS=$(grep SMTP_PASS .env 2>/dev/null | cut -d '=' -f2 || echo "")
    if [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ]; then
        vault kv put supabase/smtp \
            user="${SMTP_USER}" \
            password="${SMTP_PASS}"
        log "${GREEN}SMTP Secrets gespeichert${NC}"
    fi

    # Dashboard Secrets
    DASHBOARD_PASSWORD=$(grep DASHBOARD_PASSWORD .env | cut -d '=' -f2)
    vault kv put supabase/dashboard \
        username="supabase" \
        password="${DASHBOARD_PASSWORD}"
    log "${GREEN}Dashboard Secrets gespeichert${NC}"

else
    log "${RED}Fehler: .env Datei nicht gefunden${NC}"
    exit 1
fi

# Policy erstellen
log "Erstelle Vault Policy..."
vault policy write supabase-read - <<EOF
# Supabase Read Policy
path "supabase/data/*" {
  capabilities = ["read", "list"]
}
path "supabase/metadata/*" {
  capabilities = ["read", "list"]
}
EOF
log "${GREEN}Policy 'supabase-read' erstellt${NC}"

# AppRole fuer Services erstellen
log "Erstelle AppRole..."
vault auth enable approle 2>/dev/null || log "${YELLOW}AppRole bereits aktiviert${NC}"

vault write auth/approle/role/supabase-services \
    token_policies="supabase-read" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=10m \
    secret_id_num_uses=40

# Role ID und Secret ID ausgeben
ROLE_ID=$(vault read -field=role_id auth/approle/role/supabase-services/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/supabase-services/secret-id)

log ""
log "${GREEN}=== Vault Initialisierung abgeschlossen ===${NC}"
log ""
log "AppRole Credentials (fuer Services):"
log "  ROLE_ID: ${ROLE_ID}"
log "  SECRET_ID: ${SECRET_ID}"
log ""
log "Secrets abrufen:"
log "  vault kv get supabase/database"
log "  vault kv get supabase/jwt"
log "  vault kv get supabase/smtp"
log "  vault kv get supabase/dashboard"
log ""
log "${YELLOW}WICHTIG: Speichere diese Credentials sicher!${NC}"
