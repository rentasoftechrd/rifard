const { PrismaClient } = require('@prisma/client');
const argon2 = require('argon2');

const prisma = new PrismaClient();

const ROLES = [
  { code: 'SUPER_ADMIN', name: 'Super Administrador' },
  { code: 'ADMIN', name: 'Administrador / Gerente' },
  { code: 'OPERADOR_BACKOFFICE', name: 'Operador Backoffice' },
  { code: 'POS_ADMIN', name: 'Admin POS' },
  { code: 'POS_SELLER', name: 'Vendedor POS' },
];

const ADMIN_EMAIL = 'admin@rifard.com';
const ADMIN_PASSWORD = 'Admin123!';

async function main() {
  for (const role of ROLES) {
    await prisma.role.upsert({
      where: { code: role.code },
      create: role,
      update: { name: role.name },
    });
  }
  console.log('Roles seeded');

  const superAdminRole = await prisma.role.findUnique({ where: { code: 'SUPER_ADMIN' } });
  if (!superAdminRole) throw new Error('SUPER_ADMIN role not found');

  const existing = await prisma.user.findUnique({ where: { email: ADMIN_EMAIL } });
  if (!existing) {
    const passwordHash = await argon2.hash(ADMIN_PASSWORD, { type: argon2.argon2id });
    const user = await prisma.user.create({
      data: {
        email: ADMIN_EMAIL,
        fullName: 'Administrador',
        passwordHash,
        active: true,
      },
    });
    await prisma.userRole.create({
      data: { userId: user.id, roleId: superAdminRole.id },
    });
    console.log('Usuario admin creado:', ADMIN_EMAIL, '/', ADMIN_PASSWORD);
  } else {
    console.log('Usuario', ADMIN_EMAIL, 'ya existe');
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
