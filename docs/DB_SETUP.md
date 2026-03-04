# Crear la base de datos — Rifard

Tienes dos formas de crear el schema:

## Opción 1: Supabase (recomendado)

**Si ya tienes tablas y quieres empezar de cero:**

1. Entra en tu proyecto en [Supabase](https://supabase.com/dashboard).
2. Ve a **SQL Editor**.
3. Ejecuta primero **`supabase_migrations/0000_drop_all.sql`** (borra tablas, enums y función del schema Rifard).
4. Luego ejecuta **`supabase_migrations/0001_core.sql`** (crea todo de nuevo).

**Si la base está vacía o es la primera vez:**

1. En **SQL Editor** ejecuta solo **`supabase_migrations/0001_core.sql`**.

Listo: tendrás todas las tablas, enums, índices y triggers. Luego configura en el backend la `DATABASE_URL` de Supabase (Connection string, modo “Transaction” o “Session”).

## Opción 2: Postgres local con Docker

1. Inicia Docker Desktop (o que el daemon de Docker esté corriendo).
2. En la raíz del repo:

   ```bash
   docker compose up -d postgres
   ```

3. Cuando el contenedor esté arriba, aplica la migración:

   ```bash
   # Windows (PowerShell)
   Get-Content supabase_migrations/0001_core.sql -Raw | docker compose exec -T postgres psql -U rifard -d rifard

   # Linux/macOS
   docker compose exec -T postgres psql -U rifard -d rifard < supabase_migrations/0001_core.sql
   ```

4. En el backend, usa en `.env`:

   ```
   DATABASE_URL="postgresql://rifard:rifard@localhost:5432/rifard"
   ```

## Después de crear el schema

1. En `apps/backend`: `npx prisma generate`.
2. (Opcional) Seed de roles: `npx prisma db seed`.
3. Arranca el backend: `npm run start:dev`.
