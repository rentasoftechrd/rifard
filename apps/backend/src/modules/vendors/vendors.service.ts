import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Decimal } from '@prisma/client/runtime/library';

export interface VendorAssignmentDto {
  pointId: string;
  commissionPercent: number;
}

@Injectable()
export class VendorsService {
  constructor(private prisma: PrismaService) {}

  async findAllPoints() {
    return this.prisma.posPoint.findMany({
      where: { active: true },
      select: { id: true, name: true, code: true },
      orderBy: { name: 'asc' },
    });
  }

  async findAll() {
    const posRoleIds = await this.prisma.role
      .findMany({ where: { code: { in: ['POS_SELLER', 'POS_ADMIN'] } }, select: { id: true } })
      .then((roles) => roles.map((r) => r.id));

    const users = await this.prisma.user.findMany({
      where: {
        active: true,
        userRoles: { some: { roleId: { in: posRoleIds } } },
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        persona: true,
        pointAssignments: {
          where: { active: true },
          include: { point: { select: { id: true, name: true, code: true } } },
        },
      },
      orderBy: { fullName: 'asc' },
    });

    return users.map((u) => ({
      id: u.id,
      fullName: u.fullName,
      email: u.email,
      persona: u.persona
        ? {
            id: u.persona.id,
            fullName: u.persona.fullName,
            cedula: u.persona.cedula,
            phone: u.persona.phone,
            email: u.persona.email,
            address: u.persona.address,
            sector: u.persona.sector,
            city: u.persona.city,
            tipo: u.persona.tipo,
          }
        : null,
      assignments: u.pointAssignments.map((a) => ({
        pointId: a.pointId,
        pointName: a.point.name,
        pointCode: a.point.code,
        commissionPercent: Number(a.commissionPercent),
      })),
    }));
  }

  /** Normaliza UUID (trim + minúsculas) para coincidir con POS y BD. */
  private normalizePointId(id: string): string {
    const s = (id ?? '').trim();
    return s ? s.toLowerCase() : s;
  }

  async setAssignments(userId: string, dto: VendorAssignmentDto[]) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado');

    await this.prisma.pointAssignment.deleteMany({ where: { sellerUserId: userId } });

    if (dto.length > 0) {
      await this.prisma.pointAssignment.createMany({
        data: dto.map((a) => ({
          pointId: this.normalizePointId(a.pointId),
          sellerUserId: userId,
          commissionPercent: new Decimal(a.commissionPercent),
          active: true,
        })),
      });
    }

    return this.findAll().then((list) => list.find((v) => v.id === userId) ?? null);
  }
}
