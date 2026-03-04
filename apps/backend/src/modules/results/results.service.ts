import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { ResultStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { serverNow } from '../../common/server-time';
import { validateAndNormalizeOne } from '../../common/number-rules';
import { getDrawCloseAndDrawAt } from '../tickets/draw-schedule.helper';

@Injectable()
export class ResultsService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
  ) {}

  async enter(drawId: string, results: Record<string, unknown>, userId: string) {
    const draw = await this.prisma.draw.findUnique({ where: { id: drawId } });
    if (!draw) throw new NotFoundException('Draw not found');
    if (draw.state !== 'closed') {
      throw new BadRequestException(
        'Solo se pueden ingresar resultados cuando el sorteo está cerrado (no se aceptan más jugadas). Cambie el estado del sorteo a "cerrado" en Sorteos.',
      );
    }
    const timezone = process.env.BANCO_TIMEZONE ?? 'America/Santo_Domingo';
    const { drawAt } = await getDrawCloseAndDrawAt(this.prisma, drawId, timezone);
    const now = serverNow();
    if (now < drawAt) {
      throw new BadRequestException(
        'No se pueden ingresar resultados antes de la hora del sorteo. La validación usa la hora del servidor para evitar fraude.',
      );
    }
    const existing = await this.prisma.drawResult.findUnique({ where: { drawId } });
    const normalized: Record<string, string> = {};
    for (const key of ['primera', 'segunda', 'tercera']) {
      const v = results[key];
      if (v !== undefined && v !== null && String(v).trim() !== '') {
        try {
          normalized[key] = validateAndNormalizeOne(String(v));
        } catch (e) {
          throw new BadRequestException(e instanceof Error ? e.message : 'Número inválido.');
        }
      }
    }
    const resultsToSave = { ...(results as Record<string, unknown>), ...normalized };
    const data = {
      drawId,
      status: ResultStatus.pending_approval,
      results: resultsToSave as object,
      enteredById: userId,
      enteredAt: serverNow(),
      rejectionReason: null,
    };
    if (existing) {
      if (existing.status === ResultStatus.approved) throw new BadRequestException('Results already approved');
      await this.prisma.drawResult.update({
        where: { drawId },
        data: { ...data, approvedById: null, approvedAt: null },
      });
    } else {
      await this.prisma.drawResult.create({ data: { ...data } as never });
    }
    await this.audit.log({ action: 'RESULT_ENTER', entity: 'draw_result', entityId: drawId, actorUserId: userId, meta: { drawId } });
    return this.prisma.drawResult.findUniqueOrThrow({ where: { drawId }, include: { draw: true } });
  }

  async approve(drawId: string, userId: string) {
    const dr = await this.prisma.drawResult.findUnique({ where: { drawId } });
    if (!dr) throw new NotFoundException('Draw result not found');
    if (dr.status !== ResultStatus.pending_approval) throw new BadRequestException('Result is not pending approval');
    await this.prisma.$transaction([
      this.prisma.drawResult.update({
        where: { drawId },
        data: { status: ResultStatus.approved, approvedById: userId, approvedAt: new Date() },
      }),
      this.prisma.draw.update({
        where: { id: drawId },
        data: { state: 'posteado' as const },
      }),
    ]);
    await this.audit.log({ action: 'RESULT_APPROVE', entity: 'draw_result', entityId: drawId, actorUserId: userId, meta: { drawId } });
    return this.prisma.drawResult.findUniqueOrThrow({ where: { drawId }, include: { draw: true } });
  }

  async reject(drawId: string, userId: string, reason?: string) {
    const dr = await this.prisma.drawResult.findUnique({ where: { drawId } });
    if (!dr) throw new NotFoundException('Draw result not found');
    if (dr.status !== ResultStatus.pending_approval) throw new BadRequestException('Result is not pending approval');
    await this.prisma.drawResult.update({
      where: { drawId },
      data: { status: ResultStatus.rejected, rejectionReason: reason ?? null },
    });
    await this.audit.log({ action: 'RESULT_REJECT', entity: 'draw_result', entityId: drawId, actorUserId: userId, meta: { drawId, reason } });
    return this.prisma.drawResult.findUniqueOrThrow({ where: { drawId }, include: { draw: true } });
  }

  async getByDraw(drawId: string) {
    return this.prisma.drawResult.findUnique({
      where: { drawId },
      include: { draw: true, enteredBy: { select: { id: true, fullName: true } }, approvedBy: { select: { id: true, fullName: true } } },
    });
  }

  async listPending() {
    return this.prisma.drawResult.findMany({
      where: { status: ResultStatus.pending_approval },
      include: { draw: { include: { lottery: true } } },
      orderBy: { enteredAt: 'asc' },
    });
  }
}
