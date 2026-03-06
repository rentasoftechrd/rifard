# Especificación técnica – POS Android (Lotería/Banca)

## Objetivo

POS online-first (sin SQLite): venta rápida de tickets, trazabilidad completa, fechas/horas siempre del servidor en zona RD (America/Santo_Domingo).

## Pantallas (flujo principal)

| # | Pantalla      | Descripción |
|---|---------------|-------------|
| 1 | **Login**     | Usuario/clave, Terminal, Estado (Online), Hora servidor (RD). |
| 2 | **Home/Menú** | Terminal \| Cajero \| Online \| Hora servidor. Botones: VENTAS, PAGOS/COBROS, CUADRE/CIERRE. Opc: Consultar ticket, Resultados, Config. |
| 3 | **Ventas**    | Sorteo/juego → Carrito (número, monto, agregar). Total. Limpiar / Validar / Ir a Pago. Hora servidor RD. |
| 4 | **Pago**      | Draft/total, método (Efectivo/Otro), Recibido, Devuelta. Confirmar Pago. Hora servidor RD. |
| 5 | **Cuadre**    | Rango (server), Resumen (Ventas, Anulaciones, Net, Tickets). Generar reporte / Cerrar turno. Hora servidor RD. |

## Reglas clave

- **Hora/fecha:** Nunca `DateTime.now()` para lo contable. Todo desde servidor vía `GET /api/v1/health/time`.
- **Sin DB local:** Sin SQLite. Backend (Postgres vía API) es la única fuente de verdad.
- **Terminal:** Device binding (register-device) antes de permitir ventas; mostrar Terminal + estado Online/Offline.

## Backend – lo que ya existe

| Requisito        | Endpoint / módulo | Notas |
|------------------|-------------------|--------|
| Hora servidor RD | `GET /api/v1/health/time` | Público. Devuelve `serverTimeUtc`, `serverTimeLocal`, `serverDate`, `timezone`, `offsetMinutes`. |
| Login            | `POST /api/v1/auth/login` | Email/phone + password. JWT access + refresh. |
| Refresh          | `POST /api/v1/auth/refresh` | Body: `{ "refreshToken": "..." }`. |
| Puntos del usuario | `GET /api/v1/pos/points` | Requiere auth. Lista puntos asignados al usuario. |
| Registrar dispositivo | `POST /api/v1/pos/register-device` | Body: `deviceId`, `pointId`. Requiere que el usuario tenga el punto asignado. |
| Heartbeat        | `POST /api/v1/pos/heartbeat` | Mantiene terminal “online”. |
| Crear ticket     | `POST /api/v1/tickets` | Body: `pointId`, `deviceId`, `lines[]`. Validación de límites en backend. |
| Loterías         | `GET /api/v1/lotteries` | Catálogo. |
| Sorteos          | `GET /api/v1/draws?date=YYYY-MM-DD&lotteryId=...` | Por fecha y lotería. |
| Reportes         | `GET /api/v1/reports/daily-sales?date=...&pointId=...&sellerId=...` | Para cuadre por punto/vendedor. |

## Backend – posibles extensiones (futuro)

- `GET /api/v1/pos/bootstrap`: catálogo mínimo (juegos, sorteos, límites, permisos) en una llamada.
- `POST /api/v1/tickets/draft` + `POST /api/v1/tickets/confirm`: flujo draft → confirm (opcional).
- `GET /api/v1/reports/closeout?pointId=&from=&to=`: reporte de cierre por rango (server).
- `POST /api/v1/shifts/open` y `POST /api/v1/shifts/close`: si se implementa modelo de turnos.

## POS Flutter – arquitectura

- **Estado:** Riverpod (session, serverClock, cart/draft, etc.).
- **Capas:** UI (pantallas) → providers (casos de uso) → ApiClient (HTTP).
- **Persistencia:** Solo tokens y URL en FlutterSecureStorage; nada contable en local.

## Providers recomendados

| Provider            | Responsabilidad |
|---------------------|-----------------|
| `serverClockProvider` | Llama `GET /health/time`, expone hora RD y actualización periódica (ej. cada 30 s). |
| `sessionProvider` / `authProvider` | Token, usuario actual, logout. |
| `posSessionProvider` | pointId, deviceId (tras seleccionar punto y register-device). |
| `sellCartProvider`  | Carrito en memoria (jugadas, total). Se limpia al confirmar o cancelar. |
| `closeoutProvider`  | Datos de reporte de cierre (daily-sales o closeout) por rango. |

## Rutas POS (go_router)

- `/login` → LoginScreen  
- `/home` → HomeScreen (menú principal)  
- `/sell` → SellScreen (ventas / carrito)  
- `/payment` → PaymentScreen (confirmar pago)  
- `/closeout` → CloseoutScreen (cuadre / cierre)  
- `/select-point` → SelectPointScreen (elegir punto tras login, si aplica)  
- Opc: `/history`, `/void`, `/results`, `/config`

## Seguridad (resumen)

- JWT access corto + refresh con rotación.
- Device binding: register-device con pointId + deviceId; heartbeat para “Online”.
- Auto-lock por inactividad (opcional): PIN del cajero.
- FLAG_SECURE en pantallas sensibles (evitar screenshots).
- Auditoría en backend (quién, cuándo, terminal, acción).

## Checklist de implementación

- [x] Provider de hora servidor (GET /health/time). Login y pantallas muestran "Hora servidor (RD)".
- [ ] Login: campos usuario/clave, llamar /health/time y mostrar “Hora servidor (RD)”, estado conexión/terminal.
- [x] Tras login: selección de punto → register-device en ventas → Home.
- [x] Home: barra Terminal, Cajero, Online, Hora servidor; botones VENTAS, PAGOS, CUADRE.
- [x] Ventas: Lotería/Sorteo, entrada rápida (número, monto, Agregar), lista jugadas, total, Limpiar/Validar/Ir a Pago; hora servidor en barra.
- [x] Pago (/payment): total, método (Efectivo/Otro), Recibido, Devuelta, Confirmar Pago → POST /tickets; éxito → detalle ticket o /sell.
- [x] Cuadre: GET /pos/closeout con fecha servidor; resumen Ventas, Anulaciones, Net, Tickets; Generar reporte / Cerrar turno.

## Problemas frecuentes (401, “no entra”)

- **Misma URL y punto asignado pero 401:** El access token del backend expira en **15 minutos**. La app POS ahora guarda el refresh token y, ante un 401, intenta renovar el token y repetir la petición. Si aun así falla, en el **diagnóstico** (icono wifi en Ventas) se muestra si el token está expirado (“Token EXPIRADO hace ~X min”). Solución: **Cerrar sesión** y volver a entrar; o en el servidor aumentar la validez del JWT con `JWT_EXPIRES_IN=24h` (variable de entorno).
- **pointId y deviceId:** Son distintos (punto de venta vs terminal). El backend no los compara entre sí; valida que el pointId esté asignado al usuario y usa el deviceId para el dispositivo. Si el diagnóstico dice “pointId de esta sesión está en la lista: false”, hay que asignar ese punto al usuario en el backoffice (Personas → usuario → Puntos).
