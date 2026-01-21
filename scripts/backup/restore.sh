#!/bin/bash

# Supabase Restore Script
# Verwendung: ./restore.sh <backup-datei.sql.gz>

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

if [ -z "$1" ]; then
    echo "Verwendung: $0 <backup-datei.sql.gz>"
    echo ""
    echo "Verfuegbare Backups:"
    ls -lh /backups/supabase_*.sql.gz 2>/dev/null || echo "Keine Backups gefunden"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    # Versuche im Backup-Verzeichnis zu finden
    if [ -f "/backups/$BACKUP_FILE" ]; then
        BACKUP_FILE="/backups/$BACKUP_FILE"
    else
        log "${RED}Fehler: Backup-Datei nicht gefunden: ${BACKUP_FILE}${NC}"
        exit 1
    fi
fi

log "${YELLOW}=== WARNUNG ===${NC}"
log "Dies wird die aktuelle Datenbank UEBERSCHREIBEN!"
log "Backup-Datei: ${BACKUP_FILE}"
echo ""
read -p "Fortfahren? (ja/nein): " CONFIRM

if [ "$CONFIRM" != "ja" ]; then
    log "Abgebrochen."
    exit 0
fi

log "${GREEN}=== Supabase Restore gestartet ===${NC}"

# Aktive Verbindungen trennen
log "Trenne aktive Verbindungen..."
PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h "${POSTGRES_HOST:-db}" \
    -p "${POSTGRES_PORT:-5432}" \
    -U "${POSTGRES_USER:-postgres}" \
    -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${POSTGRES_DB:-postgres}' AND pid <> pg_backend_pid();" \
    2>/dev/null || true

# Datenbank wiederherstellen
log "Stelle Datenbank wieder her..."
gunzip -c "$BACKUP_FILE" | PGPASSWORD="${POSTGRES_PASSWORD}" pg_restore \
    -h "${POSTGRES_HOST:-db}" \
    -p "${POSTGRES_PORT:-5432}" \
    -U "${POSTGRES_USER:-postgres}" \
    -d "${POSTGRES_DB:-postgres}" \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl \
    2>&1 | grep -v "already exists" || true

log "${GREEN}=== Restore abgeschlossen ===${NC}"
log "Bitte starte die Services neu: docker compose restart"
