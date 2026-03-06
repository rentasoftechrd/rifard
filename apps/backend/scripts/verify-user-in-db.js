/**
 * Verifica en la base de datos si un usuario existe, está activo y tiene roles.
 * Útil para descartar que el error del POS sea "usuario no válido en BD".
 *
 * Ejecutar desde apps/backend:
 *   CHECK_EMAIL=usuario@ejemplo.com node scripts/verify-user-in-db.js
 *   CHECK_PHONE=8095551234 node scripts/verify-user-in-db.js
 *
 * Requiere DATABASE_URL (se carga desde .env si existe en apps/backend/.env).
 */
const path = require('path');
const fs = require('fs');
const envPath = path.resolve(__dirname, '../.env');
if (fs.existsSync(envPath)) {
  const content = fs.readFileSync(envPath, 'utf8');
  content.split('\n').forEach((line) => {
    const m = line.match(/^\s*([^#=]+)=(.*)$/);
    if (m) process.env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, '');
  });
}
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  const email = process.env.CHECK_EMAIL;
  const phone = process.env.CHECK_PHONE;

  if (!email && !phone) {
    console.log('Uso: CHECK_EMAIL=tu@email.com node scripts/verify-user-in-db.js');
    console.log('  o: CHECK_PHONE=8095551234 node scripts/verify-user-in-db.js');
    process.exitCode = 1;
    return;
  }

  const where = email
    ? { OR: [{ email: email.trim() }, { email: email.trim().toLowerCase() }] }
    : { phone: (phone || '').trim() };

  const user = await prisma.user.findFirst({
    where,
    select: {
      id: true,
      email: true,
      phone: true,
      fullName: true,
      active: true,
      personaId: true,
      userRoles: { select: { role: { select: { code: true } } } },
      pointAssignments: { where: { active: true }, select: { pointId: true } },
    },
  });

  if (!user) {
    console.log('Usuario NO encontrado en la base de datos.');
    console.log('  Identificador buscado:', email || phone);
    console.log('  Posibles causas: el email/teléfono no existe o tiene espacios/capitalización distinta.');
    process.exitCode = 1;
    return;
  }

  const roles = user.userRoles.map((ur) => ur.role.code);
  const points = user.pointAssignments.map((a) => a.pointId);

  console.log('--- Usuario encontrado en la BD ---');
  console.log('  id:', user.id);
  console.log('  email:', user.email);
  console.log('  phone:', user.phone || '(vacío)');
  console.log('  fullName:', user.fullName);
  console.log('  active:', user.active);
  console.log('  roles:', roles.length ? roles.join(', ') : '(ninguno)');
  console.log('  puntos asignados (pointId):', points.length ? points.join(', ') : '(ninguno)');
  console.log('');

  if (!user.active) {
    console.log('ERROR: El usuario está INACTIVO (active=false). No puede hacer login.');
    process.exitCode = 1;
    return;
  }
  if (roles.length === 0) {
    console.log('ADVERTENCIA: El usuario no tiene roles. El login puede emitir token pero las rutas protegidas por rol pueden fallar.');
  }
  if (points.length === 0 && roles.includes('POS_SELLER')) {
    console.log('ADVERTENCIA: Usuario POS_SELLER sin puntos asignados. Asigna un punto en Backoffice (Personas → usuario → Puntos).');
  }

  console.log('El usuario está en la BD, activo y puede autenticarse si la contraseña es correcta.');
}

main()
  .catch((e) => {
    console.error('Error:', e.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
