import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateLotteryDto, UpdateLotteryDto, DrawTimeDto } from './dto';

@Injectable()
export class LotteriesService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateLotteryDto) {
    const existing = await this.prisma.lottery.findUnique({ where: { code: dto.code } });
    if (existing) throw new ConflictException('Lottery code already exists');
    return this.prisma.lottery.create({
      data: { name: dto.name, code: dto.code, active: dto.active ?? true },
    });
  }

  async findAll() {
    return this.prisma.lottery.findMany({
      include: {
        _count: { select: { drawTimes: true } },
        drawTimes: { select: { drawTime: true, active: true }, orderBy: { drawTime: 'asc' } },
      },
      orderBy: { code: 'asc' },
    });
  }

  async findOne(id: string) {
    const lottery = await this.prisma.lottery.findUnique({
      where: { id },
      include: { drawTimes: true },
    });
    if (!lottery) throw new NotFoundException('Lottery not found');
    return lottery;
  }

  async update(id: string, dto: UpdateLotteryDto) {
    await this.findOne(id);
    if (dto.code) {
      const existing = await this.prisma.lottery.findFirst({ where: { code: dto.code, NOT: { id } } });
      if (existing) throw new ConflictException('Lottery code already exists');
    }
    return this.prisma.lottery.update({
      where: { id },
      data: { name: dto.name, code: dto.code, active: dto.active } as never,
    });
  }

  /** Normalize time to HH:mm:00 for DB TIME column consistency */
  private normalizeDrawTime(s: string): string {
    const t = String(s ?? '').trim();
    if (!t) return '00:00:00';
    const parts = t.split(':');
    const h = parts[0]?.padStart(2, '0') ?? '00';
    const m = (parts.length > 1 ? parts[1] : '00').padStart(2, '0');
    const sec = parts.length > 2 ? parts[2] : '00';
    return `${h}:${m}:${sec.padStart(2, '0')}`;
  }

  async setDrawTimes(lotteryId: string, drawTimes: DrawTimeDto[] = []) {
    try {
      await this.findOne(lotteryId);
      const list = Array.isArray(drawTimes) ? drawTimes : [];
      const normalized = list.map((d) => ({
        ...d,
        drawTime: this.normalizeDrawTime(d.drawTime),
      }));
      const existing = await this.prisma.lotteryDrawTime.findMany({ where: { lotteryId } });
      const incomingSet = new Set(normalized.map((d) => d.drawTime));
      for (const e of existing) {
        const existingTime = typeof e.drawTime === 'string' ? e.drawTime : this.normalizeDrawTime(String(e.drawTime));
        if (!incomingSet.has(existingTime)) await this.prisma.lotteryDrawTime.delete({ where: { id: e.id } });
      }
      for (const d of normalized) {
        const closeMinutes = Number(d.closeMinutesBefore) >= 0 ? Number(d.closeMinutesBefore) : 0;
        await this.prisma.lotteryDrawTime.upsert({
          where: {
            lotteryId_drawTime: { lotteryId, drawTime: d.drawTime },
          },
          create: {
            lotteryId,
            drawTime: d.drawTime,
            closeMinutesBefore: closeMinutes,
            active: d.active ?? true,
          },
          update: { closeMinutesBefore: closeMinutes, active: d.active ?? true },
        });
      }
      return this.findOne(lotteryId);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      throw new BadRequestException(`Error al guardar horarios: ${message}`);
    }
  }
}
