import { BadRequestException, ConflictException, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreatePosPointDto } from './dto/create-pos-point.dto';
import { UpdatePosPointDto } from './dto/update-pos-point.dto';

const DEFAULT_ONLINE_SECONDS = 60;

/** Formato canónico para IDs: mismo que en BD. pointId es UUID → trim + minúsculas. */
function normalizePointId(id: string | null | undefined): string {
  const s = (id ?? '').trim();
  return s ? s.toLowerCase() : s;
}

function normalizeDeviceId(id: string | null | undefined): string {
  return (id ?? '').trim();
}

@Injectable()
export class PosService {
  constructor(private prisma: PrismaService) {}

  /** Lista todos los puntos de venta (backoffice admin). Incluye inactivos y conteo de asignaciones. */
  async findAllPointsForAdmin() {
    const points = await this.prisma.posPoint.findMany({
      orderBy: [{ active: 'desc' }, { name: 'asc' }],
      include: {
        _count: { select: { pointAssignments: true, posDevices: true } },
      },
    });
    return points.map((p) => ({
      id: normalizePointId(p.id) || p.id,
      name: p.name,
      code: p.code,
      address: p.address,
      active: p.active,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      assignmentsCount: p._count.pointAssignments,
      devicesCount: p._count.posDevices,
    }));
  }

  /** Crea un nuevo punto de venta. Código debe ser único. */
  async createPoint(dto: CreatePosPointDto) {
    const existing = await this.prisma.posPoint.findUnique({ where: { code: dto.code.trim() } });
    if (existing) throw new ConflictException(`Ya existe un punto con el código "${dto.code}"`);
    return this.prisma.posPoint.create({
      data: {
        name: dto.name.trim(),
        code: dto.code.trim(),
        address: dto.address?.trim() || null,
        active: dto.active ?? true,
      },
    });
  }

  /** Actualiza un punto de venta. Si se cambia code, debe seguir siendo único. */
  async updatePoint(id: string, dto: UpdatePosPointDto) {
    const point = await this.prisma.posPoint.findUnique({ where: { id } });
    if (!point) throw new NotFoundException('Punto de venta no encontrado');
    if (dto.code != null && dto.code.trim() !== point.code) {
      const existing = await this.prisma.posPoint.findUnique({ where: { code: dto.code.trim() } });
      if (existing) throw new ConflictException(`Ya existe un punto con el código "${dto.code}"`);
    }
    return this.prisma.posPoint.update({
      where: { id },
      data: {
        ...(dto.name != null && { name: dto.name.trim() }),
        ...(dto.code != null && { code: dto.code.trim() }),
        ...(dto.address !== undefined && { address: dto.address?.trim() || null }),
        ...(dto.active !== undefined && { active: dto.active }),
      },
    });
  }

  /** Desactiva un punto de venta (soft delete). Los vendedores ya no lo verán para asignar. */
  async deactivatePoint(id: string) {
    const point = await this.prisma.posPoint.findUnique({ where: { id } });
    if (!point) throw new NotFoundException('Punto de venta no encontrado');
    return this.prisma.posPoint.update({
      where: { id },
      data: { active: false },
    });
  }

  private getOnlineThresholdSeconds(): number {
    return parseInt(process.env.POS_HEARTBEAT_ONLINE_SECONDS ?? String(DEFAULT_ONLINE_SECONDS), 10) || DEFAULT_ONLINE_SECONDS;
  }

  /** Registra el dispositivo en el punto si el usuario tiene el punto asignado. Idempotente.
   * pointId y deviceId se normalizan para coincidir con el formato de la BD. */
  async registerDevice(userId: string, dto: { deviceId: string; pointId: string; name?: string }) {
    const uid = (userId ?? '').trim();
    const pointId = normalizePointId(dto.pointId);
    if (!pointId || !uid) {
      throw new BadRequestException('Faltan pointId o usuario. Cierra sesión y vuelve a entrar.');
    }
    try {
      const assignment = await this.prisma.pointAssignment.findFirst({
        where: { pointId, sellerUserId: uid, active: true },
      });
      if (!assignment) {
        const count = await this.prisma.pointAssignment.count({ where: { sellerUserId: uid, active: true } });
        const msg =
          count === 0
            ? 'No tiene ningún punto asignado. Asigna el punto en el backoffice (Personas → Puntos).'
            : `No tiene asignado este punto (pointId=${pointId.slice(0, 8)}…). Tiene ${count} punto(s) asignado(s); usa el mismo que elegiste en "Seleccionar punto".`;
        throw new BadRequestException(msg);
      }
      const deviceId = normalizeDeviceId(dto.deviceId);
      if (!deviceId) throw new BadRequestException('Falta deviceId.');
      const existing = await this.prisma.posDevice.findUnique({
        where: { deviceId },
      });
      if (existing) {
        const existingPointIdNorm = normalizePointId(existing.pointId);
        if (existingPointIdNorm !== pointId) throw new BadRequestException('El dispositivo ya está asignado a otro punto');
        return existing;
      }
      return this.prisma.posDevice.create({
        data: {
          deviceId,
          pointId,
          name: dto.name?.trim() ?? null,
        },
      });
    } catch (err: unknown) {
      if (err instanceof BadRequestException) throw err;
      const msg = err instanceof Error ? err.message : String(err);
      if (/connect|ECONNREFUSED|timeout|database/i.test(msg)) {
        throw new ServiceUnavailableException('Error de conexión con la base de datos. Revisa que el servidor pueda conectar a la DB.');
      }
      throw err;
    }
  }

  async heartbeat(dto: { deviceId: string; pointId: string; sellerId?: string; appVersion?: string }) {
    const deviceId = normalizeDeviceId(dto.deviceId);
    const pointId = normalizePointId(dto.pointId);
    if (!deviceId || !pointId) throw new NotFoundException('Device not registered');

    const device = await this.prisma.posDevice.findUnique({
      where: { deviceId },
      include: { point: true },
    });
    if (!device) throw new NotFoundException('Device not registered');
    if (normalizePointId(device.pointId) !== pointId) throw new NotFoundException('Device not assigned to this point');

    await this.prisma.posPresence.upsert({
      where: { deviceId },
      create: {
        deviceId,
        pointId,
        sellerUserId: dto.sellerId ?? null,
        appVersion: dto.appVersion ?? null,
        lastSeenAt: new Date(),
      },
      update: {
        pointId,
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

  /** Puntos asignados al usuario (POS). Devuelve id en formato canónico para que el cliente envíe el mismo valor. */
  async getPointsForUser(userId: string) {
    const assignments = await this.prisma.pointAssignment.findMany({
      where: { sellerUserId: userId, active: true },
      include: { point: true },
    });
    return assignments.map((a) => ({
      ...a.point,
      id: normalizePointId(a.point.id) || a.point.id,
      commissionPercent: a.commissionPercent,
    }));
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
