# Especificación POS Android (Lotería/Banca)

Objetivo: POS online-first (sin SQLite), todas las fechas/horas del servidor en zona RD (America/Santo_Domingo). Flujo: **Login → Menú → Ventas → Pago → Cuadre**.

---

## 1. Arquitectura

- **Backend**: fuente de verdad (Postgres). Sin DB local en el POS.
- **Hora/fecha**: siempre desde `GET /api/v1/health/time` (serverTimeLocal en RD). El POS no usa `DateTime.now()` para nada contable.
- **Estado**: Riverpod (sessionProvider, serverClockProvider, salesDraftProvider, etc.).

---

## 2. Endpoints backend (existentes o a usar)

| Endpoint | Uso |
|----------|-----|
| `GET /health/time` | Hora servidor RD (serverTimeUtc, serverTimeLocal, timezone, offsetMinutes). **Público**. |
| `GET /health/pos-connect` | Prueba conexión sin auth. |
| `POST /auth/login` | Login usuario/clave. |
| `POST /auth/refresh` | Renovar token. |
| `GET /auth/me` | Usuario actual. |
| `GET /pos/points` | Puntos asignados al usuario (tras login). |
| `POST /pos/register-device` | Vincular dispositivo al punto. |
| `POST /pos/heartbeat` | Mantener terminal online. |
| `GET /lotteries` | Catálogo loterías. |
| `GET /draws?date=&lotteryId=` | Sorteos del día. |
| `POST /tickets` | Crear ticket (pointId, deviceId, lines). |
| `POST /tickets/:id/void` | Anular ticket. |
| `GET /tickets/code/:code` | Consultar ticket. |
| `GET /reports/daily-sales?date=&pointId=&sellerId=` | Ventas para cuadre. |

---

## 3. Pantallas (según mockups)

### 3.1 Login
- Logo / título "Lotería POS".
- Usuario, Clave (con ojo).
- Botón "Iniciar sesión".
- **Abajo**: Terminal: POS-XX | Estado: Online ✅ | **Hora servidor (RD): HH:mm:ss AM/PM** (desde GET /health/time).

### 3.2 Menú (Home)
- **Barra**: Terminal | Cajero: Nombre | Online ✅ | **Hora servidor RD: HH:mm PM**.
- Botones grandes: **VENTAS**, **PAGOS / COBROS**, **CUADRE / CIERRE**.
- Opcionales: Consultar Ticket, Resultados, Configuración.

### 3.3 Ventas
- Título: VENTA - Quiniela | Sorteo 6:00 PM. **Hora servidor RD**.
- Entrada rápida: Número, Monto, [+ Agregar].
- Lista de jugadas. Total.
- [ Limpiar ] [ Validar ] [ Ir a Pago ].

### 3.4 Pago
- PAGO. Draft/Total. **Hora servidor RD**.
- Método: Efectivo / Otro. Recibido, Devuelta.
- [ Confirmar Pago ] → crea ticket en backend, luego [ Imprimir ] / [ Nueva venta ].

### 3.5 Cuadre / Cierre
- Rango (fechas servidor). Ventas, Anulaciones, Net, Tickets.
- [ Generar Reporte ] [ Cerrar Turno ].

---

## 4. Seguridad (resumen)

- JWT access + refresh. Auto-lock por inactividad (opcional).
- Device binding: terminal registrada (register-device) para poder vender.
- RBAC: Cajero (vender/cobrar), Supervisor (anular, cuadre), Admin (config).
- Auditoría en backend (login, venta, anulación, cierre).
- FLAG_SECURE en pantallas sensibles (Android).

---

## 5. Colores / tema (mockups)

- Header: azul oscuro.
- Botones: azul (VENTAS), verde (PAGOS, agregar), naranja (CUADRE).
- Fondo claro en contenido o tema oscuro según app actual (Rifard usa dark theme; se puede alinear a mockups con azul/verde).
