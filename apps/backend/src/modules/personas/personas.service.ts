import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { TipoPersona } from '@prisma/client';
import { CreatePersonaDto, UpdatePersonaDto } from './dto';

@Injectable()
export class PersonasService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreatePersonaDto) {
    if (dto.cedula?.trim()) {
      const existing = await this.prisma.persona.findFirst({
        where: { cedula: dto.cedula.trim() },
      });
      if (existing) throw new ConflictException('Ya existe una persona con esta cédula');
    }
    return this.prisma.persona.create({
      data: {
        fullName: dto.fullName,
        cedula: dto.cedula?.trim() || null,
        phone: dto.phone?.trim() || null,
        email: dto.email?.trim() || null,
        address: dto.address?.trim() || null,
        sector: dto.sector?.trim() || null,
        city: dto.city?.trim() || null,
        tipo: (dto.tipo as TipoPersona) || 'OTRO',
      },
    });
  }

  async findAll(page = 1, limit = 50, tipo?: TipoPersona, sinUsuario = false) {
    const skip = (page - 1) * limit;
    const where: { tipo?: TipoPersona; user?: null } = {};
    if (tipo) where.tipo = tipo;
    if (sinUsuario) where.user = null;
    const posRoleIds = await this.prisma.role
      .findMany({ where: { code: { in: ['POS_SELLER', 'POS_ADMIN'] } }, select: { id: true } })
      .then((r) => r.map((x) => x.id));

    const [data, total] = await Promise.all([
      this.prisma.persona.findMany({
        where,
        skip,
        take: limit,
        orderBy: { fullName: 'asc' },
        include: {
          user: {
            select: {
              id: true,
              email: true,
              active: true,
              userRoles: { include: { role: { select: { code: true } } } },
              pointAssignments: {
                where: { active: true },
                include: { point: { select: { id: true, name: true, code: true } } },
              },
            },
          },
        },
      }),
      this.prisma.persona.count({ where }),
    ]);

    const dataWithVendor = data.map((p) => {
      const user = p.user;
      const isVendedor =
        user &&
        user.userRoles.some((ur) => posRoleIds.includes(ur.roleId));
      const assignments = isVendedor && user
        ? user.pointAssignments.map((a) => ({
            pointId: a.pointId,
            pointName: a.point.name,
            pointCode: a.point.code,
            commissionPercent: Number(a.commissionPercent),
          }))
        : [];
      return {
        id: p.id,
        fullName: p.fullName,
        cedula: p.cedula,
        phone: p.phone,
        email: p.email,
        address: p.address,
        sector: p.sector,
        city: p.city,
        tipo: p.tipo,
        createdAt: p.createdAt,
        user: user
          ? {
              id: user.id,
              email: user.email,
              active: user.active,
              roles: user.userRoles.map((ur) => ur.role.code),
            }
          : null,
        isVendedor: !!isVendedor,
        userId: user?.id ?? null,
        assignments,
      };
    });

    return { data: dataWithVendor, meta: { total, page, limit } };
  }

  async findOne(id: string) {
    const p = await this.prisma.persona.findUnique({
      where: { id },
      include: { user: { select: { id: true, email: true, active: true } } },
    });
    if (!p) throw new NotFoundException('Persona no encontrada');
    return p;
  }

  async update(id: string, dto: UpdatePersonaDto) {
    await this.findOne(id);
    if (dto.cedula?.trim()) {
      const existing = await this.prisma.persona.findFirst({
        where: { cedula: dto.cedula.trim(), NOT: { id } },
      });
      if (existing) throw new ConflictException('Ya existe otra persona con esta cédula');
    }
    return this.prisma.persona.update({
      where: { id },
      data: {
        ...(dto.fullName != null && { fullName: dto.fullName }),
        ...(dto.cedula !== undefined && { cedula: dto.cedula?.trim() || null }),
        ...(dto.phone !== undefined && { phone: dto.phone?.trim() || null }),
        ...(dto.email !== undefined && { email: dto.email?.trim() || null }),
        ...(dto.address !== undefined && { address: dto.address?.trim() || null }),
        ...(dto.sector !== undefined && { sector: dto.sector?.trim() || null }),
        ...(dto.city !== undefined && { city: dto.city?.trim() || null }),
        ...(dto.tipo != null && { tipo: dto.tipo as TipoPersona }),
      },
    });
  }
}
