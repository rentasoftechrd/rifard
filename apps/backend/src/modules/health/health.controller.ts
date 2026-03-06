import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../../prisma/prisma.service';
import { getTimeResponse, getTimezone, serverNow, serverTodayISO, serverTimeDisplay } from '../../common/server-time';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private prisma: PrismaService) {}

  /**
   * Hora del servidor en zona RD. Público para que el POS muestre "Hora servidor (RD)" en login y todas las pantallas.
   * El POS no debe usar DateTime.now() para nada contable.
   */
  @Get('time')
  @ApiOperation({ summary: 'Server time (RD timezone) for POS' })
  time() {
    return getTimeResponse();
  }

  /**
   * Endpoint público para que el POS (celular) pruebe la conexión con el backend.
   * No requiere autenticación. El celular puede llamar GET /api/v1/health/pos-connect
   * para verificar que la URL del servidor es correcta antes del login.
   */
  @Get('pos-connect')
  posConnect() {
    return {
      ok: true,
      server: 'Rifard',
      message: 'Conectado',
      version: process.env.npm_package_version ?? '1.0.0',
      api: 'v1',
    };
  }

  @Get()
  async check() {
    let db = 'ok';
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      db = 'error';
    }
    return {
      status: db === 'ok' ? 'ok' : 'degraded',
      db,
      version: process.env.npm_package_version ?? '1.0.0',
      timestamp: serverNow().toISOString(),
      serverTime: serverNow().toISOString(),
      serverDate: serverTodayISO(),
      serverTimeDisplay: serverTimeDisplay(),
      timezone: getTimezone(),
    };
  }
}
