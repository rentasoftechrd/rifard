import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

const DEFAULT_ONLINE_SECONDS = 60;

@Injectable()
export class PosService {
  constructor(private prisma: PrismaService) {}

  private getOnlineThresholdSeconds(): number {
    return parseInt(process.env.POS_HEARTBEAT_ONLINE_SECONDS ?? String(DEFAULT_ONLINE_SECONDS), 10) || DEFAULT_ONLINE_SECONDS;
  }

  /** Registra el dispositivo en el punto si el usuario tiene el punto asignado. Idempotente. */
  async registerDevice(userId: string, dto: { deviceId: string; pointId: string; name?: string }) {
    const assignment = await this.prisma.pointAssignment.findFirst({
      where: { pointId: dto.pointId, sellerUserId: userId, active: true },
    });
    if (!assignment) throw new BadRequestException('No tiene asignado este punto');
    const existing = await this.prisma.posDevice.findUnique({
      where: { deviceId: dto.deviceId },
    });
    if (existing) {
      if (existing.pointId !== dto.pointId) throw new BadRequestException('El dispositivo ya está asignado a otro punto');
      return existing;
    }
    return this.prisma.posDevice.create({
      data: {
        deviceId: dto.deviceId,
        pointId: dto.pointId,
        name: dto.name ?? null,
      },
    });
  }

  async heartbeat(dto: { deviceId: string; pointId: string; sellerId?: string; appVersion?: string }) {
    const device = await this.prisma.posDevice.findUnique({
      where: { deviceId: dto.deviceId },
      include: { point: true },
    });
    if (!device) throw new NotFoundException('Device not registered');
    if (device.pointId !== dto.pointId) throw new NotFoundException('Device not assigned to this point');

    await this.prisma.posPresence.upsert({
      where: { deviceId: dto.deviceId },
      create: {
        deviceId: dto.deviceId,
        pointId: dto.pointId,
        sellerUserId: dto.sellerId ?? null,
        appVersion: dto.appVersion ?? null,
        lastSeenAt: new Date(),
      },
      update: {
        pointId: dto.pointId,
        sellerUserId: dto.sellerId ?? null,
        appVersion: dto.appVersion ?? null,
        lastSeenAt: new Date(),
      },
    });
    return { ok: true };
  }

  async getConnected() {
    const threshold = new Date(Date.now() - this.getOnlineThresholdSeconds() * 1000);
    const presence = await this.prisma.posPresence.findMany({
      where: { lastSeenAt: { gte: threshold } },
      include: {
        point: true,
        seller: { select: { id: true, fullName: true, email: true } },
        device: true,
      },
    });
    const all = await this.prisma.posPresence.findMany({
      include: {
        point: true,
        seller: { select: { id: true, fullName: true } },
        device: true,
      },
    });
    return {
      online: presence.map((p) => ({
        ...p,
        status: 'online' as const,
      })),
      offline: all
        .filter((p) => p.lastSeenAt < threshold)
        .map((p) => ({
          ...p,
          status: 'offline' as const,
        })),
    };
  }

  async getPointsForUser(userId: string) {
    const assignments = await this.prisma.pointAssignment.findMany({
      where: { sellerUserId: userId, active: true },
      include: { point: true },
    });
    return assignments.map((a) => ({ ...a.point, commissionPercent: a.commissionPercent }));
  }

  async getMySession(userId: string, deviceId?: string) {
    if (!deviceId) return { point: null, seller: null, device: null };
    const presence = await this.prisma.posPresence.findUnique({
      where: { deviceId },
      include: {
        point: true,
        seller: { select: { id: true, fullName: true, email: true } },
        device: true,
      },
    });
    if (!presence || presence.sellerUserId !== userId) return { point: null, seller: null, device: null };
    return {
      point: presence.point,
      seller: presence.seller,
      device: presence.device,
    };
  }
}
