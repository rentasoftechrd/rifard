import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { BetType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { PayoutsService } from '../payouts/payouts.service';
import { validateAndNormalizeNumbers } from '../../common/number-rules';
import { getDrawCloseAndDrawAt, canVoid } from './draw-schedule.helper';
import { formatTicketDateAndTime, getTicketQrUrl } from './ticket-display.helper';
import { calculatePotentialPayout } from './payout.helper';
import { isLineWinner, DrawResultsApproved } from './winning.helper';
import { CreateTicketDto, VoidTicketDto } from './dto';
import { TicketNumberService } from './ticket-number.service';

@Injectable()
export class TicketsService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
    private payouts: PayoutsService,
    private ticketNumber: TicketNumberService,
  ) {}

  async create(dto: CreateTicketDto, userId: string) {
    try {
      return await this.createTicket(dto, userId);
    } catch (err: unknown) {
      if (err instanceof BadRequestException || err instanceof NotFoundException) {
        throw err;
      }
      const message = err instanceof Error ? err.message : 'Error al crear el ticket';
      throw new BadRequestException({ message, detail: String(err) });
    }
  }

  private async createTicket(dto: CreateTicketDto, userId: string) {
    const timezone = process.env.BANCO_TIMEZONE ?? 'America/Santo_Domingo';
    const multipliers = await this.payouts.getMultipliers();
    const linesWithPayout = dto.lines.map((line) => {
      // Normalizar formato de números desde el POS:
      // la app puede enviar \"02-14\" o \"02 14\"; aquí convertimos todos los guiones en espacios
      // para que validateAndNormalizeNumbers siempre reciba \"02 14\" / \"09 58 00\", etc.
      let numbers = (line.numbers ?? '').trim();
      if (numbers.includes('-')) {
        numbers = numbers.replace(/-/g, ' ').replace(/\s+/g, ' ').trim();
      }
      try {
        numbers = validateAndNormalizeNumbers(numbers, line.betType as string);
      } catch (err) {
        throw new BadRequestException(err instanceof Error ? err.message : 'Números inválidos.');
      }
      return {
        ...line,
        numbers,
        potentialPayout:
          line.potentialPayout ?? calculatePotentialPayout(line.betType as BetType, Number(line.amount), multipliers),
      };
    });
    const totalAmount = linesWithPayout.reduce((s, l) => s + Number(l.amount), 0);

    const ticket = await this.prisma.$transaction(
      async (tx) => {
        const drawIds = [...new Set(linesWithPayout.map((l) => l.drawId))];
        const limits = await tx.limitConfig.findMany({
          where: { active: true, drawId: { in: drawIds } },
        });
        for (const drawId of drawIds) {
          const drawLines = linesWithPayout.filter((l) => l.drawId === drawId);
          const existingExposure = await tx.ticketLine.aggregate({
            where: {
              drawId,
              ticket: { status: { not: 'voided' } },
            },
            _sum: { potentialPayout: true },
          });
          let globalExposure = Number(existingExposure._sum.potentialPayout ?? 0);
          const byNumberExposure = new Map<string, number>();
          const byBetTypeExposure = new Map<string, number>();

          const activeLines = await tx.ticketLine.findMany({
            where: { drawId, ticket: { status: { not: 'voided' } } },
            select: { betType: true, numbers: true, potentialPayout: true },
          });
          for (const l of activeLines) {
            globalExposure += Number(l.potentialPayout);
            const key = l.numbers.trim();
            byNumberExposure.set(key, (byNumberExposure.get(key) ?? 0) + Number(l.potentialPayout));
            byBetTypeExposure.set(l.betType, (byBetTypeExposure.get(l.betType) ?? 0) + Number(l.potentialPayout));
          }

          for (const line of drawLines) {
            const payout = Number(line.potentialPayout ?? 0);
            globalExposure += payout;
            const numKey = (line.numbers ?? '').trim();
            byNumberExposure.set(numKey, (byNumberExposure.get(numKey) ?? 0) + payout);
            byBetTypeExposure.set(line.betType, (byBetTypeExposure.get(line.betType) ?? 0) + payout);
          }

          for (const lim of limits.filter((l) => l.drawId === drawId)) {
            if (lim.type === 'global') {
              if (lim.maxPayout != null && globalExposure > Number(lim.maxPayout)) {
                throw new BadRequestException({ code: 'LIMIT_REJECT', message: 'Global limit exceeded for this draw' });
              }
            }
            if (lim.type === 'by_number' && lim.numberKey) {
              const exp = byNumberExposure.get(lim.numberKey) ?? 0;
              if (lim.maxPayout != null && exp > Number(lim.maxPayout)) {
                throw new BadRequestException({ code: 'LIMIT_REJECT', message: `Limit exceeded for number ${lim.numberKey}` });
              }
            }
            if (lim.type === 'by_bet_type' && lim.betType) {
              const exp = byBetTypeExposure.get(lim.betType) ?? 0;
              if (lim.maxPayout != null && exp > Number(lim.maxPayout)) {
                throw new BadRequestException({ code: 'LIMIT_REJECT', message: `Limit exceeded for bet type ${lim.betType}` });
              }
            }
          }
        }

        const ticketNumber = await this.ticketNumber.getNextTicketNumber(tx);
        const ticket = await tx.ticket.create({
          data: {
            ticketCode: ticketNumber,
            ticketNumber,
            pointId: dto.pointId,
            deviceId: dto.deviceId,
            sellerUserId: userId,
            totalAmount,
            status: 'sold',
          },
          include: { lines: true },
        });
        await tx.ticketLine.createMany({
          data: linesWithPayout.map((line) => ({
            ticketId: ticket.id,
            lotteryId: line.lotteryId,
            drawId: line.drawId,
            betType: line.betType as BetType,
            numbers: line.numbers,
            amount: line.amount,
            potentialPayout: line.potentialPayout,
          })),
        });
        return tx.ticket.findUniqueOrThrow({
          where: { id: ticket.id },
          include: { lines: true, point: true },
        });
      },
      { isolationLevel: 'Serializable' },
    );

    await this.audit.log({
      action: 'TICKET_CREATE',
      entity: 'ticket',
      entityId: ticket.id,
      actorUserId: userId,
      meta: { ticketCode: ticket.ticketCode, totalAmount: String(ticket.totalAmount) },
    });
    return ticket;
  }

  async print(id: string) {
    const ticket = await this.prisma.ticket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.printedAt) return this.getByCode(ticket.ticketCode);
    await this.prisma.ticket.update({
      where: { id },
      data: { printedAt: new Date() },
    });
    return this.getByCode(ticket.ticketCode);
  }

  async void(id: string, dto: VoidTicketDto, userId: string) {
    const ticket = await this.prisma.ticket.findUnique({
      where: { id },
      include: { lines: { take: 1 } },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.status === 'voided') throw new BadRequestException({ code: 'ALREADY_VOIDED', message: 'Ticket already voided' });
    if (!ticket.printedAt) throw new BadRequestException({ code: 'TICKET_NOT_PRINTED', message: 'Ticket was not printed' });

    const timezone = process.env.BANCO_TIMEZONE ?? 'America/Santo_Domingo';
    const drawId = ticket.lines[0]?.drawId;
    if (!drawId) throw new BadRequestException('Ticket has no lines');
    const { drawCloseAt, drawAt } = await getDrawCloseAndDrawAt(this.prisma, drawId, timezone);
    const now = new Date();
    const check = canVoid(ticket.createdAt, ticket.printedAt, now, drawCloseAt, drawAt);
    if (!check.ok) throw new BadRequestException({ code: check.code, message: check.code });

    await this.prisma.ticket.update({
      where: { id },
      data: {
        status: 'voided',
        voidedAt: now,
        voidedById: userId,
        voidReason: dto.reason ?? null,
      },
    });
    await this.audit.log({
      action: 'TICKET_VOID',
      entity: 'ticket',
      entityId: id,
      actorUserId: userId,
      meta: { ticketCode: ticket.ticketCode, reason: dto.reason },
    });
    return this.getByCode(ticket.ticketCode);
  }

  /** Enrich ticket with display date/time (America/Santo_Domingo) and qrValue for printing */
  private enrichTicketForDisplay<T extends { createdAt: Date; ticketNumber: string | null; ticketCode: string }>(ticket: T): T & { date: string; time: string; qrValue: string } {
    const { date, time } = formatTicketDateAndTime(ticket.createdAt);
    const number = ticket.ticketNumber ?? ticket.ticketCode;
    return {
      ...ticket,
      date,
      time,
      qrValue: getTicketQrUrl(number),
    };
  }

  async getByCode(code: string) {
    const codeTrimmed = code.trim();
    const ticket = await this.prisma.ticket.findFirst({
      where: {
        OR: [{ ticketCode: codeTrimmed }, { ticketNumber: codeTrimmed }],
      },
      include: {
        lines: { include: { lottery: true, draw: true } },
        point: true,
        seller: { select: { id: true, fullName: true } },
      },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    return this.enrichTicketForDisplay(ticket);
  }

  async getByTicketNumber(ticketNumber: string) {
    const ticket = await this.prisma.ticket.findUnique({
      where: { ticketNumber: ticketNumber.trim() },
      include: {
        lines: { include: { lottery: true, draw: true } },
        point: true,
        seller: { select: { id: true, fullName: true } },
      },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    return this.enrichTicketForDisplay(ticket);
  }

  /**
   * Public validation for QR scan: returns minimal data for ticket verification page.
   * Does not throw; returns valid: false when not found.
   */
  async getPublicValidation(ticketNumber: string): Promise<{
    valid: boolean;
    ticketNumber?: string;
    status?: string;
    totalAmount?: string;
    message?: string;
  }> {
    const ticket = await this.prisma.ticket.findUnique({
      where: { ticketNumber: ticketNumber.trim() },
      select: { ticketNumber: true, status: true, totalAmount: true },
    });
    if (!ticket) {
      return { valid: false, message: 'Ticket no encontrado' };
    }
    return {
      valid: true,
      ticketNumber: ticket.ticketNumber ?? undefined,
      status: ticket.status,
      totalAmount: String(ticket.totalAmount),
      message: ticket.status === 'voided' ? 'Ticket anulado' : ticket.status === 'paid' ? 'Ticket ya cobrado' : undefined,
    };
  }

  /**
   * Buscar ticket por código para cobro de premio: incluye si cada línea gana y el monto a pagar.
   * Si el ticket ya está pagado, se indica para evitar doble cobro en otro punto.
   */
  async getByCodeForPayment(code: string) {
    const codeTrimmed = code.trim();
    const ticket = await this.prisma.ticket.findFirst({
      where: {
        OR: [{ ticketCode: codeTrimmed }, { ticketNumber: codeTrimmed }],
      },
      include: {
        lines: { include: { lottery: true, draw: true } },
        point: true,
        seller: { select: { id: true, fullName: true } },
        paidBy: { select: { id: true, fullName: true } },
      },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.status === 'voided') {
      return { ticket, linesWithWinning: [], totalWinningAmount: 0, canBePaid: false, message: 'Ticket anulado.' };
    }

    const drawIds = [...new Set(ticket.lines.map((l) => l.drawId))];
    const approvedResults = await this.prisma.drawResult.findMany({
      where: { drawId: { in: drawIds }, status: 'approved' },
    });
    const resultsByDraw = new Map<string | null, DrawResultsApproved>();
    for (const dr of approvedResults) {
      const r = dr.results as Record<string, string> | null;
      if (r) {
        resultsByDraw.set(dr.drawId, {
          primera: r.primera ?? '',
          segunda: r.segunda ?? '',
          tercera: r.tercera ?? '',
        });
      }
    }

    const linesWithWinning = ticket.lines.map((line) => {
      const results = resultsByDraw.get(line.drawId);
      const isWinner = results
        ? isLineWinner(line.betType, line.numbers, results)
        : false;
      const winningPayout = isWinner ? Number(line.potentialPayout) : 0;
      return {
        ...line,
        isWinner,
        winningPayout,
      };
    });
    const totalWinningAmount = linesWithWinning.reduce((s, l) => s + (l.winningPayout ?? 0), 0);
    const canBePaid = ticket.status === 'sold' && totalWinningAmount > 0;

    return {
      ticket: {
        id: ticket.id,
        ticketCode: ticket.ticketCode,
        ticketNumber: ticket.ticketNumber,
        status: ticket.status,
        totalAmount: ticket.totalAmount,
        printedAt: ticket.printedAt,
        paidAt: ticket.paidAt,
        paidBy: ticket.paidBy,
        point: ticket.point,
        seller: ticket.seller,
        createdAt: ticket.createdAt,
      },
      linesWithWinning,
      totalWinningAmount,
      canBePaid,
      message: ticket.status === 'paid' ? 'Este ticket ya fue pagado.' : undefined,
    };
  }

  /**
   * Lista tickets ganadores para una fecha. Usa vista v_winning_ticket_lines si existe; si no, lógica Prisma.
   */
  async getWinningTickets(date: string, lotteryId?: string) {
    const dateNorm = date?.trim();
    if (!dateNorm || !/^\d{4}-\d{2}-\d{2}$/.test(dateNorm)) return [];

    try {
      const rows = await this.prisma.$queryRaw<Array<Record<string, unknown>>>(
        lotteryId
          ? Prisma.sql`SELECT * FROM v_winning_ticket_lines WHERE draw_date = ${dateNorm}::date AND lottery_id = ${lotteryId}::uuid`
          : Prisma.sql`SELECT * FROM v_winning_ticket_lines WHERE draw_date = ${dateNorm}::date`,
      );
      return this.buildWinningTicketsOutput(rows, lotteryId, false);
    } catch {
      return this.getWinningTicketsLegacy(dateNorm, lotteryId);
    }
  }

  /**
   * Lista tickets ganadores en un rango de fechas (historial). Usa vista si existe; si no, lógica Prisma.
   */
  async getWinningTicketsHistory(from: string, to: string) {
    const fromNorm = from?.trim();
    const toNorm = to?.trim();
    if (!fromNorm || !toNorm || !/^\d{4}-\d{2}-\d{2}$/.test(fromNorm) || !/^\d{4}-\d{2}-\d{2}$/.test(toNorm)) return [];

    try {
      const rows = await this.prisma.$queryRaw<Array<Record<string, unknown>>>(
        Prisma.sql`SELECT * FROM v_winning_ticket_lines WHERE draw_date >= ${fromNorm}::date AND draw_date <= ${toNorm}::date`,
      );
      return this.buildWinningTicketsOutput(rows, undefined, true);
    } catch {
      return this.getWinningTicketsHistoryLegacy(fromNorm, toNorm);
    }
  }

  /** Fallback sin vista: lista ganadores por fecha. Usa comparación DATE en SQL para evitar timezone. */
  private async getWinningTicketsLegacy(date: string, lotteryId?: string) {
    let drawIds: string[];
    try {
      const rows = await this.prisma.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT d.id FROM draws d INNER JOIN draw_results dr ON dr.draw_id = d.id AND dr.status = 'approved' WHERE d.draw_date = ${date}::date`,
      );
      drawIds = rows.map((r) => r.id);
    } catch {
      return [];
    }
    if (drawIds.length === 0) return [];
    const ticketIds = await this.prisma.ticketLine.findMany({
      where: { drawId: { in: drawIds }, ticket: { status: { not: 'voided' } } },
      select: { ticketId: true },
      distinct: ['ticketId'],
    }).then((r) => [...new Set(r.map((x) => x.ticketId))]);
    if (ticketIds.length === 0) return [];
    const resultsByDraw = await this.prisma.drawResult.findMany({ where: { drawId: { in: drawIds }, status: 'approved' } }).then((list) => {
      const map = new Map<string, DrawResultsApproved>();
      for (const dr of list) {
        const r = (dr.results as Record<string, string>) ?? {};
        map.set(dr.drawId, { primera: r.primera ?? '', segunda: r.segunda ?? '', tercera: r.tercera ?? '' });
      }
      return map;
    });
    const tickets = await this.prisma.ticket.findMany({
      where: { id: { in: ticketIds } },
      include: { lines: { include: { lottery: true, draw: true } }, point: true, seller: { select: { id: true, fullName: true } }, paidBy: { select: { id: true, fullName: true } } },
    });
    const out: Array<{ ticket: Record<string, unknown>; linesWithWinning: Array<Record<string, unknown>>; totalWinningAmount: number; canBePaid: boolean; lotteryName: string; drawTime: string }> = [];
    for (const ticket of tickets) {
      const linesWithWinning = ticket.lines.map((line) => {
        const res = resultsByDraw.get(line.drawId);
        const isWinner = res ? isLineWinner(line.betType, line.numbers, res) : false;
        return { ...line, isWinner, winningPayout: isWinner ? Number(line.potentialPayout) : 0 };
      });
      const total = linesWithWinning.reduce((s, l) => s + (l.winningPayout ?? 0), 0);
      if (total <= 0) continue;
      if (lotteryId && !ticket.lines.some((l) => l.lotteryId === lotteryId)) continue;
      const first = ticket.lines[0];
      out.push({
        ticket: { id: ticket.id, ticketCode: ticket.ticketCode, ticketNumber: ticket.ticketNumber, status: ticket.status, totalAmount: ticket.totalAmount, printedAt: ticket.printedAt, paidAt: ticket.paidAt, paidBy: ticket.paidBy, point: ticket.point, seller: ticket.seller, createdAt: ticket.createdAt },
        linesWithWinning,
        totalWinningAmount: total,
        canBePaid: ticket.status === 'sold' && total > 0,
        lotteryName: first?.lottery?.name ?? '—',
        drawTime: first?.draw?.drawTime ?? '—',
      });
    }
    out.sort((a, b) => (a.lotteryName ?? '').localeCompare(b.lotteryName ?? '') || (a.drawTime ?? '').localeCompare(b.drawTime ?? '') || ((a.ticket.createdAt as Date)?.getTime?.() ?? 0) - ((b.ticket.createdAt as Date)?.getTime?.() ?? 0));
    return out;
  }

  /** Fallback sin vista: historial de ganadores. Comparación DATE en SQL. */
  private async getWinningTicketsHistoryLegacy(from: string, to: string) {
    let drawIds: string[];
    try {
      const rows = await this.prisma.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT d.id FROM draws d INNER JOIN draw_results dr ON dr.draw_id = d.id AND dr.status = 'approved' WHERE d.draw_date >= ${from}::date AND d.draw_date <= ${to}::date`,
      );
      drawIds = rows.map((r) => r.id);
    } catch {
      return [];
    }
    if (drawIds.length === 0) return [];
    const ticketIds = await this.prisma.ticketLine.findMany({
      where: { drawId: { in: drawIds }, ticket: { status: { not: 'voided' } } },
      select: { ticketId: true },
      distinct: ['ticketId'],
    }).then((r) => [...new Set(r.map((x) => x.ticketId))]);
    if (ticketIds.length === 0) return [];
    const resultsByDraw = await this.prisma.drawResult.findMany({ where: { drawId: { in: drawIds }, status: 'approved' } }).then((list) => {
      const map = new Map<string, DrawResultsApproved>();
      for (const dr of list) {
        const r = (dr.results as Record<string, string>) ?? {};
        map.set(dr.drawId, { primera: r.primera ?? '', segunda: r.segunda ?? '', tercera: r.tercera ?? '' });
      }
      return map;
    });
    const tickets = await this.prisma.ticket.findMany({
      where: { id: { in: ticketIds } },
      include: { lines: { include: { lottery: true, draw: true } }, point: true, seller: { select: { id: true, fullName: true } }, paidBy: { select: { id: true, fullName: true } } },
    });
    const out: Array<{ ticket: Record<string, unknown>; linesWithWinning: Array<Record<string, unknown>>; totalWinningAmount: number; canBePaid: boolean; lotteryName: string; drawTime: string; drawDate: string }> = [];
    for (const ticket of tickets) {
      const linesWithWinning = ticket.lines.map((line) => {
        const res = resultsByDraw.get(line.drawId);
        const isWinner = res ? isLineWinner(line.betType, line.numbers, res) : false;
        return { ...line, isWinner, winningPayout: isWinner ? Number(line.potentialPayout) : 0 };
      });
      const total = linesWithWinning.reduce((s, l) => s + (l.winningPayout ?? 0), 0);
      if (total <= 0) continue;
      const first = ticket.lines[0];
      const drawDate = first?.draw?.drawDate ? new Date(first.draw.drawDate).toISOString().slice(0, 10) : '—';
      out.push({
        ticket: { id: ticket.id, ticketCode: ticket.ticketCode, ticketNumber: ticket.ticketNumber, status: ticket.status, totalAmount: ticket.totalAmount, printedAt: ticket.printedAt, paidAt: ticket.paidAt, paidBy: ticket.paidBy, point: ticket.point, seller: ticket.seller, createdAt: ticket.createdAt },
        linesWithWinning,
        totalWinningAmount: total,
        canBePaid: ticket.status === 'sold' && total > 0,
        lotteryName: first?.lottery?.name ?? '—',
        drawTime: first?.draw?.drawTime ?? '—',
        drawDate,
      });
    }
    out.sort((a, b) => (b.drawDate ?? '').localeCompare(a.drawDate ?? '') || (a.lotteryName ?? '').localeCompare(b.lotteryName ?? '') || ((b.ticket.createdAt as Date)?.getTime?.() ?? 0) - ((a.ticket.createdAt as Date)?.getTime?.() ?? 0));
    return out;
  }

  /**
   * Agrupa filas de v_winning_ticket_lines por ticket, calcula isWinner por línea y montos, y arma la respuesta.
   */
  private async buildWinningTicketsOutput(
    viewRows: Array<Record<string, unknown>>,
    filterLotteryId?: string,
    includeDrawDate = false,
  ) {
    const byTicket = new Map<string, Array<Record<string, unknown>>>();
    for (const row of viewRows) {
      const ticketId = row.ticket_id as string;
      if (!ticketId) continue;
      let arr = byTicket.get(ticketId);
      if (!arr) {
        arr = [];
        byTicket.set(ticketId, arr);
      }
      arr.push(row);
    }

    const candidates: Array<{ ticketId: string; linesWithWinning: Array<Record<string, unknown>>; totalWinningAmount: number; lotteryName: string; drawTime: string; drawDate?: string }> = [];

    for (const [ticketId, rows] of byTicket) {
      const linesWithWinning: Array<Record<string, unknown>> = [];
      let totalWinningAmount = 0;
      let lotteryName = '—';
      let drawTime = '—';
      let drawDate: string | undefined;

      for (const r of rows) {
        const betType = (r.bet_type as BetType) ?? 'quiniela';
        const numbers = (r.numbers as string) ?? '';
        const resForDraw: DrawResultsApproved = {
          primera: (r.result_primera as string) ?? '',
          segunda: (r.result_segunda as string) ?? '',
          tercera: (r.result_tercera as string) ?? '',
        };
        const isWinner = isLineWinner(betType, numbers, resForDraw);
        const potentialPayout = Number(r.potential_payout) ?? 0;
        const winningPayout = isWinner ? potentialPayout : 0;
        totalWinningAmount += winningPayout;
        if (r.lottery_name != null) lotteryName = String(r.lottery_name);
        if (r.draw_time != null) drawTime = String(r.draw_time);
        if (includeDrawDate && r.draw_date != null) drawDate = new Date(r.draw_date as Date).toISOString().slice(0, 10);
        linesWithWinning.push({
          id: r.line_id,
          drawId: r.draw_id,
          lotteryId: r.lottery_id,
          betType,
          numbers,
          amount: r.amount,
          potentialPayout: r.potential_payout,
          lottery: { name: r.lottery_name },
          draw: { drawTime: r.draw_time, drawDate: r.draw_date },
          isWinner,
          winningPayout,
        });
      }

      if (totalWinningAmount <= 0) continue;
      if (filterLotteryId && !rows.some((r) => r.lottery_id === filterLotteryId)) continue;

      candidates.push({
        ticketId,
        linesWithWinning,
        totalWinningAmount,
        lotteryName,
        drawTime,
        drawDate,
      });
    }

    const ticketIds = [...candidates.map((c) => c.ticketId)];
    if (ticketIds.length === 0) return [];

    const tickets = await this.prisma.ticket.findMany({
      where: { id: { in: ticketIds } },
      include: {
        point: true,
        seller: { select: { id: true, fullName: true } },
        paidBy: { select: { id: true, fullName: true } },
      },
    });
    const ticketMap = new Map(tickets.map((t) => [t.id, t]));

    const out: Array<{
      ticket: Record<string, unknown>;
      linesWithWinning: Array<Record<string, unknown>>;
      totalWinningAmount: number;
      canBePaid: boolean;
      lotteryName: string;
      drawTime: string;
      drawDate?: string;
    }> = [];

    for (const c of candidates) {
      const ticket = ticketMap.get(c.ticketId);
      if (!ticket) continue;
      out.push({
        ticket: {
          id: ticket.id,
          ticketCode: ticket.ticketCode,
          ticketNumber: ticket.ticketNumber,
          status: ticket.status,
          totalAmount: ticket.totalAmount,
          printedAt: ticket.printedAt,
          paidAt: ticket.paidAt,
          paidBy: ticket.paidBy,
          point: ticket.point,
          seller: ticket.seller,
          createdAt: ticket.createdAt,
        },
        linesWithWinning: c.linesWithWinning,
        totalWinningAmount: c.totalWinningAmount,
        canBePaid: ticket.status === 'sold' && c.totalWinningAmount > 0,
        lotteryName: c.lotteryName,
        drawTime: c.drawTime,
        ...(includeDrawDate && c.drawDate != null ? { drawDate: c.drawDate } : {}),
      });
    }

    out.sort((a, b) => {
      if (includeDrawDate) {
        const da = (a as { drawDate?: string }).drawDate ?? '';
        const db = (b as { drawDate?: string }).drawDate ?? '';
        const d = da.localeCompare(db);
        if (d !== 0) return -d;
      }
      const c = (a.lotteryName ?? '').localeCompare(b.lotteryName ?? '');
      if (c !== 0) return c;
      const ta = (a.ticket.createdAt as Date)?.getTime?.() ?? 0;
      const tb = (b.ticket.createdAt as Date)?.getTime?.() ?? 0;
      return includeDrawDate ? tb - ta : ta - tb;
    });
    return out;
  }

  /** Marcar ticket como pagado (cobro de premio). Solo si es ganador y no está ya pagado. */
  async markAsPaid(id: string, userId: string) {
    const ticket = await this.prisma.ticket.findUnique({
      where: { id },
      include: { lines: { include: { draw: true } } },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.status === 'paid') {
      throw new BadRequestException('Este ticket ya fue pagado. No se puede cobrar de nuevo.');
    }
    if (ticket.status === 'voided') {
      throw new BadRequestException('Ticket anulado, no se puede pagar.');
    }

    const paymentInfo = await this.getByCodeForPayment(ticket.ticketCode);
    if (!paymentInfo.canBePaid) {
      throw new BadRequestException(
        paymentInfo.totalWinningAmount === 0
          ? 'Este ticket no tiene líneas ganadoras con resultados aprobados.'
          : 'No se puede marcar como pagado.',
      );
    }

    await this.prisma.ticket.update({
      where: { id },
      data: { status: 'paid', paidAt: new Date(), paidById: userId },
    });
    await this.audit.log({
      action: 'TICKET_PAID',
      entity: 'ticket',
      entityId: id,
      actorUserId: userId,
      meta: { ticketCode: ticket.ticketCode, totalWinningAmount: paymentInfo.totalWinningAmount },
    });
    return this.getByCodeForPayment(ticket.ticketCode);
  }
}
