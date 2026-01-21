#!/bin/bash

# Supabase Automatic Backup Script
# Wird vom Backup-Container ausgefuehrt

set -e

# Konfiguration
BACKUP_DIR="/backups"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/supabase_${TIMESTAMP}.sql.gz"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "${GREEN}=== Supabase Backup gestartet ===${NC}"

# Backup-Verzeichnis pruefen
if [ ! -d "$BACKUP_DIR" ]; then
    log "${YELLOW}Erstelle Backup-Verzeichnis...${NC}"
    mkdir -p "$BACKUP_DIR"
fi

# PostgreSQL Backup erstellen
log "Erstelle Datenbank-Backup..."
PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
    -h "${POSTGRES_HOST:-db}" \
    -p "${POSTGRES_PORT:-5432}" \
    -U "${POSTGRES_USER:-postgres}" \
    -d "${POSTGRES_DB:-postgres}" \
    --no-owner \
    --no-acl \
    -Fc \
    | gzip > "$BACKUP_FILE"

# Backup-Groesse pruefen
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "${GREEN}Backup erstellt: ${BACKUP_FILE} (${BACKUP_SIZE})${NC}"

# Alte Backups loeschen
log "Loesche Backups aelter als ${RETENTION_DAYS} Tage..."
find "$BACKUP_DIR" -name "supabase_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
REMAINING=$(ls -1 "$BACKUP_DIR"/supabase_*.sql.gz 2>/dev/null | wc -l)
log "Verbleibende Backups: ${REMAINING}"

# Optional: Storage-Dateien sichern
if [ "${BACKUP_STORAGE:-false}" = "true" ] && [ -d "/storage" ]; then
    STORAGE_BACKUP="${BACKUP_DIR}/storage_${TIMESTAMP}.tar.gz"
    log "Erstelle Storage-Backup..."
    tar -czf "$STORAGE_BACKUP" -C /storage .
    STORAGE_SIZE=$(du -h "$STORAGE_BACKUP" | cut -f1)
    log "${GREEN}Storage-Backup erstellt: ${STORAGE_BACKUP} (${STORAGE_SIZE})${NC}"

    # Alte Storage-Backups loeschen
    find "$BACKUP_DIR" -name "storage_*.tar.gz" -mtime +${RETENTION_DAYS} -delete
fi

# Optional: Upload zu S3/MinIO
if [ -n "${S3_BUCKET}" ] && [ -n "${AWS_ACCESS_KEY_ID}" ]; then
    log "Lade Backup zu S3 hoch..."
    aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/backups/$(basename $BACKUP_FILE)"
    log "${GREEN}S3 Upload abgeschlossen${NC}"
fi

# Webhook-Benachrichtigung (optional)
if [ -n "${BACKUP_WEBHOOK_URL}" ]; then
    curl -s -X POST "$BACKUP_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"status\":\"success\",\"file\":\"${BACKUP_FILE}\",\"size\":\"${BACKUP_SIZE}\",\"timestamp\":\"${TIMESTAMP}\"}" \
        || log "${YELLOW}Webhook-Benachrichtigung fehlgeschlagen${NC}"
fi

log "${GREEN}=== Backup abgeschlossen ===${NC}"
