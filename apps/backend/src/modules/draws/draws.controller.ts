import {
  Body,
  Controller,
  Get,
  HttpException,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { DrawState } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { ensureDateNotFuture } from '../../common/server-time';
import { DrawsService } from './draws.service';

@ApiTags('draws')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('draws')
export class DrawsController {
  constructor(private draws: DrawsService) {}

  @Get()
  @ApiOperation({ summary: 'List draws by date and optional lottery' })
  async findByDate(@Query('date') date: string, @Query('lotteryId') lotteryId?: string) {
    try {
      const raw = date || new Date().toISOString().slice(0, 10);
      const d = ensureDateNotFuture(raw);
      return this.draws.findByDateAndLottery(d, lotteryId);
    } catch (err) {
      if (err instanceof HttpException) throw err;
      console.error('[DrawsController.findByDate]', err);
      throw new HttpException(
        'Error al listar sorteos. Revise la fecha (YYYY-MM-DD) y que no sea futura.',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('generate')
  @Roles(ROLE_SUPER_ADMIN)
  @ApiOperation({ summary: 'Generate draws for a date' })
  async generate(@Query('date') date: string) {
    try {
      const raw = date || new Date().toISOString().slice(0, 10);
      const d = ensureDateNotFuture(raw);
      return this.draws.generateForDate(d);
    } catch (err) {
      if (err instanceof HttpException) throw err;
      console.error('[DrawsController.generate]', err);
      throw new HttpException(
        'Error al generar sorteos. Revise la fecha (YYYY-MM-DD) y que no sea futura.',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get draw by id' })
  findOne(@Param('id') id: string) {
    return this.draws.findOne(id);
  }

  @Put(':id/state')
  @Roles(ROLE_SUPER_ADMIN)
  @ApiOperation({ summary: 'Update draw state' })
  updateState(@Param('id') id: string, @Body('state') state: DrawState) {
    return this.draws.updateState(id, state);
  }
}
