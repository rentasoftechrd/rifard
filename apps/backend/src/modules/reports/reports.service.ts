import { Injectable } from '@nestjs/common';
import { ResultStatus, TicketStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ensureDateNotFuture } from '../../common/server-time';

const POS_ONLINE_SECONDS = 60;

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  /** start (00:00:00) and end (23:59:59.999) in UTC for the given date and range. */
  private getRangeBounds(date: Date, range: 'day' | 'week' | 'month'): { start: Date; end: Date } {
    const start = new Date(date);
    const end = new Date(date);
    if (range === 'day') {
      start.setUTCHours(0, 0, 0, 0);
      end.setUTCHours(23, 59, 59, 999);
      return { start, end };
    }
    if (range === 'week') {
      const day = date.getUTCDay();
      const mondayOffset = day === 0 ? -6 : 1 - day;
      start.setUTCDate(date.getUTCDate() + mondayOffset);
      start.setUTCHours(0, 0, 0, 0);
      end.setUTCHours(23, 59, 59, 999);
      return { start, end };
    }
    if (range === 'month') {
      start.setUTCDate(1);
      start.setUTCHours(0, 0, 0, 0);
      end.setUTCHours(23, 59, 59, 999);
      return { start, end };
    }
    start.setUTCHours(0, 0, 0, 0);
    end.setUTCHours(23, 59, 59, 999);
    return { start, end };
  }

  async dashboardSummary(dateStr: string, range: 'day' | 'week' | 'month' = 'day') {
    const safeDateStr = ensureDateNotFuture(dateStr);
    const date = new Date(safeDateStr + 'T12:00:00.000Z');
    const rangeBounds = this.getRangeBounds(date, range);
    const start = rangeBounds.start;
    const end = rangeBounds.end;

    const [salesAgg, voidsAgg, draws, pendingResults, presenceList, recentResults, todayResults] = await Promise.all([
      this.prisma.ticket.aggregate({
        where: { createdAt: { gte: start, lte: end }, status: TicketStatus.sold },
        _sum: { totalAmount: true },
        _count: true,
      }),
      this.prisma.ticket.aggregate({
        where: { voidedAt: { gte: start, lte: end }, status: TicketStatus.voided },
        _count: true,
        _sum: { totalAmount: true },
      }),
      this.prisma.draw.findMany({
        where: { drawDate: date },
        include: { lottery: { select: { id: true, name: true, code: true } } },
        orderBy: [{ lotteryId: 'asc' }, { drawTime: 'asc' }],
      }),
      this.prisma.drawResult.findMany({
        where: { status: ResultStatus.pending_approval },
        include: { draw: { include: { lottery: { select: { name: true, code: true } } } } },
        orderBy: { enteredAt: 'asc' },
      }),
      this.prisma.posPresence.findMany({
        include: { point: true, seller: { select: { fullName: true } } },
      }),
      this.prisma.drawResult.findMany({
        where: { status: ResultStatus.approved },
        include: { draw: { include: { lottery: { select: { name: true, code: true } } } } },
        orderBy: { approvedAt: 'desc' },
        take: 5,
      }),
      this.prisma.drawResult.findMany({
        where: { draw: { drawDate: date } },
        include: { draw: { include: { lottery: { select: { name: true, code: true } } } } },
        orderBy: { enteredAt: 'asc' },
      }),
    ]);

    const threshold = new Date(Date.now() - POS_ONLINE_SECONDS * 1000);
    const online = presenceList.filter((p) => p.lastSeenAt >= threshold);
    const offline = presenceList.filter((p) => p.lastSeenAt < threshold);

    const drawsWithExposure = await Promise.all(
      draws.map(async (draw) => {
        const lines = await this.prisma.ticketLine.findMany({
          where: { drawId: draw.id, ticket: { status: { not: TicketStatus.voided } } },
        });
        const global = lines.reduce((s, l) => s + Number(l.potentialPayout), 0);
        return { ...draw, exposure: global };
      }),
    );

    return {
      date: safeDateStr,
      range,
      sales: {
        totalAmount: Number(salesAgg._sum?.totalAmount ?? 0),
        ticketCount: salesAgg._count,
      },
      voids: {
        count: voidsAgg._count,
        totalAmount: Number(voidsAgg._sum?.totalAmount ?? 0),
      },
      draws: drawsWithExposure,
      pendingResults: pendingResults.map((r) => ({
        id: r.id,
        drawId: r.drawId,
        lottery: r.draw?.lottery,
        drawTime: r.draw?.drawTime,
        enteredAt: r.enteredAt,
      })),
      pendingResultsCount: pendingResults.length,
      pos: {
        online: online.length,
        offline: offline.length,
        total: presenceList.length,
      },
      recentResults: recentResults.map((r) => ({
        id: r.id,
        drawId: r.drawId,
        lottery: r.draw?.lottery,
        drawTime: r.draw?.drawTime,
        drawDate: r.draw?.drawDate,
        results: r.results,
        approvedAt: r.approvedAt,
      })),
      todayResults: todayResults.map((r) => ({
        id: r.id,
        drawId: r.drawId,
        status: r.status,
        results: r.results,
        enteredAt: r.enteredAt,
        approvedAt: r.approvedAt,
        lottery: r.draw?.lottery,
        drawTime: r.draw?.drawTime,
      })),
    };
  }

  async dailySales(dateStr: string, pointId?: string, sellerId?: string) {
    const safeDateStr = ensureDateNotFuture(dateStr);
    const date = new Date(safeDateStr);
    const start = new Date(date);
    start.setUTCHours(0, 0, 0, 0);
    const end = new Date(date);
    end.setUTCHours(23, 59, 59, 999);
    const where: { createdAt: { gte: Date; lte: Date }; status: TicketStatus; pointId?: string; sellerUserId?: string } = {
      createdAt: { gte: start, lte: end },
      status: TicketStatus.sold,
    };
    if (pointId) where.pointId = pointId;
    if (sellerId) where.sellerUserId = sellerId;
    const [tickets, agg] = await Promise.all([
      this.prisma.ticket.findMany({
        where,
        include: { point: true, seller: { select: { id: true, fullName: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.ticket.aggregate({
        where,
        _sum: { totalAmount: true },
        _count: true,
      }),
    ]);
    return {
      date: safeDateStr,
      totalAmount: agg._sum?.totalAmount ?? 0,
      ticketCount: agg._count,
      tickets,
    };
  }

  async commissions(dateStr: string) {
    const safeDateStr = ensureDateNotFuture(dateStr);
    const date = new Date(safeDateStr);
    const start = new Date(date);
    start.setUTCHours(0, 0, 0, 0);
    const end = new Date(date);
    end.setUTCHours(23, 59, 59, 999);
    const tickets = await this.prisma.ticket.findMany({
      where: { createdAt: { gte: start, lte: end }, status: TicketStatus.sold },
      include: {
        seller: { select: { id: true, fullName: true } },
        point: { select: { id: true, name: true } },
      },
    });
    const assignments = await this.prisma.pointAssignment.findMany({
      where: { active: true },
      include: { user: { select: { id: true, fullName: true } }, point: true },
    });
    const bySeller = new Map<string, { fullName: string; sales: number; commissionPercent: number; commission: number }>();
    for (const t of tickets) {
      const ass = assignments.find((a) => a.sellerUserId === t.sellerUserId && a.pointId === t.pointId);
      const pct = ass ? Number(ass.commissionPercent) : 0;
      const sales = Number(t.totalAmount);
      const commission = (sales * pct) / 100;
      const cur = bySeller.get(t.sellerUserId) ?? { fullName: t.seller?.fullName ?? '', sales: 0, commissionPercent: pct, commission: 0 };
      cur.sales += sales;
      cur.commission += commission;
      bySeller.set(t.sellerUserId, cur);
    }
    return { date: safeDateStr, bySeller: Array.from(bySeller.entries()).map(([id, v]) => ({ sellerId: id, ...v })) };
  }

  async voids(dateStr: string) {
    const safeDateStr = ensureDateNotFuture(dateStr);
    const date = new Date(safeDateStr);
    const start = new Date(date);
    start.setUTCHours(0, 0, 0, 0);
    const end = new Date(date);
    end.setUTCHours(23, 59, 59, 999);
    const tickets = await this.prisma.ticket.findMany({
      where: { voidedAt: { gte: start, lte: end }, status: TicketStatus.voided },
      include: { point: true, voidedBy: { select: { id: true, fullName: true } } },
    });
    const totalVoided = tickets.reduce((s, t) => s + Number(t.totalAmount), 0);
    return { date: safeDateStr, count: tickets.length, totalAmount: totalVoided, tickets };
  }

  async exposure(drawId: string) {
    const lines = await this.prisma.ticketLine.findMany({
      where: { drawId, ticket: { status: { not: TicketStatus.voided } } },
      include: { ticket: true, lottery: true, draw: true },
    });
    const global = lines.reduce((s, l) => s + Number(l.potentialPayout), 0);
    const byNumber = new Map<string, number>();
    const byBetType = new Map<string, number>();
    for (const l of lines) {
      byNumber.set(l.numbers.trim(), (byNumber.get(l.numbers.trim()) ?? 0) + Number(l.potentialPayout));
      byBetType.set(l.betType, (byBetType.get(l.betType) ?? 0) + Number(l.potentialPayout));
    }
    return {
      drawId,
      global,
      byNumber: Object.fromEntries(byNumber),
      byBetType: Object.fromEntries(byBetType),
      lineCount: lines.length,
    };
  }
}
