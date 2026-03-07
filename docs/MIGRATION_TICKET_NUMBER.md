# Migración: ticket_number y ticket_daily_sequence

## Opción 1: Supabase SQL Editor (recomendado con connection pooling)

Si el backend usa la URL con pooler (puerto 6543), aplica la migración desde **Supabase Dashboard → SQL Editor**:

1. Abre el proyecto en [Supabase](https://supabase.com/dashboard).
2. Ve a **SQL Editor** y pega el contenido de:
   `apps/backend/prisma/migrations/20260227000000_add_ticket_number_and_daily_sequence/migration.sql`
3. Ejecuta el script.

## Opción 2: Prisma migrate deploy (conexión directa)

Si tienes una URL **directa** a Postgres (sin PgBouncer, puerto 5432), puedes usar:

```bash
cd apps/backend
# Usar DATABASE_URL directa (sin ?pgbouncer=true)
npx prisma migrate deploy
```

Para generar la URL directa en Supabase: **Project Settings → Database → Connection string** (URI con puerto **5432**, no 6543).

## Después de migrar

1. Añade en `.env` (o deja los valores por defecto):
   - `TICKET_QR_BASE_URL=https://tudominio.com`
   - `VOID_WINDOW_MINUTES=5`
2. Reinicia el backend.
3. Los **nuevos** tickets tendrán `ticket_number` (formato `YYYYMMDD00001`). Los tickets antiguos siguen con `ticket_code` y `ticket_number` en NULL; la búsqueda por código sigue funcionando.

## Probar validación pública (QR)

Sin autenticación:

```bash
curl "http://localhost:3000/api/v1/t/20260227000001"
```

Respuesta esperada si existe: `{"valid":true,"ticketNumber":"20260227000001","status":"sold","totalAmount":"150",...}`  
Si no existe: `{"valid":false,"message":"Ticket no encontrado"}`.
