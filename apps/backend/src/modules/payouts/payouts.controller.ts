import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ROLE_ADMIN, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { PayoutsService } from './payouts.service';

@ApiTags('payouts')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('payouts')
export class PayoutsController {
  constructor(private payouts: PayoutsService) {}

  @Get()
  @ApiOperation({ summary: 'List payout multipliers by bet type' })
  findAll() {
    return this.payouts.findAll();
  }

  @Put()
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN)
  @ApiOperation({ summary: 'Update payout multiplier for a bet type' })
  upsert(@Body() body: { betType: string; multiplier: number }) {
    const betType = body.betType as 'quiniela' | 'pale' | 'tripleta' | 'superpale';
    return this.payouts.upsert(betType, body.multiplier);
  }
}
