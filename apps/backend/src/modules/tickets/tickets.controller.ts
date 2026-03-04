import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ROLE_ADMIN, ROLE_OPERADOR_BACKOFFICE, ROLE_POS_SELLER, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { TicketsService } from './tickets.service';
import { CreateTicketDto, VoidTicketDto } from './dto';

const ROLES_PAYMENT = [ROLE_POS_SELLER, ROLE_OPERADOR_BACKOFFICE, ROLE_ADMIN, ROLE_SUPER_ADMIN];

@ApiTags('tickets')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('tickets')
export class TicketsController {
  constructor(private tickets: TicketsService) {}

  @Post()
  @Roles(ROLE_POS_SELLER)
  @ApiOperation({ summary: 'Create ticket (validates limits)' })
  create(@Body() dto: CreateTicketDto, @CurrentUser('sub') userId: string) {
    return this.tickets.create(dto, userId);
  }

  @Post(':id/print')
  @Roles(ROLE_POS_SELLER)
  @ApiOperation({ summary: 'Mark ticket as printed' })
  print(@Param('id') id: string) {
    return this.tickets.print(id);
  }

  @Post(':id/void')
  @Roles(ROLE_POS_SELLER)
  @ApiOperation({ summary: 'Void ticket (5min window + draw not closed)' })
  void(@Param('id') id: string, @Body() dto: VoidTicketDto, @CurrentUser('sub') userId: string) {
    return this.tickets.void(id, dto, userId);
  }

  @Get('code/:code/payment')
  @Roles(...ROLES_PAYMENT)
  @ApiOperation({ summary: 'Get ticket by code for payment (winning lines, amount, already paid)' })
  getByCodeForPayment(@Param('code') code: string) {
    return this.tickets.getByCodeForPayment(code);
  }

  @Get('code/:code')
  @Roles(ROLE_POS_SELLER)
  @ApiOperation({ summary: 'Get ticket by code' })
  getByCode(@Param('code') code: string) {
    return this.tickets.getByCode(code);
  }

  @Post(':id/pay')
  @Roles(...ROLES_PAYMENT)
  @ApiOperation({ summary: 'Mark ticket as paid (prize payout); prevents double claim at another point' })
  markAsPaid(@Param('id') id: string, @CurrentUser('sub') userId: string) {
    return this.tickets.markAsPaid(id, userId);
  }
}
