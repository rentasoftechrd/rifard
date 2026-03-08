import { Injectable } from '@nestjs/common';
import { BetType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

const DEFAULT_MULTIPLIERS: Record<BetType, number> = {
  quiniela: 15,
  pale: 1500,
  tripleta: 10000,
  superpale: 2000,
};

@Injectable()
export class PayoutsService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.payoutConfig.findMany({
      orderBy: [{ betType: 'asc' }, { variant: 'asc' }],
    });
  }

  /** Máximo multiplicador por tipo (para potential_payout / límites). Usa el mayor precio de cada tipo. */
  async getMultipliers(): Promise<Record<BetType, number>> {
    const rows = await this.prisma.payoutConfig.findMany();
    const map = { ...DEFAULT_MULTIPLIERS };
    for (const r of rows) {
      const num = Number(r.multiplier);
      map[r.betType] = Math.max(map[r.betType] ?? 0, num);
    }
    return map;
  }

  /** Precio para una variante concreta (p. ej. pale 1_2, tripleta 2). Para pago de premios. */
  async getMultiplierForVariant(betType: BetType, variant: string): Promise<number> {
    const v = (variant ?? '').trim();
    const row = await this.prisma.payoutConfig.findUnique({
      where: { betType_variant: { betType, variant: v || '' } },
    });
    return row ? Number(row.multiplier) : (DEFAULT_MULTIPLIERS[betType] ?? 0);
  }

  async upsert(betType: BetType, variant: string, multiplier: number) {
    const v = (variant ?? '').trim();
    return this.prisma.payoutConfig.upsert({
      where: { betType_variant: { betType, variant: v } },
      create: { betType, variant: v, multiplier },
      update: { multiplier },
    });
  }
}
