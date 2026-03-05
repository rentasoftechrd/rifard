# Desplegar Rifard en Hostinger

Guía para subir el **backend (NestJS)** y el **backoffice (Flutter Web)** a Hostinger. La base de datos sigue en Supabase (no se migra a Hostinger).

---

## Usar el MCP de Hostinger para el VPS

Si tienes un **VPS en Hostinger** y el MCP **hostinger-mcp** conectado en Cursor:

1. **Listar VPS:** pide al agente que ejecute `VPS_getVirtualMachinesV1` para ver tus máquinas e IDs.
2. **Detalle de una VPS:** con el `virtualMachineId` usa `VPS_getVirtualMachineDetailsV1` para obtener IP, estado, usuario root y si está en estado `initial` (sin configurar).
3. **Configurar VPS recién comprada:** si el estado es `initial`:
   - Ejecuta `VPS_getTemplatesV1` y `VPS_getDataCenterListV1` para elegir OS (ej. Ubuntu) y datacenter.
   - Llama a `VPS_setupPurchasedVirtualMachineV1` con `virtualMachineId`, `template_id`, `data_center_id`, y opcionalmente `password`, `hostname`, `enable_backups`.
4. **Obtener IP y acceso:** tras el setup, vuelve a `VPS_getVirtualMachineDetailsV1` para la IP. Conecta por SSH (usuario `root` y la contraseña que configuraste).
5. **Desplegar el backend:** en tu PC ejecuta el script de deploy (ver sección VPS más abajo) pasando la IP del VPS, o sigue los pasos manuales por SSH.

Si el MCP no aparece en Cursor, reinicia Cursor y revisa que en **Cursor Settings → MCP** (o `mcp.json`) el servidor `hostinger-mcp` esté configurado con tu `API_TOKEN`.

---

## Requisitos en Hostinger

- Plan **Business** o **Cloud** (con soporte Node.js). Los planes Single no incluyen Node.js.
- Dominio o subdominio para la API y otro para el backoffice (o mismo dominio con rutas distintas).

Ejemplo de dominios:
- **API:** `https://api.tudominio.com` o `https://tudominio.com/api`
- **Backoffice:** `https://backoffice.tudominio.com` o `https://tudominio.com`

---

## 1. Backend (NestJS) en Hostinger

### 1.1 Build en tu PC

```bash
cd apps/backend
npm ci
npx prisma generate
npm run build
```

Se genera la carpeta `dist/` y Prisma queda listo para producción.

### 1.2 Subir el backend

**Opción A – Con GitHub (recomendado en Hostinger)**

1. Sube el proyecto a un repositorio (solo lo necesario para el backend o monorepo).
2. En hPanel → **Websites** → **Add Website** (o tu sitio) → **Node.js Apps** → **Import Git Repository**.
3. Conecta GitHub y elige el repo. En “Application root” apunta a la carpeta del backend, por ejemplo: `apps/backend`.
4. En **Build settings**:
   - Build command: `npm ci && npx prisma generate && npm run build`
   - Run command: `npm run start:prod`
   - Node version: 18 o 20.
5. En **Environment variables** (hPanel) añade todas las variables de producción (ver 1.4).
6. Deploy.

**Opción B – Subir por ZIP/FTP**

1. En tu PC, desde la raíz del monorepo:
   - Crea un ZIP con: `apps/backend/package.json`, `apps/backend/package-lock.json`, `apps/backend/dist/` (entera), `apps/backend/prisma/` (schema.prisma y lo que uses). **No** incluyas `node_modules`.
2. En Hostinger: **File Manager** o FTP. En la carpeta que te indiquen para Node.js (por ejemplo `domains/tudominio.com/nodejs`), sube el ZIP y descomprímelo.
3. Por SSH (si tu plan lo permite):
   ```bash
   cd ~/domains/tudominio.com/nodejs   # o la ruta que te den
   npm ci --production
   npx prisma generate
   ```
4. Configura el **Start command** en hPanel: `node dist/main` o `npm run start:prod`.

### 1.3 Puerto y dominio

- Hostinger suele asignar un puerto interno para Node.js y exponer la app por el dominio (proxy).
- Deja que Hostinger gestione el puerto; no hace falta poner `PORT` en `.env` salvo que la documentación lo pida.
- Si usas subdominio para la API (ej. `api.tudominio.com`), en el panel apunta ese dominio a la aplicación Node.js.

### 1.4 Variables de entorno (producción)

En hPanel → tu sitio → **Node.js** → **Environment variables** (o equivalente), configura:

```env
NODE_ENV=production
DATABASE_URL="postgresql://postgres.[PROJECT]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true"
JWT_SECRET="[cadena-larga-segura-min-32-caracteres]"
JWT_EXPIRES_IN=15m
REFRESH_SECRET="[otra-cadena-segura]"
REFRESH_EXPIRES_IN=7d
BANCO_TIMEZONE=America/Santo_Domingo
POS_HEARTBEAT_ONLINE_SECONDS=60
CORS_ORIGINS=https://backoffice.tudominio.com,https://tudominio.com
```

- Sustituye `backoffice.tudominio.com` y `tudominio.com` por la URL real del backoffice.
- Si el backoffice está en otra ruta (ej. `https://tudominio.com/backoffice`), usa `https://tudominio.com`.

### 1.5 Despliegue en VPS (Hostinger) y dejar el backend corriendo

Si usas un **VPS** (no Node.js Apps en shared/cloud):

**En el VPS (primera vez, por SSH):**

```bash
# Conectar: ssh root@IP_DEL_VPS
apt update && apt install -y nodejs npm
npm install -g pm2
mkdir -p /opt/rifard-backend
```

**Desde tu PC – script automático (Windows PowerShell):**

Desde la raíz del repo (o desde `scripts/`):

```powershell
.\scripts\deploy-backend-vps.ps1 -VpsIp "IP_DE_TU_VPS" -SshUser "root"
```

Te pedirá la contraseña SSH. Si usas clave: `-SshKey "C:\ruta\a\id_rsa"`.

El script hace: build local → sube `dist/`, `prisma/`, `package.json` → en el VPS ejecuta `npm ci --production`, `prisma generate`, y arranca con **pm2** (`pm2 start dist/main.js --name rifard-backend`).

**Variables de entorno en el VPS:** crea `/opt/rifard-backend/.env` en el servidor con `DATABASE_URL`, `JWT_SECRET`, etc. (mismo contenido que en 1.4). Puedes subir el `.env` a mano o con `scp`.

**Nginx (opcional):** para exponer el backend en el puerto 80/443 con tu dominio:

```nginx
# /etc/nginx/sites-available/rifard-api
server {
    listen 80;
    server_name api.tudominio.com;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Habilita el sitio y recarga Nginx. Así el backend queda corriendo en el VPS y accesible por `https://api.tudominio.com` (añade SSL con certbot si quieres).

#### Actualizar el backend en Hostinger

Cuando hay cambios en el código (por ejemplo módulo Personas, migración 0006):

1. **Aplicar la migración en la base de datos** (solo la primera vez que subes la migración 0006). La BD suele estar en **Supabase** (la que usa `DATABASE_URL` del `.env`):
   - Entra en [Supabase](https://supabase.com) → tu proyecto → **SQL Editor**.
   - Copia y pega el contenido de `supabase_migrations/0006_personas.sql` y ejecuta.
   - Si la BD está en otro Postgres, ejecuta ese mismo SQL con `psql` o el cliente que uses.

2. **Desplegar desde tu PC** (PowerShell, desde la raíz del repo):
   ```powershell
   .\scripts\deploy-backend-vps.ps1 -VpsIp "187.124.81.201" -SshUser "root"
   ```
   Si usas clave SSH: `-SshKey "$env:USERPROFILE\.ssh\id_ed25519"`.

   El script hace: build en tu PC → sube `dist/`, `prisma/`, `package.json`, `package-lock.json` al VPS → en el VPS ejecuta `npm ci --production`, `npx prisma generate`, reinicia pm2.

3. **Comprobar** en el VPS:
   ```bash
   ssh root@187.124.81.201 "pm2 status && pm2 logs rifard-backend --lines 20"
   ```

#### Dejar el backend corriendo para pruebas con el POS

**Root access (Hostinger):**
```bash
ssh root@187.124.81.201
```
Usa la contraseña de root que tienes en el panel del VPS (o restablece la contraseña desde hPanel si no la recuerdas).

1. **Build en tu PC** (ya hecho si ejecutaste el script):
   ```bash
   cd apps/backend && npm ci && npx prisma generate && npm run build
   ```

2. **En el VPS (primera vez):** crea el `.env` en la carpeta del backend (por defecto `~/rifard-backend`, es decir `/root/rifard-backend` si entras como root). Mismas variables que en 1.4. Para pruebas con el POS, en `CORS_ORIGINS` pon la IP del VPS o déjalo vacío:
   ```env
   CORS_ORIGINS=http://187.124.81.201:3000
   ```
   o deja `CORS_ORIGINS=` vacío para permitir cualquier origen en pruebas.

3. **Abre el puerto 3000** en el firewall del VPS (si usas ufw):
   ```bash
   ufw allow 3000/tcp && ufw reload
   ```

4. **Despliega desde tu PC** (PowerShell, desde la raíz del repo):
   ```powershell
   .\scripts\deploy-backend-vps.ps1 -VpsIp "187.124.81.201" -SshUser "root"
   ```
   Te pedirá la contraseña SSH (o usa `-SshKey "C:\ruta\a\id_rsa"`). El backend se instala en `~/rifard-backend` en el VPS (para evitar "permission denied" en `/opt`).

   **Si sigue "Permission denied" después de cambiar la contraseña:** suele ser que el VPS tiene desactivada la autenticación por contraseña. Haz lo siguiente **desde la consola web de Hostinger** (VPS → Open Web Terminal), así no dependes de SSH desde tu PC:

   1. Entra al VPS por la **Web Terminal** de Hostinger (Overview del VPS → botón de terminal en el navegador).
   2. Comprueba que la contraseña nueva funciona: cierra sesión y vuelve a entrar en la web terminal con la nueva clave.
   3. Activa la autenticación por contraseña de SSH en el servidor:
      ```bash
      sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      grep -q '^PasswordAuthentication ' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
      systemctl reload ssh
      ```
   4. Vuelve a intentar desde tu PC: `ssh root@187.124.81.201` y luego el script de deploy.

   **Alternativa sin contraseña (recomendada):** usar clave SSH. En la Web Terminal del VPS crea `~/.ssh/authorized_keys` y pega tu clave pública. En tu PC tienes la clave en `%USERPROFILE%\.ssh\id_ed25519.pub` (o `id_rsa.pub`). En la Web Terminal:
      ```bash
      mkdir -p ~/.ssh
      echo "PEGA_AQUI_TU_CLAVE_PUBLICA" >> ~/.ssh/authorized_keys
      chmod 700 ~/.ssh
      chmod 600 ~/.ssh/authorized_keys
      ```
   Luego en tu PC ejecuta el script con `-SshKey "$env:USERPROFILE\.ssh\id_ed25519"`.

5. **En el POS:** en la pantalla de login/configuración, pon como URL del backend:
   ```text
   http://187.124.81.201:3000
   ```
   (sin barra final; el app ya añade `/api/v1`). Comprueba con `GET http://187.124.81.201:3000/api/v1/health/pos-connect`.

6. **Comprobar que sigue corriendo:** `ssh root@187.124.81.201 'pm2 status'` y `pm2 logs rifard-backend`.

#### Desplegar desde el VPS (todo en el servidor)

Haz **todo desde el VPS** usando la **Web Terminal** de Hostinger (no hace falta SSH desde tu PC). Orden recomendado:

**1. Entrar a la Web Terminal**  
En el panel de Hostinger → tu VPS → abrir la terminal en el navegador. Inicias sesión como root con tu contraseña.

**2. Instalar Node.js 20, npm, pm2 y git**
```bash
apt update && apt install -y git
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g pm2
```

**3. Clonar el repo**  
Con token de GitHub (cuando pida password, pega el token):
```bash
cd /root
git clone https://github.com/rentasoftechrd/rifard.git
cd rifard/apps/backend
```
Usuario: `rentasoftechrd`, contraseña: tu **Personal Access Token** de GitHub.

**4. Crear el `.env`**
```bash
nano .env
```
Pega las variables (DATABASE_URL, JWT_SECRET, REFRESH_SECRET, CORS_ORIGINS, etc., como en 1.4). Para pruebas POS puedes dejar `CORS_ORIGINS=` vacío. Guarda: Ctrl+O, Enter, Ctrl+X.

**5. Instalar, generar Prisma y compilar**
```bash
npm ci
npx prisma generate
npm run build
```

**6. Arrancar con pm2**
```bash
pm2 delete rifard-backend 2>/dev/null; true
pm2 start dist/main.js --name rifard-backend
pm2 save
pm2 status
```

**7. Abrir el puerto 3000 (si usas firewall)**
```bash
ufw allow 3000/tcp && ufw reload
```

**Comprobar:** en el navegador o desde el POS: `http://187.124.81.201:3000/api/v1/health/pos-connect`

**Para actualizar después:** `cd /root/rifard/apps/backend`, `git pull`, luego repetir pasos 5 y 6.

---

### 1.6 Migraciones Prisma

Si usas migraciones en Supabase, ejecuta en tu PC (o en un job de deploy) antes de desplegar:

```bash
cd apps/backend
npx prisma migrate deploy
```

En Hostinger con GitHub, puedes añadir en el build command:

`npm ci && npx prisma generate && npx prisma migrate deploy && npm run build`

(si tienes `DATABASE_URL` disponible en el entorno de build).

---

## 2. Backoffice (Flutter Web) en Hostinger

### 2.1 Build con la URL de la API

En tu PC, desde la raíz del monorepo:

```bash
cd apps/backoffice
flutter pub get
flutter build web --dart-define=API_URL=https://api.tudominio.com
```

Sustituye `https://api.tudominio.com` por la URL real de tu API en Hostinger (con `https://` y sin barra final). El build en release (por defecto) aplica minimización y carga diferida de pantallas; más detalles en [BACKOFFICE_PERFORMANCE.md](BACKOFFICE_PERFORMANCE.md).

### 2.2 Subir los archivos

La build genera la carpeta `build/web/` con algo como:

- `index.html`
- `main.dart.js`
- `flutter.js`
- `assets/`
- etc.

1. En Hostinger, entra a **File Manager** (o FTP) al directorio del dominio del backoffice (por ejemplo `public_html` o `public_html/backoffice`).
2. Sube **todo el contenido** de `apps/backoffice/build/web/` (no la carpeta `web` en sí, sino su contenido) a esa ruta.
3. Asegúrate de que `index.html` esté en la raíz de ese sitio (o en la subcarpeta que uses para el backoffice).

Si usas **subdominio** `backoffice.tudominio.com`, en Hostinger asigna ese subdominio a la carpeta donde subiste los archivos.

### 2.3 Rutas (SPA)

Flutter Web es una SPA; todas las rutas deben devolver `index.html`. El proyecto ya incluye un **`web/.htaccess`** que se copia a `build/web/` al hacer `flutter build web`. Si subes todo el contenido de `build/web/`, el `.htaccess` irá incluido y Hostinger (Apache) redirigirá las rutas al `index.html`.

Si el backoffice queda en una subcarpeta (ej. `https://tudominio.com/backoffice`), edita el `.htaccess` y cambia `RewriteBase /` por `RewriteBase /backoffice/`.

---

## 3. POS (celular) después del deploy

En la app POS, en “URL del servidor” el usuario debe poner la URL **pública** de la API, por ejemplo:

- `https://api.tudominio.com`

No usar `localhost` ni IP local en producción.

---

## 4. Resumen de URLs

| Componente   | URL ejemplo (producción)     |
|-------------|------------------------------|
| API         | `https://api.tudominio.com`  |
| Backoffice  | `https://backoffice.tudominio.com` o `https://tudominio.com` |
| POS (campo) | Misma URL que la API         |
| Supabase DB | Ya configurada en `DATABASE_URL` |

---

## 5. Comandos rápidos (en tu PC)

```bash
# Backend – build
cd apps/backend && npm ci && npx prisma generate && npm run build

# Backoffice – build para producción (cambia la URL)
cd apps/backoffice && flutter build web --dart-define=API_URL=https://api.tudominio.com
```

Después solo queda subir `dist/` + `package.json` + `prisma` (y opcionalmente instalar `node_modules` en el servidor) para el backend, y el contenido de `build/web/` para el backoffice.
