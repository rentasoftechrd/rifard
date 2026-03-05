import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateUserDto, UpdateUserDto, AssignRolesDto } from './dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateUserDto) {
    const persona = await this.prisma.persona.findUnique({ where: { id: dto.personaId } });
    if (!persona) throw new ConflictException('Persona no encontrada');
    const existingUserForPersona = await this.prisma.user.findUnique({ where: { personaId: dto.personaId } });
    if (existingUserForPersona) throw new ConflictException('Esta persona ya tiene una cuenta de usuario');
    const email = (dto.email?.trim() || persona.email?.trim()) || null;
    if (!email) throw new ConflictException('La persona debe tener email para crear usuario (edita la persona y añade email)');
    const existing = await this.prisma.user.findFirst({ where: { email } });
    if (existing) throw new ConflictException('Ya existe un usuario con este email');
    const passwordHash = await argon2.hash(dto.password, { type: argon2.argon2id });
    const user = await this.prisma.user.create({
      data: {
        email,
        fullName: persona.fullName,
        phone: persona.phone,
        passwordHash,
        active: dto.active ?? true,
        personaId: dto.personaId,
      },
      select: { id: true, email: true, phone: true, fullName: true, active: true, createdAt: true },
    });
    if (dto.roleIds?.length) {
      await this.prisma.userRole.createMany({
        data: dto.roleIds.map((roleId) => ({ userId: user.id, roleId })),
        skipDuplicates: true,
      });
    }
    return this.findOne(user.id);
  }

  async findAll(page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.prisma.user.findMany({
        skip,
        take: limit,
        select: {
          id: true,
          personaId: true,
          email: true,
          phone: true,
          fullName: true,
          active: true,
          createdAt: true,
          persona: true,
          userRoles: { include: { role: { select: { id: true, code: true, name: true } } } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.user.count(),
    ]);
    return { data, meta: { total, page, limit } };
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        personaId: true,
        email: true,
        phone: true,
        fullName: true,
        active: true,
        createdAt: true,
        updatedAt: true,
        persona: true,
        userRoles: { include: { role: { select: { id: true, code: true, name: true } } } },
      },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.findOne(id);
    if (dto.email) {
      const existing = await this.prisma.user.findFirst({ where: { email: dto.email, NOT: { id } } });
      if (existing) throw new ConflictException('Email already in use');
    }
    if (dto.phone !== undefined) {
      const existing = dto.phone ? await this.prisma.user.findFirst({ where: { phone: dto.phone, NOT: { id } } }) : null;
      if (existing) throw new ConflictException('Phone already in use');
    }
    const updateData: Record<string, unknown> = { ...dto };
    if (dto.password) {
      updateData.passwordHash = await argon2.hash(dto.password, { type: argon2.argon2id });
      delete updateData.password;
    }
    if (dto.personaId !== undefined) updateData.personaId = dto.personaId;
    await this.prisma.user.update({ where: { id }, data: updateData as never });
    return this.findOne(id);
  }

  async assignRoles(id: string, dto: AssignRolesDto) {
    await this.findOne(id);
    await this.prisma.userRole.deleteMany({ where: { userId: id } });
    if (dto.roleIds?.length) {
      await this.prisma.userRole.createMany({
        data: dto.roleIds.map((roleId) => ({ userId: id, roleId })),
      });
    }
    return this.findOne(id);
  }

  async setActive(id: string, active: boolean) {
    await this.prisma.user.update({ where: { id }, data: { active } });
    return this.findOne(id);
  }

  async getRoles() {
    return this.prisma.role.findMany({ orderBy: { code: 'asc' } });
  }
}
