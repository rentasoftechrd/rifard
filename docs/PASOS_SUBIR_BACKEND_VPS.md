# Paso a paso: subir el backend al VPS (Hostinger)

Sigue estos pasos en orden. Si ya hiciste alguno antes (por ejemplo la migración o el .env), puedes saltarlo.

---

## Paso 1: Aplicar la migración en la base de datos (solo la primera vez)

La tabla `personas` y la relación con `users` deben existir en Supabase antes de usar el backend nuevo.

1. Entra en [Supabase](https://supabase.com) → tu proyecto → **SQL Editor**.
2. Abre el archivo `supabase_migrations/0006_personas.sql` de este repo.
3. Copia todo el contenido y pégalo en el editor SQL.
4. Ejecuta el script (Run).
5. Si ya lo ejecutaste antes, puede dar error de “ya existe”; en ese caso está bien, sigue al paso 2.

---

## Paso 2: Tener el `.env` en el VPS (solo la primera vez)

Si aún no tienes el backend corriendo en el VPS, crea el archivo de variables de entorno en el servidor.

1. Conéctate al VPS por SSH:
   ```bash
   ssh root@187.124.81.201
   ```
   (Sustituye la IP por la de tu VPS si es distinta. Usa la contraseña de root o clave SSH.)

2. Crea la carpeta del backend (si no existe) y el archivo `.env`:
   ```bash
   mkdir -p ~/rifard-backend
   nano ~/rifard-backend/.env
   ```

3. Pega algo como esto (ajusta los valores a tu proyecto):
   ```env
   NODE_ENV=production
   DATABASE_URL="postgresql://postgres.[PROJECT]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true"
   JWT_SECRET="una-cadena-muy-larga-y-segura-de-al-menos-32-caracteres"
   JWT_EXPIRES_IN=15m
   REFRESH_SECRET="otra-cadena-segura-diferente"
   REFRESH_EXPIRES_IN=7d
   CORS_ORIGINS=http://localhost:xxxxx,http://187.124.81.201:3000
   ```
   En `CORS_ORIGINS` pon las URLs desde las que abres el backoffice (localhost cuando pruebas en tu PC, y la IP/dominio del backoffice en producción).

4. Guarda: `Ctrl+O`, Enter, `Ctrl+X`.

5. Sal del VPS: `exit`.

---

## Paso 3: Desde tu PC – build y subir con el script

Abre **PowerShell** en la raíz del proyecto (donde está la carpeta `apps` y `scripts`).

1. Ve a la raíz del repo:
   ```powershell
   cd c:\dev\rifard
   ```

2. Ejecuta el script de deploy (sustituye la IP si tu VPS es otra):
   ```powershell
   .\scripts\deploy-backend-vps.ps1 -VpsIp "187.124.81.201" -SshUser "root"
   ```

3. Si te pide contraseña, usa la de root del VPS.

   Si usas **clave SSH** en lugar de contraseña:
   ```powershell
   .\scripts\deploy-backend-vps.ps1 -VpsIp "187.124.81.201" -SshUser "root" -SshKey "$env:USERPROFILE\.ssh\id_ed25519"
   ```

4. El script hace automáticamente:
   - `npm ci` y `npm run build` en `apps/backend` en tu PC
   - Sube `dist/`, `prisma/`, `package.json` y `package-lock.json` al VPS
   - En el VPS: `npm ci --production`, `npx prisma generate`, reinicia **pm2** con el nombre `rifard-backend`

Cuando termine, el backend ya está actualizado y corriendo en el VPS.

---

## Paso 4: Comprobar que está corriendo

En PowerShell:

```powershell
ssh root@187.124.81.201 "pm2 status"
```

Deberías ver `rifard-backend` en estado **online**.

Ver últimas líneas del log:

```powershell
ssh root@187.124.81.201 "pm2 logs rifard-backend --lines 20"
```

Probar la API desde el navegador o con curl:

- `http://187.124.81.201:3000/api/v1/health/pos-connect`

(Sustituye la IP si es otra.)

---

## Paso 5: Abrir el puerto 3000 (solo si no responde la API)

Si desde fuera no puedes acceder a `http://IP:3000`, abre el puerto en el firewall del VPS:

```bash
ssh root@187.124.81.201
ufw allow 3000/tcp
ufw reload
exit
```

---

## Resumen rápido (cuando ya todo está configurado)

Cada vez que cambies código del backend y quieras subirlo al VPS:

1. **Opcional:** Si añadiste una migración SQL nueva, ejecútala en Supabase (paso 1).
2. En tu PC, en la raíz del repo:
   ```powershell
   .\scripts\deploy-backend-vps.ps1 -VpsIp "187.124.81.201" -SshUser "root"
   ```
3. Comprobar: `ssh root@187.124.81.201 "pm2 status"`

---

## Problemas frecuentes

| Problema | Qué hacer |
|----------|-----------|
| **Permission denied** al hacer SSH | Usa la contraseña correcta de root o configura clave SSH y usa `-SshKey`. En Hostinger puedes restablecer la contraseña desde el panel del VPS. |
| **Cannot POST /api/v1/personas** (404) | El backend en el VPS no tiene la ruta: asegúrate de haber desplegado con el script **después** de tener el módulo Personas en el código y la migración 0006 aplicada en Supabase. |
| **pm2 no encontrado** | En el VPS: `npm install -g pm2`. Si Node no está instalado: `apt update && apt install -y nodejs npm` (o instala Node 20 como en `docs/DEPLOY_HOSTINGER.md`). |
| **Backend se cae al rato** | En el VPS: `pm2 save` y `pm2 startup` para que pm2 se reinicie al reiniciar el servidor. |

Si algo falla, revisa también la guía completa en `docs/DEPLOY_HOSTINGER.md`.
