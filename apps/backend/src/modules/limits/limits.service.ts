import { Injectable, NotFoundException } from '@nestjs/common';
import { LimitType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { UpsertLimitDto } from './dto/upsert-limit.dto';

@Injectable()
export class LimitsService {
  constructor(private prisma: PrismaService) {}

  async findMany(lotteryId?: string, drawId?: string) {
    const where: { lotteryId?: string; drawId?: string } = {};
    if (lotteryId) where.lotteryId = lotteryId;
    if (drawId) where.drawId = drawId;
    return this.prisma.limitConfig.findMany({
      where,
      include: { lottery: true, draw: true },
      orderBy: [{ type: 'asc' }, { lotteryId: 'asc' }, { drawId: 'asc' }],
    });
  }

  async upsert(dto: UpsertLimitDto) {
    const data = {
      type: dto.type,
      lotteryId: dto.lotteryId ?? null,
      drawId: dto.drawId ?? null,
      betType: (dto.betType as import('@prisma/client').BetType) ?? null,
      numberKey: dto.numberKey ?? null,
      maxPayout: dto.maxPayout,
      active: dto.active ?? true,
    };
    if (dto.id) {
      const existing = await this.prisma.limitConfig.findUnique({ where: { id: dto.id } });
      if (!existing) throw new NotFoundException('Limit config not found');
      return this.prisma.limitConfig.update({ where: { id: dto.id }, data });
    }
    return this.prisma.limitConfig.create({ data });
  }

  async delete(id: string) {
    await this.prisma.limitConfig.delete({ where: { id } });
    return { success: true };
  }
}
