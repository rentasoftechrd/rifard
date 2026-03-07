import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { BetType } from '@prisma/client';
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
