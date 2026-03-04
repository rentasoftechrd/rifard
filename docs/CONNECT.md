# Conectar backend a Supabase y frontend al backend

## 1. Obtener la URL de conexión de Supabase

1. Entra en [Supabase Dashboard](https://supabase.com/dashboard) y abre tu proyecto.
2. Ve a **Project Settings** (icono de engranaje) → **Database**.
3. En **Connection string** elige la pestaña **URI**.
4. Copia la URL. Si usas **Connection pooling** (puerto 6543), mejor para Prisma.
5. Sustituye `[YOUR-PASSWORD]` por la contraseña de la base de datos (la que definiste al crear el proyecto, o restablece en **Database** → **Reset database password** si no la recuerdas).

Ejemplo (con pooler). **Importante:** si usas el pooler (puerto 6543), añade `?pgbouncer=true` al final para evitar el error "prepared statement already exists" al hacer seed:
```
postgresql://postgres.xxxxx:TU_PASSWORD@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true
```

## 2. Conectar el backend

1. En la carpeta del backend crea el archivo `.env` a partir del ejemplo:
   ```bash
   cd apps/backend
   copy .env.example .env
   ```
   (En PowerShell: `Copy-Item .env.example .env`)

2. Abre `apps/backend/.env` y pega tu `DATABASE_URL` de Supabase (la URL completa entre comillas):
   ```
   DATABASE_URL="postgresql://postgres.xxxxx:TU_PASSWORD@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
   ```

3. Genera el cliente de Prisma y (opcional) inserta los roles:
   ```bash
   cd apps/backend
   npx prisma generate
   npx prisma db seed
   ```

4. Arranca el backend:
   ```bash
   npm run start:dev
   ```
   Deberías ver: `Application is running on: http://localhost:3000/api/v1`

5. Comprueba la API: abre en el navegador `http://localhost:3000/api/v1/health` y `http://localhost:3000/api/docs` (Swagger).

## 3. Usuario admin por defecto

El seed crea los **roles** y un usuario administrador para poder hacer login de inmediato:

- **Email:** `admin@rifard.com`
- **Contraseña:** `Admin123!`

Si ya existía un usuario con ese email, el seed no lo sobrescribe. Para crear más usuarios usa el backoffice (Usuarios) o la API con un token de admin.

## 4. Conectar el frontend (Backoffice Web)

1. El backoffice usa por defecto `http://localhost:3000` como URL del API. Con el backend en marcha en el puerto 3000 no hace falta cambiar nada.

2. Arranca el backoffice:
   ```bash
   cd apps/backoffice
   flutter pub get
   flutter run -d chrome
   ```

3. En la pantalla de login usa: **admin@rifard.com** / **Admin123!**

4. Si el backend corre en otra máquina o puerto, indica la URL al compilar:
   ```bash
   flutter run -d chrome --dart-define=API_URL=http://IP:3000
   ```

## 5. POS (Android / Web)

El POS también usa por defecto `http://localhost:3000`. En un dispositivo Android, usa la IP de tu PC en la red local (ej. `http://192.168.1.10:3000`). Puedes guardar la URL en la app (el POS ya tiene `setBaseUrl` si implementaste pantalla de configuración).

## 6. Fecha y hora del servidor (anti-fraude)

Todas las validaciones de fecha y hora se hacen **en el servidor**, no en los dispositivos:

- **Cierre de sorteos, anulaciones (5 min), ingreso de resultados:** usan la hora del servidor.
- **Reportes y dashboard:** si el cliente envía una fecha futura, el servidor la rechaza.
- **Zona horaria:** configurable con `BANCO_TIMEZONE` en `.env` (por defecto `America/Santo_Domingo`).

El endpoint `GET /api/v1/health` devuelve `serverTime` e `timezone` para que las apps muestren la hora de referencia del banco.

---

**Resumen:**  
`.env` en `apps/backend` con `DATABASE_URL` de Supabase → `npx prisma generate` → `npx prisma db seed` → `npm run start:dev` → `flutter run -d chrome` en backoffice → login con **admin@rifard.com** / **Admin123!**
