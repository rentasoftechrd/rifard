import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface AuditLogInput {
  action: string;
  entity: string;
  entityId?: string | null;
  actorUserId?: string | null;
  meta?: Record<string, unknown>;
  ip?: string | null;
  userAgent?: string | null;
}

@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  async log(input: AuditLogInput) {
    return this.prisma.auditLog.create({
      data: {
        action: input.action,
        entity: input.entity,
        entityId: input.entityId ?? null,
        actorUserId: input.actorUserId ?? null,
        meta: (input.meta ?? {}) as object,
        ip: input.ip ?? null,
        userAgent: input.userAgent ?? null,
      },
    });
  }

  async findMany(filters: { from?: Date; to?: Date; action?: string; actorId?: string; entity?: string }, page = 1, limit = 50) {
    const where: Record<string, unknown> = {};
    if (filters.from) where.createdAt = { ...((where.createdAt as object) || {}), gte: filters.from };
    if (filters.to) where.createdAt = { ...((where.createdAt as object) || {}), lte: filters.to };
    if (filters.action) where.action = filters.action;
    if (filters.actorId) where.actorUserId = filters.actorId;
    if (filters.entity) where.entity = filters.entity;
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { actor: { select: { id: true, fullName: true, email: true } } },
      }),
      this.prisma.auditLog.count({ where }),
    ]);
    return { data, meta: { total, page, limit } };
  }
}
