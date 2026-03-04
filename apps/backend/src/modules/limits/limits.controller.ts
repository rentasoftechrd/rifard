import { Body, Controller, Delete, Get, Param, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { LimitsService } from './limits.service';
import { UpsertLimitDto } from './dto/upsert-limit.dto';

/** Solo SUPER_ADMIN puede ver y modificar límites; así se evita fraude. */
@ApiTags('limits')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(ROLE_SUPER_ADMIN)
@Controller('limits')
export class LimitsController {
  constructor(private limits: LimitsService) {}

  @Get()
  @ApiOperation({ summary: 'List limit configs' })
  findMany(@Query('lotteryId') lotteryId?: string, @Query('drawId') drawId?: string) {
    return this.limits.findMany(lotteryId, drawId);
  }

  @Put()
  @ApiOperation({ summary: 'Create or update limit config' })
  upsert(@Body() dto: UpsertLimitDto) {
    return this.limits.upsert(dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete limit config' })
  delete(@Param('id') id: string) {
    return this.limits.delete(id);
  }
}
