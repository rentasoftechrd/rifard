import { Body, Controller, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { LotteriesService } from './lotteries.service';
import { CreateLotteryDto, UpdateLotteryDto, DrawTimeDto } from './dto';

@ApiTags('lotteries')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('lotteries')
export class LotteriesController {
  constructor(private lotteries: LotteriesService) {}

  @Post()
  @Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE)
  @ApiOperation({ summary: 'Create lottery' })
  create(@Body() dto: CreateLotteryDto) {
    return this.lotteries.create(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List lotteries' })
  findAll() {
    return this.lotteries.findAll();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get lottery with draw times' })
  findOne(@Param('id') id: string) {
    return this.lotteries.findOne(id);
  }

  @Put(':id')
  @Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE)
  @ApiOperation({ summary: 'Update lottery' })
  update(@Param('id') id: string, @Body() dto: UpdateLotteryDto) {
    return this.lotteries.update(id, dto);
  }

  @Put(':id/draw-times')
  @Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE)
  @ApiOperation({ summary: 'Set draw times for lottery' })
  setDrawTimes(@Param('id') id: string, @Body() body: { drawTimes: DrawTimeDto[] }) {
    return this.lotteries.setDrawTimes(id, body.drawTimes);
  }
}
