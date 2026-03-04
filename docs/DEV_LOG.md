# Dev Log — Sistema Loteria Dominicana (Rifard)

## 2026-02-27

### Pantalla Pagos y reglas de números

**Pagos (multiplicadores por tipo de jugada)**
- Nueva tabla `payout_config` (bet_type, multiplier). Migración `0004_payout_config.sql` con valores por defecto: quiniela 15, pale 50, tripleta 500, superpale 1000.
- Backend: módulo `PayoutsModule` (GET /payouts, PUT /payouts). TicketsService usa multiplicadores desde BD para calcular `potential_payout`.
- Backoffice: pantalla **Pagos** (/pagos) con tabla Quiniela, Palé, Tripleta, Superpalé y campo multiplicador por fila con botón Guardar. Enlace en sidebar.

**Reglas de números (1–100, 00 = 100, 01–09)**
- `common/number-rules.ts`: `normalizeLotteryNumber`, `validateAndNormalizeOne`, `validateAndNormalizeNumbers(betType)`. Números del 1 al 100; 100 se representa "00"; 1–9 con cero a la izquierda (01–09). No se permiten valores fuera de rango.
- Tickets: al crear ticket se validan y normalizan los números de cada línea según el bet_type (quiniela 1, pale 2, tripleta/superpale 3).
- Resultados: al ingresar primera/segunda/tercera se normalizan con la misma regla.

---

## 2025-02-27

### Módulo: DB + Backend + Flutter POS + Backoffice

**Tablas / migración**
- Creado `supabase_migrations/0001_core.sql`: enums (`draw_state`, `result_status`, `ticket_status`, `limit_type`, `bet_type`), tablas (`roles`, `users`, `user_roles`, `lotteries`, `lottery_draw_times`, `games`, `draws`, `pos_points`, `point_assignments`, `pos_devices`, `pos_presence`, `tickets`, `ticket_lines`, `draw_results`, `limit_configs`, `refresh_tokens`, `audit_logs`), índices y triggers `updated_at`.
- Constraints con `DO $$ ... EXCEPTION WHEN duplicate_object` para idempotencia.

**Prisma**
- `apps/backend/prisma/schema.prisma` alineado al SQL (UUIDs, enums, relaciones). Campos `draw_time` como String (Postgres TIME mapeado en app).

**Backend (NestJS)**
- Estructura: `src/prisma`, `src/common` (guards, decorators), `src/modules`: auth, users, lotteries, draws, results, limits, tickets, pos, reports, audit, health.
- Auth: login (email/phone + password), refresh token, JWT (access), Argon2 hash, rate limit en login (Throttler).
- RBAC: `RolesGuard` + `@Roles()`, constantes SUPER_ADMIN, ADMIN, OPERADOR_BACKOFFICE, POS_ADMIN, POS_SELLER.
- Tickets: creación con validación de límites en transacción SERIALIZABLE; print (printed_at); void con regla 5 min + draw_close_at + draw no celebrado; códigos de error VOID_WINDOW_EXPIRED, DRAW_ALREADY_CLOSED, DRAW_ALREADY_HELD.
- Resultados: enter (pending_approval), approve/reject (solo ADMIN/SUPER_ADMIN); auditoría RESULT_ENTER, RESULT_APPROVE, RESULT_REJECT.
- Límites: get/upsert/delete por lottery/draw; tipos global, by_number, by_bet_type.
- POS: heartbeat, GET connected (online/offline por last_seen), points, my-session.
- Reportes: daily-sales, commissions, voids, exposure.
- Auditoría: list con filtros (from, to, action, actorId, entity).
- Health: GET /api/v1/health (DB check).
- Swagger en /api/docs. Global prefix /api/v1. CORS y ValidationPipe configurados.

**Flutter POS (apps/pos)**
- go_router, flutter_riverpod, flutter_secure_storage, http, permission_handler.
- Pantallas: login, select-point, printer-setup (placeholder; ESC/POS Bluetooth requiere esc_pos_bluetooth_updated por namespace Android en dependencia actual), sell, ticket-detail, history, void, closeout.
- ApiClient con token en secure storage. Rutas protegidas por isLoggedInProvider (redirect a login).

**Flutter Backoffice (apps/backoffice)**
- Tema dark por defecto (AppColors: primary #2563EB, background #0B1220, surface #111827, etc.).
- go_router, Riverpod, AppShell con NavigationRail (Dashboard, Loterías, Sorteos, Resultados, Límites, POS Conectados, Usuarios, Vendedores, Reportes, Auditoría).
- Pantallas skeleton: dashboard con enlaces a resultados y generar sorteos; resto CRUD/lista como placeholders.

**Módulo Resultados (Backoffice)**
- Pantalla Resultados con dos pestañas: **Ingresar** y **Pendientes aprobación**.
- Ingresar: filtro por fecha (servidor), lista de sorteos cerrados, formulario JSON para resultados, guardar => pending_approval (validación backend: sorteo cerrado y hora del sorteo pasada).
- Pendientes: lista de resultados pendientes de aprobación; botones Aprobar (ADMIN/SUPER_ADMIN) y Rechazar (con motivo opcional). Auditoría RESULT_ENTER, RESULT_APPROVE, RESULT_REJECT en backend.
- Providers: pendingResultsProvider, drawResultProvider(drawId), enterResult, approveResult, rejectResult, resultsDrawsForDateProvider(date).

**Módulo Límites (Backoffice)**
- Pantalla Límites con alcance **lotería + sorteo** (filtro fecha, dropdown lotería, dropdown sorteo del día).
- Tres pestañas: **Global** (exposición total máx.), **Por número** (límite por número ej. "23"), **Por tipo jugada** (quiniela, palé, tripleta, superpalé).
- Tabla por pestaña: tipo, detalle (número o tipo jugada), máximo pago, activo, acciones editar/eliminar.
- Diálogo crear/editar: maxPayout, active; por número añade numberKey; por tipo jugada añade betType. API GET/PUT/DELETE /limits (solo ADMIN/SUPER_ADMIN).

**Pendientes / próximos pasos**
- Aplicar migración en Supabase vía MCP `apply_migration` (nombre `core_schema`).
- Seed de roles (SUPER_ADMIN, ADMIN, …) y usuario inicial.
- Completar resto de pantallas backoffice (POS Conectados, Usuarios, Vendedores, etc.) consumiendo API.
- POS: integrar esc_pos_bluetooth_updated o corregir namespace en flutter_bluetooth_basic; heartbeat cada 10–30 s en venta; persistir pointId/deviceId en sesión.
- Tests: unit (límites, void, resultados), E2E backend, opcional Flutter.
- Docker Compose (Postgres + backend) y CI (lint, test, build).
