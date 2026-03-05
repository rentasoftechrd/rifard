# Probar y depurar en local (más fácil)

Para depurar el POS, el backoffice y el backend desde tu PC (breakpoints, `debugPrint`, misma base de datos).

## 1. Backend en local

En una terminal, desde la raíz del repo:

```powershell
cd c:\dev\rifard\apps\backend
npm run start:dev
```

- El backend queda en **http://localhost:3000**.
- Usa la base de datos configurada en tu `.env` (por ejemplo Supabase o Postgres local).

## 2. POS apuntando al backend local

### Opción A: URL en tiempo de ejecución (sin recompilar)

1. Ejecuta el POS:
   ```powershell
   cd c:\dev\rifard\apps\pos
   flutter run -d chrome
   ```
   (O `flutter run -d <id>` para ver dispositivos/emuladores.)

2. En la pantalla de **login** del POS, en “URL del servidor” pon:
   - **Web (Chrome):** `http://localhost:3000`
   - **Emulador Android:** `http://10.0.2.2:3000`
   - **Dispositivo físico en la misma red:** `http://<IP_DE_TU_PC>:3000`

3. Inicia sesión con un usuario que tenga **punto asignado** (Personas → Puntos en el backoffice).

### Opción B: URL fija en debug con `--dart-define` (recomendado para depurar)

Así no dependes de escribir la URL en el login cada vez:

```powershell
cd c:\dev\rifard\apps\pos
# Web
flutter run -d chrome --dart-define=API_URL=http://localhost:3000

# Emulador Android
flutter run -d android --dart-define=API_URL=http://10.0.2.2:3000
```

Con `API_URL` definido, el POS usa esa URL y tiene prioridad sobre la guardada en el login. Ideal para depurar desde aquí.

## 3. Backoffice en local (opcional)

Para que el backoffice también use el backend local:

```powershell
cd c:\dev\rifard\apps\backoffice
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

Así backoffice y POS usan el mismo backend en tu máquina.

## 4. Depuración en el IDE

- **Breakpoints:** ponlos en `apps/pos/lib` (por ejemplo en `sell_screen.dart`, `api_client.dart`) y depura con “Run → Start Debugging” (F5) o “Debug” en la barra de Flutter.
- **Consola:** los `debugPrint(...)` del POS salen en la terminal donde lanzaste `flutter run` y en la pestaña “Debug Console” de VS Code/Cursor.
- **Backend:** si usas `npm run start:debug`, puedes adjuntar el depurador de Node (puerto 9229) para poner breakpoints en el backend.

## 5. Resumen rápido (todo en local)

| Terminal   | Comando |
|-----------|---------|
| 1 – Backend | `cd apps\backend` → `npm run start:dev` |
| 2 – POS     | `cd apps\pos` → `flutter run -d chrome --dart-define=API_URL=http://localhost:3000` |
| 3 – Backoffice (opcional) | `cd apps\backoffice` → `flutter run -d chrome --dart-define=API_URL=http://localhost:3000` |

Asegúrate de que el usuario con el que entras en el POS tenga el punto asignado en el backoffice (Personas → Puntos) y que la base de datos del backend local tenga loterías y sorteos si quieres probar la pantalla de venta completa.

---

## 6. Debug por cable (teléfono Android por USB)

Así ves en el PC todos los `debugPrint`, errores y el diagnóstico mientras usas el POS en el teléfono.

### 6.1 Activar depuración USB en el teléfono

1. **Opciones de desarrollador**
   - Android: **Ajustes → Acerca del teléfono** y toca **Número de compilación** 7 veces hasta que diga "Ahora eres desarrollador".
   - Luego **Ajustes → Sistema → Opciones de desarrollador** (o **Ajustes → Opciones de desarrollador**).

2. Activa **Depuración USB**.
3. Conecta el teléfono al PC con el cable USB.
4. En el teléfono, cuando pregunte "¿Permitir depuración USB?", acepta y opcionalmente marca "Permitir siempre desde este equipo".

### 6.2 Ver que Flutter ve el dispositivo

En PowerShell:

```powershell
cd c:\dev\rifard\apps\pos
flutter devices
```

Debe aparecer tu Android (por ejemplo "samsung SM-Gxxx" o "Android SDK built for arm64"). Anota el **id** si tienes varios dispositivos.

### 6.3 Backend accesible desde el teléfono

El teléfono no puede usar `localhost` del PC. Usa la **IP de tu PC** en la red Wi‑Fi:

- En Windows: `ipconfig` y busca "Adaptador de LAN inalámbrica Wi-Fi" → **Dirección IPv4** (ej. `192.168.1.105`).
- Backend en el PC: `http://192.168.1.105:3000` (misma IP, puerto 3000).

Asegúrate de que el backend esté corriendo en el PC (`npm run start:dev` en `apps/backend`).

### 6.4 Lanzar el POS en el teléfono con debug por cable

Sustituye `192.168.1.105` por la IP de tu PC:

```powershell
cd c:\dev\rifard\apps\pos
flutter run -d <id_del_dispositivo> --dart-define=API_URL=http://192.168.1.105:3000
```

Si solo tienes un dispositivo Android conectado:

```powershell
flutter run -d android --dart-define=API_URL=http://192.168.1.105:3000
```

La app se instalará y abrirá en el teléfono. Toda la salida (logs, `debugPrint`, errores) aparecerá en esta terminal.

### 6.5 En el teléfono (login)

- **URL del servidor:** si usaste `--dart-define=API_URL=...`, la app ya usará esa URL; no hace falta cambiarla en login.
- Entra con el mismo usuario que tenga punto asignado (ej. lalberto@rifard.com).

### 6.6 Qué ver en la terminal del PC

- Mensajes tipo `POS: register-device sending pointId=... deviceId=...`
- `POS: register-device OK` o `POS: register-device failed 400 ...`
- `POS: heartbeat ...` y cualquier error de red o servidor.

Así puedes seguir el flujo (login → selección de punto → venta) y ver en tiempo real por qué falla el registro o las loterías.
