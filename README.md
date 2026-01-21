# Supabase Self-Hosted Docker Setup

Lokale Supabase-Installation mit Docker Compose.

## Voraussetzungen

- Docker >= 20.10
- Docker Compose >= 2.0
- 4GB RAM (empfohlen: 8GB)
- 10GB freier Festplattenspeicher

## Schnellstart

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

## Zugriff

Nach dem Start sind folgende Dienste verfuegbar:

| Service | URL | Beschreibung |
|---------|-----|--------------|
| Studio (Dashboard) | http://localhost:3000 | Web-Interface |
| API Gateway | http://localhost:8000 | REST/Realtime API |
| PostgreSQL | localhost:5432 | Datenbank |

### Dashboard Login

- URL: http://localhost:3000
- Benutzername: Wert von `DASHBOARD_USERNAME` (Standard: `supabase`)
- Passwort: Wert von `DASHBOARD_PASSWORD`

## Architektur

```
                                    +------------------+
                                    |    Studio        |
                                    |   (Dashboard)    |
                                    +--------+---------+
                                             |
+--------+     +-------+            +--------v---------+
| Client | --> | Kong  | ---------> |  Meta Service    |
+--------+     | (API  |            +------------------+
               | Gate- |
               | way)  | ---------> +------------------+
               +---+---+            |    GoTrue        |
                   |                |  (Auth Service)  |
                   |                +------------------+
                   |
                   | ---------> +------------------+
                   |            |   PostgREST      |
                   |            |  (REST API)      |
                   |            +------------------+
                   |
                   | ---------> +------------------+
                   |            |    Realtime      |
                   |            | (WebSockets)     |
                   |            +------------------+
                   |
                   | ---------> +------------------+
                   |            |    Storage       |
                   |            | (Dateispeicher)  |
                   |            +------------------+
                   |
                   | ---------> +------------------+
                               |  Edge Functions  |
                               |     (Deno)       |
                               +------------------+
                                        |
                                        v
                               +------------------+
                               |   PostgreSQL     |
                               |   (Datenbank)    |
                               +------------------+
```

## Services

### PostgreSQL
- Hauptdatenbank mit Supabase-Erweiterungen
- Port: 5432
- Includes: uuid-ossp, pgcrypto, pgjwt

### GoTrue (Auth)
- Authentifizierung und Benutzerverwaltung
- Email/Password, OAuth, Magic Links
- JWT Token-Verwaltung

### PostgREST (REST API)
- Automatische REST API aus PostgreSQL Schema
- Endpunkt: `/rest/v1/`

### Realtime
- WebSocket-basierte Echtzeit-Subscriptions
- Endpunkt: `/realtime/v1/`

### Storage
- Dateispeicherung mit Policies
- Bildtransformationen via imgproxy
- Endpunkt: `/storage/v1/`

### Edge Functions
- Serverless Functions mit Deno
- Endpunkt: `/functions/v1/`

### Kong
- API Gateway und Routing
- Authentifizierung via API Keys
- CORS-Handling

## Konfiguration

### Wichtige Umgebungsvariablen

| Variable | Beschreibung |
|----------|--------------|
| `POSTGRES_PASSWORD` | PostgreSQL Passwort |
| `JWT_SECRET` | Secret fuer JWT-Token (min. 32 Zeichen) |
| `ANON_KEY` | API Key fuer anonyme Anfragen |
| `SERVICE_ROLE_KEY` | API Key fuer Admin-Anfragen |
| `SITE_URL` | URL der Frontend-Anwendung |
| `API_EXTERNAL_URL` | Externe URL der API |

### SMTP konfigurieren (Email-Versand)

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your-username
SMTP_PASS=your-password
SMTP_ADMIN_EMAIL=admin@example.com
```

### SSL/HTTPS aktivieren

Fuer Produktion sollte ein Reverse Proxy (nginx, Traefik) mit SSL verwendet werden.

## Edge Functions

### Neue Function erstellen

```bash
mkdir volumes/functions/meine-funktion
```

Erstelle `volumes/functions/meine-funktion/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  return new Response(
    JSON.stringify({ message: "Hallo von meiner Funktion!" }),
    { headers: { "Content-Type": "application/json" } }
  );
});
```

Die Function ist unter `http://localhost:8000/functions/v1/meine-funktion` erreichbar.

## Befehle

```bash
# Starten
docker compose up -d

# Stoppen
docker compose down

# Logs anzeigen
docker compose logs -f

# Logs eines Services
docker compose logs -f db

# Neustart eines Services
docker compose restart auth

# Alle Daten loeschen (Vorsicht!)
docker compose down -v
rm -rf volumes/db/data volumes/storage/*
```

## Datenbank-Zugriff

### Via psql

```bash
docker compose exec db psql -U postgres
```

### Via externem Client

- Host: `localhost`
- Port: `5432`
- User: `postgres`
- Password: Wert von `POSTGRES_PASSWORD`
- Database: `postgres`

## Backup

### Datenbank-Backup

```bash
docker compose exec db pg_dump -U postgres > backup.sql
```

### Datenbank wiederherstellen

```bash
cat backup.sql | docker compose exec -T db psql -U postgres
```

### Vollstaendiges Backup

```bash
# Datenbank
docker compose exec db pg_dump -U postgres > backup.sql

# Storage-Dateien
tar -czvf storage-backup.tar.gz volumes/storage/
```

## Fehlerbehebung

### Services starten nicht

```bash
# Logs pruefen
docker compose logs

# Einzelnen Service debuggen
docker compose logs db
docker compose logs auth
```

### Datenbank-Verbindungsfehler

1. Pruefen ob DB laeuft: `docker compose ps db`
2. DB-Logs pruefen: `docker compose logs db`
3. Healthcheck: `docker compose exec db pg_isready`

### Auth-Service Fehler

1. JWT_SECRET in .env pruefen (min. 32 Zeichen)
2. ANON_KEY und SERVICE_ROLE_KEY pruefen
3. Auth-Logs: `docker compose logs auth`

### Kong/API Gateway Fehler

1. Kong-Konfiguration pruefen: `volumes/kong/kong.yml`
2. Kong-Logs: `docker compose logs kong`

## Upgrade

```bash
# Backup erstellen
docker compose exec db pg_dump -U postgres > backup-$(date +%Y%m%d).sql

# Images aktualisieren
docker compose pull

# Neustart
docker compose up -d
```

## Ressourcen

- [Supabase Dokumentation](https://supabase.com/docs)
- [Self-Hosting Guide](https://supabase.com/docs/guides/self-hosting)
- [GitHub Repository](https://github.com/supabase/supabase)

## Lizenz

Dieses Setup basiert auf der offiziellen Supabase-Konfiguration.
Supabase ist unter der Apache 2.0 Lizenz veroeffentlicht.
