import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

const TIMEZONE = 'America/Santo_Domingo';

/** Returns today's date as YYYY-MM-DD in America/Santo_Domingo */
export function getTodayInRD(): string {
  return new Date().toLocaleDateString('en-CA', { timeZone: TIMEZONE });
}

/**
 * Returns the next ticket number for the current day (America/Santo_Domingo).
 * Format: YYYYMMDD + 5-digit correlative (e.g. 2026070300001).
 * Must be called inside a transaction to avoid collisions.
 */
@Injectable()
export class TicketNumberService {
  constructor(private prisma: PrismaService) {}

  /**
   * Get next ticket number for the given date (in RD timezone).
   * Uses ticket_daily_sequence with INSERT...ON CONFLICT to avoid race conditions.
   * @param tx - Prisma transaction client (must be same transaction as ticket creation)
   */
  async getNextTicketNumber(tx: Pick<PrismaService, '$queryRawUnsafe'>): Promise<string> {
    const dateStr = getTodayInRD(); // YYYY-MM-DD
    const result = await tx.$queryRawUnsafe<{ next_value: number }[]>(
      `INSERT INTO ticket_daily_sequence (date, next_value)
       VALUES ($1::date, 1)
       ON CONFLICT (date) DO UPDATE SET next_value = ticket_daily_sequence.next_value + 1
       RETURNING next_value`,
      dateStr,
    );
    const nextValue = result[0]?.next_value ?? 1;
    const datePart = dateStr.replace(/-/g, ''); // YYYYMMDD
    return `${datePart}${String(nextValue).padStart(5, '0')}`;
  }
}
