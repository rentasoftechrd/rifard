import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DrawState, Prisma } from '@prisma/client';
import { getDrawCloseAt, serverNow, serverTodayISO } from '../../common/server-time';
import { PrismaService } from '../../prisma/prisma.service';

/** Minutos antes del cierre para mostrar "por cerrar" (amarillo). */
const CLOSING_SOON_MINUTES = 15;

export type DrawDisplayStatus = 'open' | 'closing_soon' | 'closed' | 'scheduled';

/** Respuesta de listado de sorteos (con displayStatus y closeAt para la UI). */
export interface DrawWithDisplayStatus {
  id: string;
  lotteryId: string;
  drawDate: Date;
  drawTime: string;
  state: string;
  createdAt?: Date;
  updatedAt?: Date;
  lottery: { id: string; name: string | null; code: string | null };
  displayStatus: DrawDisplayStatus;
  closeAt: string;
}

/** Fila de sorteo con lottery (para enriquecer con displayStatus). */
interface DrawRow {
  id: string;
  lotteryId: string;
  drawDate: Date;
  drawTime: string;
  state: string;
  createdAt?: Date;
  updatedAt?: Date;
  lottery: { id: string; name: string | null; code: string | null };
}

/** Parsea fecha YYYY-MM-DD a Date a medianoche UTC (evita desfases con Postgres Date). */
function parseDrawDate(dateStr: string): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateStr);
  if (!match) {
    throw new BadRequestException('Formato de fecha inválido. Use YYYY-MM-DD.');
  }
  const year = parseInt(match[1], 10);
  const month = parseInt(match[2], 10) - 1;
  const day = parseInt(match[3], 10);
  const date = new Date(Date.UTC(year, month, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month || date.getUTCDate() !== day) {
    throw new BadRequestException('Fecha inválida.');
  }
  return date;
}

/** Resultado crudo de listar sorteos (cuando draw_time en DB es TIME y Prisma falla). */
interface RawDrawRow {
  id: string;
  lotteryId: string;
  drawDate: Date;
  drawTime: string;
  state: string;
  createdAt: Date;
  updatedAt: Date;
  lottery_id: string;
  lottery_name: string | null;
  lottery_code: string | null;
}

@Injectable()
export class DrawsService {
  constructor(private prisma: PrismaService) {}

  async findByDateAndLottery(dateStr: string, lotteryId?: string): Promise<DrawWithDisplayStatus[]> {
    const date = parseDrawDate(dateStr);
    // Auto-generar sorteos del día al primer acceso: si es hoy y aún no existen, se crean.
    if (dateStr === serverTodayISO()) {
      const existingCount = await this.prisma.draw.count({ where: { drawDate: date } });
      if (existingCount === 0) {
        await this.generateForDate(dateStr);
      }
    }
    let list: DrawRow[];
    try {
      const where: Prisma.DrawWhereInput = { drawDate: date };
      if (lotteryId) where.lotteryId = lotteryId;
      list = await this.prisma.draw.findMany({
        where,
        include: { lottery: { select: { id: true, name: true, code: true } } },
        orderBy: [{ lotteryId: 'asc' }, { drawTime: 'asc' }],
      }) as unknown as DrawRow[];
    } catch (err) {
      try {
        list = await this.findByDateAndLotteryRaw(dateStr, date, lotteryId);
      } catch (rawErr) {
        throw err;
      }
    }
    await this.closeExpiredDraws(list);
    return this.enrichDrawsWithDisplayStatus(list);
  }

  /** Pasa el estado a 'closed' en BD cuando ya pasó la hora de cierre. No requiere que nadie cierre manualmente. */
  private async closeExpiredDraws(list: DrawRow[]): Promise<void> {
    const toCheck = list.filter((d) => d.state === 'open' || d.state === 'scheduled');
    if (toCheck.length === 0) return;
    const lotteryIds = [...new Set(toCheck.map((d) => d.lotteryId))];
    const lotteriesWithTimes = await this.prisma.lottery.findMany({
      where: { id: { in: lotteryIds } },
      include: { drawTimes: { where: { active: true } } },
    });
    const now = serverNow();
    for (const d of toCheck) {
      const lot = lotteriesWithTimes.find((l) => l.id === d.lotteryId);
      const closeMinutesBefore =
        lot?.drawTimes.find((dt) => dt.drawTime === d.drawTime || dt.drawTime?.slice(0, 8) === d.drawTime?.slice(0, 8))
          ?.closeMinutesBefore ?? 0;
      const closeAt = getDrawCloseAt(d.drawDate, d.drawTime, closeMinutesBefore);
      if (now >= closeAt) {
        await this.prisma.draw.update({
          where: { id: d.id },
          data: { state: DrawState.closed },
        });
        (d as { state: string }).state = 'closed';
      }
    }
  }

  private async enrichDrawsWithDisplayStatus(list: DrawRow[]): Promise<DrawWithDisplayStatus[]> {
    if (list.length === 0) return [];
    const lotteryIds = [...new Set(list.map((d) => d.lotteryId))];
    const lotteriesWithTimes = await this.prisma.lottery.findMany({
      where: { id: { in: lotteryIds } },
      include: { drawTimes: { where: { active: true } } },
    });
    const now = serverNow();
    const closingSoonMs = CLOSING_SOON_MINUTES * 60 * 1000;

    return list.map((d) => {
      const lot = lotteriesWithTimes.find((l) => l.id === d.lotteryId);
      const closeMinutesBefore =
        lot?.drawTimes.find((dt) => dt.drawTime === d.drawTime || dt.drawTime?.slice(0, 8) === d.drawTime?.slice(0, 8))
          ?.closeMinutesBefore ?? 0;
      const closeAt = getDrawCloseAt(d.drawDate, d.drawTime, closeMinutesBefore);
      const drawAt = new Date(closeAt.getTime() + closeMinutesBefore * 60 * 1000);
      let displayStatus: DrawDisplayStatus = 'scheduled';
      if (d.state === 'closed' || d.state === 'posteado') {
        displayStatus = 'closed';
      } else if (now >= drawAt) {
        displayStatus = 'closed';
      } else if (d.state === 'open') {
        if (now >= closeAt) displayStatus = 'closed';
        else if (now.getTime() >= closeAt.getTime() - closingSoonMs) displayStatus = 'closing_soon';
        else displayStatus = 'open';
      }
      return {
        ...d,
        displayStatus,
        closeAt: closeAt.toISOString(),
      };
    });
  }

  private async findByDateAndLotteryRaw(dateStr: string, date: Date, lotteryId?: string): Promise<DrawRow[]> {
    const lotteryFilter = lotteryId ? Prisma.sql`AND d.lottery_id = ${lotteryId}::uuid` : Prisma.empty;
    const rows = await this.prisma.$queryRaw<RawDrawRow[]>`
      SELECT d.id, d.lottery_id AS "lotteryId", d.draw_date AS "drawDate",
             to_char(d.draw_time, 'HH24:MI:SS') AS "drawTime",
             d.state::text AS state, d.created_at AS "createdAt", d.updated_at AS "updatedAt",
             l.id AS lottery_id, l.name AS lottery_name, l.code AS lottery_code
      FROM draws d
      JOIN lotteries l ON l.id = d.lottery_id
      WHERE d.draw_date = ${dateStr}::date ${lotteryFilter}
      ORDER BY d.lottery_id, d.draw_time
    `;
    return rows.map((r) => ({
      id: r.id,
      lotteryId: r.lotteryId,
      drawDate: r.drawDate,
      drawTime: r.drawTime,
      state: r.state,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      lottery: { id: r.lottery_id, name: r.lottery_name, code: r.lottery_code },
    }));
  }

  async generateForDate(dateStr: string) {
    const date = parseDrawDate(dateStr);
    const lotteries = await this.prisma.lottery.findMany({
      where: { active: true },
      include: { drawTimes: { where: { active: true } } },
    });
    const created: { id: string }[] = [];
    for (const lot of lotteries) {
      for (const dt of lot.drawTimes) {
        const existing = await this.prisma.draw.findFirst({
          where: { lotteryId: lot.id, drawDate: date, drawTime: dt.drawTime },
        });
        if (!existing) {
          const draw = await this.prisma.draw.create({
            data: {
              lotteryId: lot.id,
              drawDate: date,
              drawTime: dt.drawTime,
              state: DrawState.scheduled,
            },
          });
          created.push({ id: draw.id });
        }
      }
    }
    return { created, date: dateStr };
  }

  async findOne(id: string) {
    const draw = await this.prisma.draw.findUnique({
      where: { id },
      include: { lottery: true, drawResult: true },
    });
    if (!draw) throw new NotFoundException('Draw not found');
    return draw;
  }

  async updateState(id: string, state: DrawState) {
    await this.findOne(id);
    return this.prisma.draw.update({
      where: { id },
      data: { state },
      include: { lottery: true },
    });
  }
}
