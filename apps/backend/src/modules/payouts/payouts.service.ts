import { Injectable } from '@nestjs/common';
import { BetType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

const DEFAULT_MULTIPLIERS: Record<BetType, number> = {
  quiniela: 15,
  pale: 50,
  tripleta: 500,
  superpale: 1000,
};

@Injectable()
export class PayoutsService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    const rows = await this.prisma.payoutConfig.findMany({
      orderBy: { betType: 'asc' },
    });
    return rows;
  }

  /** Multiplicadores por tipo (desde BD o por defecto). Usado al calcular potential_payout. */
  async getMultipliers(): Promise<Record<BetType, number>> {
    const rows = await this.prisma.payoutConfig.findMany();
    const map = { ...DEFAULT_MULTIPLIERS };
    for (const r of rows) {
      map[r.betType] = Number(r.multiplier);
    }
    return map;
  }

  async upsert(betType: BetType, multiplier: number) {
    return this.prisma.payoutConfig.upsert({
      where: { betType },
      create: { betType, multiplier },
      update: { multiplier },
    });
  }
}
