import { BetType } from '@prisma/client';

const DEFAULT_MULTIPLIERS: Record<BetType, number> = {
  quiniela: 15,
  pale: 50,
  tripleta: 500,
  superpale: 1000,
};

/** potential_payout = amount * multiplier (multiplicadores desde BD o por defecto). */
export function calculatePotentialPayout(
  betType: BetType,
  amount: number,
  multipliers?: Record<BetType, number>,
): number {
  const mult = multipliers ?? DEFAULT_MULTIPLIERS;
  return Math.round(amount * (mult[betType] ?? DEFAULT_MULTIPLIERS[betType]) * 100) / 100;
}
