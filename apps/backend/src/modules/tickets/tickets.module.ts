import { Module } from '@nestjs/common';
import { TicketsController } from './tickets.controller';
import { TicketPublicController } from './ticket-public.controller';
import { TicketsService } from './tickets.service';
import { TicketNumberService } from './ticket-number.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuditModule } from '../audit/audit.module';
import { PayoutsModule } from '../payouts/payouts.module';

@Module({
  imports: [PrismaModule, AuditModule, PayoutsModule],
  controllers: [TicketsController, TicketPublicController],
  providers: [TicketsService, TicketNumberService],
  exports: [TicketsService],
})
export class TicketsModule {}
