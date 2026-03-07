import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE, ROLE_POS_ADMIN, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { ReportsService } from './reports.service';

@ApiTags('reports')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE, ROLE_POS_ADMIN)
@Controller('reports')
export class ReportsController {
  constructor(private reports: ReportsService) {}

  @Get('dashboard-summary')
  @ApiOperation({ summary: 'Dashboard summary; date + optional range: day (default), week, month' })
  dashboardSummary(
    @Query('date') date?: string,
    @Query('range') range?: 'day' | 'week' | 'month',
  ) {
    const d = date || new Date().toISOString().slice(0, 10);
    return this.reports.dashboardSummary(d, range ?? 'day');
  }

  @Get('daily-sales')
  @ApiOperation({ summary: 'Daily sales' })
  dailySales(
    @Query('date') date: string,
    @Query('pointId') pointId?: string,
    @Query('sellerId') sellerId?: string,
  ) {
    const d = date || new Date().toISOString().slice(0, 10);
    return this.reports.dailySales(d, pointId, sellerId);
  }

  @Get('commissions')
  @ApiOperation({ summary: 'Commissions by seller for date' })
  commissions(@Query('date') date: string) {
    const d = date || new Date().toISOString().slice(0, 10);
    return this.reports.commissions(d);
  }

  @Get('voids')
  @ApiOperation({ summary: 'Voids for date' })
  voids(@Query('date') date: string) {
    const d = date || new Date().toISOString().slice(0, 10);
    return this.reports.voids(d);
  }

  @Get('exposure')
  @ApiOperation({ summary: 'Exposure for draw' })
  exposure(@Query('drawId') drawId: string) {
    return this.reports.exposure(drawId);
  }
}
