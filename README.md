# Supabase Self-Hosted Docker Setup

Lokale Supabase-Installation mit Docker Compose - inklusive Production-Features.

## Features

- **Basis-Setup**: Alle Supabase Core-Services
- **pgvector**: AI/Embeddings mit Vektor-Suche
- **Automatische Backups**: Taeglich mit konfigurierbarer Retention
- **SSL/HTTPS**: Let's Encrypt via Traefik
- **Monitoring**: Prometheus + Grafana Dashboards
- **Secrets Management**: HashiCorp Vault

## Voraussetzungen

- Docker >= 20.10
- Docker Compose >= 2.0
- 4GB RAM (empfohlen: 8GB, Production: 16GB)
- 10GB freier Festplattenspeicher

## Schnellstart (Entwicklung)

### 1. Repository klonen

```bash
git clone <repository-url>
cd supabase
```

### 2. Umgebungsvariablen konfigurieren

```bash
# Beispiel-Konfiguration kopieren
cp .env.example .env

# Sichere Secrets generieren
./scripts/generate-keys.sh

# Generierte Werte in .env eintragen
nano .env
```

### 3. Supabase starten

```bash
docker compose up -d
```

### 4. Status pruefen

```bash
docker compose ps
```

## Production Setup

Fuer Produktion mit SSL, Monitoring und automatischen Backups:

### 1. Production-Konfiguration

```bash
# Basis + Production Konfiguration
cp .env.example .env
cp .env.production.example .env.production

# Secrets generieren
./scripts/generate-keys.sh

# Beide Dateien anpassen
nano .env
nano .env.production

# htpasswd Auth-Strings generieren
htpasswd -nb admin your-password
```

### 2. Mit Production-Services starten

```bash
# Netzwerk erstellen
docker network create supabase-network

# Alle Services starten
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

### 3. Vault initialisieren (optional)

```bash
./scripts/vault-init.sh
```

## Zugriff

### Entwicklung (localhost)

| Service | URL | Beschreibung |
|---------|-----|--------------|
| Studio (Dashboard) | http://localhost:3000 | Web-Interface |
| API Gateway | http://localhost:8000 | REST/Realtime API |
| PostgreSQL | localhost:5432 | Datenbank |

### Production (mit Domain)

| Service | URL | Beschreibung |
|---------|-----|--------------|
| Studio | https://supabase.example.com | Dashboard |
| API | https://api.supabase.example.com | REST/Realtime |
| Grafana | https://grafana.supabase.example.com | Monitoring |
| Prometheus | https://prometheus.supabase.example.com | Metriken |
| Traefik | https://traefik.supabase.example.com | Proxy Dashboard |
| Vault | https://vault.supabase.example.com | Secrets |

## Architektur

```
                    +------------------+
                    |    Traefik       |  (SSL/Proxy)
                    +--------+---------+
                             |
+--------+          +--------v---------+
| Client | -------> |      Kong        |  (API Gateway)
+--------+          +--------+---------+
                             |
         +-------------------+-------------------+
         |         |         |         |         |
    +----v---+ +---v----+ +--v---+ +---v---+ +---v----+
    | GoTrue | | REST   | |Real- | |Storage| |  Edge  |
    | (Auth) | |(Post-  | |time  | |       | |Funcs   |
    +--------+ | gREST) | +------+ +-------+ +--------+
         |     +--------+     |         |         |
         |         |          |         |         |
         +----+----+----+-----+----+----+----+----+
              |              |              |
         +----v----+    +----v----+    +----v----+
         |PostgreSQL|   |imgproxy |    | Deno    |
         |+pgvector |   +---------+    +---------+
         +---------+
              |
    +---------+---------+
    |                   |
+---v---+          +----v----+
|Backup |          |Prometheus|
|Service|          | Grafana  |
+-------+          +----------+
```

## Services

### Core Services

| Service | Beschreibung |
|---------|--------------|
| PostgreSQL + pgvector | Datenbank mit Vektor-Suche |
| GoTrue | Authentifizierung |
| PostgREST | REST API |
| Realtime | WebSocket Subscriptions |
| Storage | Dateispeicherung |
| Edge Functions | Serverless (Deno) |
| Kong | API Gateway |
| Studio | Dashboard |

### Production Services

| Service | Beschreibung |
|---------|--------------|
| Traefik | Reverse Proxy + SSL |
| Backup | Automatische DB-Backups |
| Prometheus | Metriken-Sammlung |
| Grafana | Visualisierung |
| Vault | Secrets Management |

## pgvector - AI/Embeddings

pgvector ist vorinstalliert und aktiviert. Beispiel-Nutzung:

```sql
-- Dokument mit Embedding speichern
INSERT INTO documents (content, embedding, metadata)
VALUES (
  'Mein Text',
  '[0.1, 0.2, ...]'::vector(1536),
  '{"source": "api"}'
);

-- Aehnliche Dokumente finden
SELECT * FROM match_documents(
  '[0.1, 0.2, ...]'::vector(1536),
  0.78,  -- Schwellwert
  10     -- Anzahl Ergebnisse
);
```

### Mit OpenAI Embeddings

```typescript
import { createClient } from '@supabase/supabase-js'
import OpenAI from 'openai'

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)
const openai = new OpenAI()

// Embedding erstellen
const response = await openai.embeddings.create({
  model: 'text-embedding-ada-002',
  input: 'Mein Text'
})

// In Supabase speichern
await supabase.from('documents').insert({
  content: 'Mein Text',
  embedding: response.data[0].embedding
})
```

## Automatische Backups

Backups werden taeglich um 02:00 Uhr erstellt (konfigurierbar).

### Konfiguration

```env
# Backup-Zeitplan (Cron)
BACKUP_SCHEDULE=0 2 * * *

# Aufbewahrungsdauer
BACKUP_RETENTION_DAYS=7

# Auch Storage sichern
BACKUP_STORAGE=true

# Optional: S3 Upload
S3_BUCKET=my-backup-bucket
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

### Manuelles Backup

```bash
docker compose exec backup /scripts/backup.sh
```

### Restore

```bash
docker compose exec backup /scripts/restore.sh supabase_20240101_020000.sql.gz
```

### Backup-Verzeichnis

Backups werden in `./volumes/backups/` gespeichert.

## Monitoring

### Grafana Dashboard

1. Oeffne https://grafana.your-domain.com (oder http://localhost:3001)
2. Login mit `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`
3. Das "Supabase Overview" Dashboard ist vorinstalliert

### Verfuegbare Metriken

- CPU/Memory/Disk Auslastung
- PostgreSQL Verbindungen
- Datenbankgroesse
- Container-Ressourcen
- HTTP Request-Metriken (via Traefik)

### Prometheus Queries

```promql
# PostgreSQL aktive Verbindungen
pg_stat_activity_count

# Container Memory
container_memory_usage_bytes{name=~"supabase.*"}

# CPU Auslastung
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

## Vault Secrets Management

### Initialisierung

```bash
# Nach dem Start von Vault
./scripts/vault-init.sh
```

### Secrets abrufen

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=your-root-token

# Datenbank-Credentials
vault kv get supabase/database

# JWT Secrets
vault kv get supabase/jwt
```

### In Anwendungen

```javascript
// Mit Vault AppRole
const roleId = process.env.VAULT_ROLE_ID
const secretId = process.env.VAULT_SECRET_ID

// Token holen und Secrets abrufen
```

## SSL/HTTPS mit Traefik

### Automatische Zertifikate

Let's Encrypt Zertifikate werden automatisch erstellt und erneuert.

### DNS Konfiguration

Erstelle folgende DNS-Eintraege:

```
supabase.example.com     -> Server IP
api.supabase.example.com -> Server IP
grafana.supabase.example.com -> Server IP
```

### Eigene Zertifikate

Fuer eigene Zertifikate, lege sie in `./volumes/traefik/` ab und passe die Traefik-Konfiguration an.

## Befehle

```bash
# === Entwicklung ===
docker compose up -d
docker compose down
docker compose logs -f

# === Production ===
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d
docker compose -f docker-compose.yml -f docker-compose.production.yml down
docker compose -f docker-compose.yml -f docker-compose.production.yml logs -f

# === Einzelne Services ===
docker compose logs -f db
docker compose restart auth

# === Datenbank ===
docker compose exec db psql -U postgres

# === Backup ===
docker compose exec backup /scripts/backup.sh
docker compose exec backup /scripts/restore.sh <datei>

# === Alle Daten loeschen (Vorsicht!) ===
docker compose down -v
rm -rf volumes/db/data volumes/storage/* volumes/backups/*
```

## Edge Functions

### Neue Function erstellen

```bash
mkdir volumes/functions/meine-funktion
```

Erstelle `volumes/functions/meine-funktion/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { data, error } = await supabase
    .from('users')
    .select('*')
    .limit(10);

  return new Response(
    JSON.stringify({ data, error }),
    { headers: { "Content-Type": "application/json" } }
  );
});
```

## Fehlerbehebung

### Services starten nicht

```bash
docker compose logs
docker compose logs db
docker compose logs auth
```

### Datenbank-Verbindungsfehler

```bash
docker compose ps db
docker compose logs db
docker compose exec db pg_isready
```

### SSL-Zertifikat Fehler

```bash
# Traefik Logs pruefen
docker compose -f docker-compose.yml -f docker-compose.production.yml logs traefik

# Zertifikate pruefen
ls -la volumes/traefik/
```

### Backup fehlgeschlagen

```bash
# Backup-Logs
docker compose exec backup cat /var/log/backup.log

# Manuell ausfuehren
docker compose exec backup /scripts/backup.sh
```

## Upgrade

```bash
# 1. Backup erstellen
docker compose exec backup /scripts/backup.sh

# 2. Images aktualisieren
docker compose pull
docker compose -f docker-compose.yml -f docker-compose.production.yml pull

# 3. Neustart
docker compose up -d
# oder fuer Production:
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

## Dateistruktur

```
supabase/
├── docker-compose.yml           # Basis-Services
├── docker-compose.production.yml # Production-Services
├── .env.example                  # Basis-Konfiguration
├── .env.production.example       # Production-Konfiguration
├── scripts/
│   ├── generate-keys.sh         # API Key Generator
│   ├── vault-init.sh            # Vault Setup
│   └── backup/
│       ├── backup.sh            # Backup-Skript
│       └── restore.sh           # Restore-Skript
└── volumes/
    ├── db/
    │   ├── data/                # PostgreSQL Daten
    │   └── init/                # Init-Skripte (pgvector)
    ├── kong/kong.yml            # API Gateway Config
    ├── storage/                 # Datei-Storage
    ├── functions/               # Edge Functions
    ├── backups/                 # Backup-Dateien
    ├── traefik/                 # SSL Zertifikate
    ├── prometheus/              # Prometheus Config
    ├── grafana/                 # Grafana Dashboards
    └── vault/                   # Vault Config
```

## Ressourcen

- [Supabase Dokumentation](https://supabase.com/docs)
- [Self-Hosting Guide](https://supabase.com/docs/guides/self-hosting)
- [pgvector](https://github.com/pgvector/pgvector)
- [Traefik Dokumentation](https://doc.traefik.io/traefik/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [HashiCorp Vault](https://www.vaultproject.io/docs)

## Lizenz

Dieses Setup basiert auf der offiziellen Supabase-Konfiguration.
Supabase ist unter der Apache 2.0 Lizenz veroeffentlicht.
