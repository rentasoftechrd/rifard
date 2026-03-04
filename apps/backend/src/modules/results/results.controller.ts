import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { ResultsService } from './results.service';

@ApiTags('results')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('draws')
export class ResultsController {
  constructor(private results: ResultsService) {}

  @Get('results/pending')
  @ApiOperation({ summary: 'List draws with pending approval results' })
  listPending() {
    return this.results.listPending();
  }

  @Post(':id/results')
  @Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE)
  @ApiOperation({ summary: 'Enter results (pending approval)' })
  enter(@Param('id') drawId: string, @Body() body: { results: Record<string, unknown> }, @CurrentUser('sub') userId: string) {
    return this.results.enter(drawId, body.results ?? {}, userId);
  }

  @Post(':id/results/approve')
  @Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN)
  @ApiOperation({ summary: 'Approve results' })
  approve(@Param('id') drawId: string, @CurrentUser('sub') userId: string) {
    return this.results.approve(drawId, userId);
  }

  @Post(':id/results/reject')
  @Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN)
  @ApiOperation({ summary: 'Reject results' })
  reject(@Param('id') drawId: string, @Body() body: { reason?: string }, @CurrentUser('sub') userId: string) {
    return this.results.reject(drawId, userId, body.reason);
  }

  @Get(':id/results')
  @ApiOperation({ summary: 'Get result for draw' })
  getByDraw(@Param('id') drawId: string) {
    return this.results.getByDraw(drawId);
  }
}
