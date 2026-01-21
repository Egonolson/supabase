#!/bin/bash

# Supabase API Key Generator
# Dieses Skript generiert die notwendigen JWT-Tokens fuer Supabase

set -e

# Farben fuer Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Supabase API Key Generator ===${NC}"
echo ""

# JWT_SECRET generieren oder aus Parameter nehmen
if [ -z "$1" ]; then
    echo -e "${YELLOW}Generiere neuen JWT_SECRET...${NC}"
    JWT_SECRET=$(openssl rand -base64 32)
else
    JWT_SECRET="$1"
fi

echo -e "JWT_SECRET: ${GREEN}${JWT_SECRET}${NC}"
echo ""

# Funktion zum Erstellen eines JWT
generate_jwt() {
    local role=$1
    local secret=$2

    # Header
    local header='{"alg":"HS256","typ":"JWT"}'
    local header_base64=$(echo -n "$header" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    # Payload
    local iat=$(date +%s)
    local exp=$((iat + 157680000)) # 5 Jahre
    local payload="{\"role\":\"${role}\",\"iss\":\"supabase\",\"iat\":${iat},\"exp\":${exp}}"
    local payload_base64=$(echo -n "$payload" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    # Signature
    local signature=$(echo -n "${header_base64}.${payload_base64}" | openssl dgst -sha256 -hmac "$secret" -binary | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    echo "${header_base64}.${payload_base64}.${signature}"
}

# Anon Key generieren
echo -e "${YELLOW}Generiere ANON_KEY...${NC}"
ANON_KEY=$(generate_jwt "anon" "$JWT_SECRET")
echo -e "ANON_KEY: ${GREEN}${ANON_KEY}${NC}"
echo ""

# Service Role Key generieren
echo -e "${YELLOW}Generiere SERVICE_ROLE_KEY...${NC}"
SERVICE_ROLE_KEY=$(generate_jwt "service_role" "$JWT_SECRET")
echo -e "SERVICE_ROLE_KEY: ${GREEN}${SERVICE_ROLE_KEY}${NC}"
echo ""

# PostgreSQL Passwort generieren
echo -e "${YELLOW}Generiere POSTGRES_PASSWORD...${NC}"
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')
echo -e "POSTGRES_PASSWORD: ${GREEN}${POSTGRES_PASSWORD}${NC}"
echo ""

# Secret Key Base generieren
echo -e "${YELLOW}Generiere SECRET_KEY_BASE...${NC}"
SECRET_KEY_BASE=$(openssl rand -base64 48 | tr -d '/+=')
echo -e "SECRET_KEY_BASE: ${GREEN}${SECRET_KEY_BASE}${NC}"
echo ""

# Dashboard Passwort generieren
echo -e "${YELLOW}Generiere DASHBOARD_PASSWORD...${NC}"
DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=')
echo -e "DASHBOARD_PASSWORD: ${GREEN}${DASHBOARD_PASSWORD}${NC}"
echo ""

# Logflare API Key generieren
echo -e "${YELLOW}Generiere LOGFLARE_API_KEY...${NC}"
LOGFLARE_API_KEY=$(openssl rand -hex 16)
echo -e "LOGFLARE_API_KEY: ${GREEN}${LOGFLARE_API_KEY}${NC}"
echo ""

echo -e "${GREEN}=== .env Datei Inhalt ===${NC}"
echo ""
cat << EOF
# Generierte Secrets - $(date)

# PostgreSQL
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# JWT
JWT_SECRET=${JWT_SECRET}

# API Keys
ANON_KEY=${ANON_KEY}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}

# Realtime
SECRET_KEY_BASE=${SECRET_KEY_BASE}

# Dashboard
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}

# Analytics
LOGFLARE_API_KEY=${LOGFLARE_API_KEY}
EOF

echo ""
echo -e "${YELLOW}Tipp: Kopiere diese Werte in deine .env Datei${NC}"
echo -e "${RED}WICHTIG: Bewahre diese Secrets sicher auf!${NC}"
