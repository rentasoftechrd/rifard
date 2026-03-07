# Rediseño del ticket de lotería — Especificación técnica

## 1. Análisis técnico del rediseño

### Estado actual
- **Backend**: Modelo `Ticket` (id UUID, `ticketCode` string único tipo `P-{timestamp}-{random}`), `TicketLine` por jugada (lotteryId, drawId, betType, numbers, amount). Creación en `TicketsService.create()`, búsqueda por `ticketCode` en `getByCode()`.
- **POS**: `printer_service.dart` genera bytes ESC/POS con `buildTicketBytes()`: encabezado punto/fecha/ticketCode, líneas agrupadas por lotería (sin subtotal por lotería), total. Solo 80mm. Sin QR, sin barcode, sin notas. Fecha/hora desde `createdAt` (UTC, sin formateo AM/PM).
- **Anulación**: Ventana de 5 min desde `printedAt`, más reglas de cierre de sorteo (`draw-schedule.helper.ts`).

### Objetivos del rediseño
1. **ticketNumber** legible: formato `YYYYMMDD` + correlativo 5 dígitos, generado en backend, único por día (America/Santo_Domingo).
2. **Impresión**: diseño oficial con encabezado “LOTERIA R”, Ticket/Fecha/Hora/Terminal/Cajero, jugadas agrupadas por lotería con columnas JGO / NUMERO / APUESTA, subtotal por lotería, total, QR, CODE128, notas fijas.
3. **Compatibilidad**: 58mm y 80mm, sin romper flujo actual (se mantiene `id` y se añade `ticketNumber`; `ticketCode` puede igualarse a `ticketNumber` para no duplicar lógica).
4. **Validación futura**: URL en QR `https://dominio.com/t/{ticketNumber}`, endpoint público `GET /t/:ticketNumber` preparado.
5. **Anulación**: ventana configurable desde creación del ticket (server time), por defecto 5 min.

### Decisiones de diseño
- **Backend** genera `ticketNumber` en el mismo flujo de creación del ticket; no se expone UUID en impresión ni en APIs públicas.
- **Zona horaria** única: `America/Santo_Domingo` para numeración y para fecha/hora mostrada en ticket.
- **Barcode**: CODE128 con valor `ticketNumber`.
- **QR**: URL configurable (env `TICKET_QR_BASE_URL`), por defecto `https://ejemplo.com/t/`.
- **Notas**: lista fija obligatoria + campo/configuración futura para notas opcionales por banca.

---

## 2. Propuesta de estructura de datos y modelos

### 2.1 Base de datos (Prisma)

**Ticket (actual + nuevos campos)**
- `id` (UUID) — se mantiene.
- `ticket_code` — se mantiene por compatibilidad; en creación se asignará igual a `ticket_number`.
- **`ticket_number`** (nuevo): string único, formato `YYYYMMDD00001` (12 caracteres). Índice único. Generado en backend.
- `point_id`, `device_id`, `seller_user_id`, `status`, `total_amount`, `printed_at`, `voided_at`, `paid_at`, `created_at`, `updated_at` — sin cambio.
- **`sold_at`** (opcional): DateTime, hora de venta en servidor (puede ser igual a `created_at` o setearse explícitamente en timezone RD). Si no se añade, se usa `created_at` para ventana de anulación.

**TicketLine** — sin cambio (lotteryId, drawId, betType, numbers, amount, potentialPayout).

**Secuencia diaria (nueva tabla)**
- Tabla: `ticket_daily_sequence`.
- Campos: `date` (DATE, PK), `next_value` (INT, default 1).
- Uso: en cada creación de ticket del día, hacer `SELECT ... FOR UPDATE`, leer `next_value`, devolver `YYYYMMDD + pad(next_value, 5)`, incrementar `next_value`, commit. Así se evitan colisiones concurrentes.

Alternativa sin tabla nueva: usar `SELECT COUNT(*) + 1 FROM tickets WHERE created_at::date = today` con bloqueo. Menos robusto bajo concurrencia alta. Se recomienda tabla de secuencia.

### 2.2 Formato de datos para impresión (payload al POS)

El backend al devolver un ticket (getByCode / getByTicketNumber) debe exponer una forma que el POS pueda usar para imprimir. Se propone que el POS construya el DTO de impresión a partir del ticket completo:

```json
{
  "ticketNumber": "2026070300001",
  "date": "03/07/2026",
  "time": "7:42 PM",
  "terminal": "POS-03",
  "cashier": "Maria",
  "groups": [
    {
      "lotteryName": "Nacional",
      "subtotal": 100,
      "plays": [
        { "playType": "Q", "number": "15", "amount": 50 },
        { "playType": "P", "number": "12-15", "amount": 50 }
      ]
    }
  ],
  "total": 150,
  "barcodeValue": "2026070300001",
  "qrValue": "https://dominio.com/t/2026070300001",
  "notes": [
    "NO SE PAGA SIN TICKET",
    "NO SE ANULAN TICKETS DESPUES DE 5 MINUTOS",
    "VERIFIQUE SU JUGADA ANTES DE RETIRARSE"
  ]
}
```

- **terminal**: nombre o código del punto (point.name o point.code); si no hay, derivar de deviceId.
- **cashier**: seller.fullName.
- **groups**: agrupación de `lines` por `lotteryId` (lottery.name), con `plays` (betType → abreviatura, numbers, amount) y `subtotal` por lotería.
- **date/time**: formateados en backend en America/Santo_Domingo (DD/MM/YYYY, h:mm AM/PM).
- **qrValue**: base URL configurable + ticketNumber.
- **notes**: fijas por ahora; luego extensible por configuración.

---

## 3. Estrategia para ticketNumber diario sin colisiones

### 3.1 Tabla de secuencia

```sql
CREATE TABLE ticket_daily_sequence (
  date DATE PRIMARY KEY,
  next_value INT NOT NULL DEFAULT 1
);
```

- **date**: fecha en timezone America/Santo_Domingo (solo el día).
- **next_value**: próximo correlativo a usar (1, 2, 3, …).

### 3.2 Algoritmo en el backend (dentro de la transacción de creación del ticket)

1. Obtener fecha de hoy en America/Santo_Domingo → `todayStr` (YYYY-MM-DD).
2. Dentro de la misma transacción que crea el ticket:
   - `INSERT INTO ticket_daily_sequence (date, next_value) VALUES (todayStr, 1) ON CONFLICT (date) DO UPDATE SET next_value = ticket_daily_sequence.next_value RETURNING next_value`  
     **o** mejor: `SELECT next_value FROM ticket_daily_sequence WHERE date = todayStr FOR UPDATE SKIP LOCKED`; si no hay fila, insertar (1); si hay, leer `next_value`, luego `UPDATE ticket_daily_sequence SET next_value = next_value + 1 WHERE date = todayStr`.
3. Formatear: `ticketNumber = todayStr.replace(/-/g, '') + String(seq).padStart(5, '0')` (ej. 20260703 + 00001).
4. Crear `Ticket` con `ticketNumber` y `ticketCode = ticketNumber`.
5. Commit.

Con `FOR UPDATE` (o equivalente en Prisma con raw query o transacción serializable) se evitan colisiones entre requests concurrentes.

### 3.3 Índices

- `tickets.ticket_number` UNIQUE.
- Búsqueda por ticketNumber en GET /tickets/number/:ticketNumber y en GET público /t/:ticketNumber.

---

## 4. Diseño visual del ticket (58mm y 80mm)

### 4.1 Anchos de referencia
- **58mm**: ~32 caracteres en fuente estándar.
- **80mm**: ~48 caracteres.

### 4.2 Plantilla 80mm (base oficial)

```
================================
           LOTERIA R
        Sistema Autorizado
================================

Ticket   : 2026070300001
Fecha    : 03/07/2026
Hora     : 7:42 PM
Terminal : POS-03
Cajero   : Maria

--------------------------------
            JUGADAS
--------------------------------

LOTERIA: NACIONAL

JGO   NUMERO        APUESTA
Q     15            $50
P     12-15         $50

-------------------------------
SUBTOTAL            $100

--------------------------------
LOTERIA: LOTEKA
...
================================
TOTAL               $150
================================

   ESCANEA PARA VALIDAR
         [QR CODE]

||||||||||||||||||||||||
      2026070300001
       CODE 128

--------------------------------
NO SE PAGA SIN TICKET
NO SE ANULAN TICKETS DESPUES DE 5 MINUTOS
VERIFIQUE SU JUGADA ANTES DE RETIRARSE

--------------------------------
        GRACIAS POR JUGAR
================================
```

### 4.3 Plantilla 58mm

Misma estructura; reducir separadores a ~32 caracteres, acortar etiquetas si hace falta (ej. “Ticket:”, “Fecha:”, “Hora:”, “Term:”, “Cajero:”). Columnas JGO (3) + NUMERO (ancho variable, truncar si es largo) + APUESTA (derecha, ej. 6 caracteres). QR y barcode un poco más pequeños para que no se corten.

### 4.4 Helpers de impresión (Flutter)

- **center(String text, int width)**: rellenar con espacios a izquierda/derecha para centrar.
- **columns(List<({String text, int width})>)**: concatenar textos con ancho fijo por columna (truncar o pad).
- **currency(num amount)**: formatear como $XX o $XX.00.
- **separator(char ch, int width)**: línea de `ch` repetido `width` veces.
- **paperWidth(PaperSize)**: 32 para 58mm, 48 para 80mm (o valores que use la librería).

---

## 5. Endpoints y API

### 5.1 Existentes (adaptar)
- **POST /tickets**: crear ticket; backend asigna `ticketNumber` (y `ticketCode = ticketNumber`); respuesta incluye `ticketNumber`, fecha/hora en timezone RD.
- **GET /tickets/code/:code**: mantener; que acepte tanto `ticketCode` como `ticketNumber` (o redirigir internamente).
- **GET /tickets/code/:code/payment**: igual, por código o por ticketNumber.

### 5.2 Nuevos
- **GET /tickets/number/:ticketNumber**: devolver ticket completo por número (para reimpresión y para que el POS arme el DTO de impresión). Roles: POS_SELLER, admin, etc.
- **GET /t/:ticketNumber** (público, sin auth): validación pública del ticket. Respuesta mínima: válido/no válido, estado (sold/voided/paid), total, mensaje. Preparado para futura página web al escanear QR.

### 5.3 Configuración
- **TICKET_QR_BASE_URL**: base de la URL del QR (ej. `https://tu-dominio.com/t/`).
- **BANCO_TIMEZONE**: ya existe, `America/Santo_Domingo`.
- **VOID_WINDOW_MINUTES**: ventana de anulación en minutos desde creación (default 5). Usar `createdAt` (o `soldAt` si se añade) en servidor.

---

## 6. Reglas de anulación y preparación de pago

- **Anulación**: solo permitida dentro de los primeros N minutos (configurable) desde `created_at` (hora servidor), y mientras el sorteo no haya cerrado. La regla actual en `canVoid` usa `printedAt`; se puede cambiar a `createdAt` y hacer el límite configurable por env.
- **Pago**: el ticket ya se consulta por código/ticketNumber; dejar preparado que validación/pago use `ticketNumber`, barcode, QR y estado, sin implementar aún toda la lógica de premios.

---

## 7. Validación corta (VAL: XXXX)

- Opcional: campo o función `shortValidationCode` = f(ticketNumber + secret). Ej. primeros 4 caracteres de HMAC. No obligatorio en Fase 1; dejar preparado en el modelo (campo opcional o método en servicio).

---

## 8. Lista de archivos a crear/modificar

### Backend (Nest + Prisma)
- `prisma/schema.prisma`: añadir `ticket_number` (unique) a `Ticket`; tabla `ticket_daily_sequence` (date, next_value).
- `modules/tickets/tickets.service.ts`: generar `ticketNumber` en create (secuencia diaria); formatear fecha/hora RD; getByTicketNumber; opcional getByCode que acepte ticketNumber.
- `modules/tickets/ticket-number.service.ts` (nuevo): `getNextTicketNumber(date: Date): Promise<string>` usando tabla de secuencia con bloqueo.
- `modules/tickets/tickets.controller.ts`: GET /tickets/number/:ticketNumber; GET /t/:ticketNumber (controlador público o en módulo público).
- `modules/tickets/dto`: respuesta de ticket con date/time formateados y/o DTO de impresión.
- `draw-schedule.helper.ts`: ventana de anulación desde `createdAt` y VOID_WINDOW_MINUTES.

### POS Flutter
- `lib/core/printer/printer_service.dart`: reemplazar/ampliar `buildTicketBytes` con nuevo layout; soporte 58/80mm; QR; barcode CODE128; notas; helpers (center, columns, currency, separator).
- `lib/core/printer/ticket_print_model.dart` (nuevo): DTO del ticket para impresión (ticketNumber, date, time, terminal, cashier, groups, total, qrValue, barcodeValue, notes).
- Construcción del DTO desde la respuesta del API (agrupar por lotería, formatear tipos de jugada Q/P/T/SP).

### Config / env
- `.env.example`: TICKET_QR_BASE_URL, VOID_WINDOW_MINUTES.

---

## 9. Migración SQL (si no usas Prisma migrate)

Si usas Supabase u otro flujo de migraciones, aplica manualmente:

```sql
CREATE TABLE ticket_daily_sequence (
  date       DATE PRIMARY KEY,
  next_value INT  NOT NULL DEFAULT 1
);

ALTER TABLE tickets ADD COLUMN ticket_number TEXT UNIQUE;
CREATE UNIQUE INDEX IF NOT EXISTS tickets_ticket_number_key ON tickets (ticket_number) WHERE ticket_number IS NOT NULL;
```

## 10. Plan de implementación paso a paso

1. **Backend – Schema y migración**: añadir `ticket_number` a `tickets`, crear `ticket_daily_sequence`; migración.
2. **Backend – Ticket number service**: implementar obtención de siguiente correlativo con bloqueo.
3. **Backend – Create ticket**: en `create()`, obtener ticketNumber, asignar `ticketCode = ticketNumber`, guardar; incluir en respuesta date/time en zona RD.
4. **Backend – getByTicketNumber y GET /t/:ticketNumber**: búsqueda por ticketNumber; endpoint público con respuesta mínima de validación.
5. **Backend – Void**: usar createdAt y VOID_WINDOW_MINUTES (y reglas de sorteo actuales).
6. **POS – Modelo de impresión**: clase/struct con ticketNumber, date, time, terminal, cashier, groups, total, qrValue, barcodeValue, notes; función que construye esto desde el ticket completo del API.
7. **POS – Helpers**: center, columns, currency, separator, paperWidth.
8. **POS – buildTicketBytes**: nuevo diseño con encabezado, datos, jugadas por lotería, subtotales, total, QR, barcode, notas; parámetro 58 vs 80mm.
9. **POS – Integración**: que checkout/detalle sigan usando el mismo flujo pero con el nuevo formato de respuesta (ticketNumber, etc.) y la nueva impresión.
10. **Pruebas**: crear ticket, reimprimir, validar GET /t/:ticketNumber, anulación dentro/fuera de ventana.

---

## 10. Tipos de jugada (abreviaturas)

| BetType   | Abreviatura impresión |
|----------|------------------------|
| quiniela | Q                      |
| pale     | P                      |
| tripleta | T                      |
| superpale| SP                     |

El modelo actual ya usa el enum BetType; en impresión se mapea a estas abreviaturas.
