# Rifard — Sistema Loteria Dominicana

Backoffice Web (Flutter Web) + POS Android (Flutter) + Backend (NestJS + Prisma) + Supabase Postgres.

## Estructura (monorepo)

- `apps/backend` — API NestJS, Prisma, JWT, RBAC, módulos: auth, users, lotteries, draws, results, limits, tickets, pos, reports, audit, health.
- `apps/backoffice` — Flutter Web, tema dark, go_router, Riverpod, pantallas: Dashboard, Loterías, Sorteos, Resultados, Límites, POS Conectados, Usuarios, Vendedores, Reportes, Auditoría.
- `apps/pos` — Flutter Android (y Web), POS: login, punto, impresora, venta, anulación, cierre.
- `supabase_migrations/` — SQL de schema (aplicar vía Supabase MCP o manual).
- `docs/DEV_LOG.md` — Log de desarrollo.

## Requisitos

- Node 20+, npm
- Flutter 3.24+
- PostgreSQL 14+ (o Supabase)
- Cuenta Supabase (opcional, para aplicar migraciones)

## Desarrollo

### Backend

```bash
cd apps/backend
cp .env.example .env   # editar DATABASE_URL, JWT_SECRET, etc.
npm install
npx prisma generate
npm run start:dev
```

API: `http://localhost:3000/api/v1`. Swagger: `http://localhost:3000/api/docs`.

### Base de datos

Ver ** [docs/DB_SETUP.md](docs/DB_SETUP.md) ** para crear el schema.

- **Supabase:** SQL Editor → pegar contenido de `supabase_migrations/0001_core.sql` → Run.
- **Local (Docker):** `docker compose up -d postgres` y luego ejecutar el mismo SQL con `psql` (instrucciones en DB_SETUP.md).

Después: `npx prisma generate` y opcionalmente `npx prisma db seed` en `apps/backend`.

### Backoffice Web

```bash
cd apps/backoffice
flutter pub get
flutter run -d chrome
```

### POS

```bash
cd apps/pos
flutter pub get
flutter run -d android
```

Configurar URL del API en el cliente (por defecto localhost; en dispositivo usar IP de la máquina o URL de backend).

### Docker

```bash
docker compose up -d
# Backend en :3000, Postgres en :5432
```

## Variables de entorno (backend)

Ver `apps/backend/.env.example`: `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `REFRESH_SECRET`, `REFRESH_EXPIRES_IN`, `BANCO_TIMEZONE`, `POS_HEARTBEAT_ONLINE_SECONDS`, `CORS_ORIGINS`.

## CI

GitHub Actions: lint/build backend, build Flutter backoffice web y POS Android (ver `.github/workflows/ci.yml`).
