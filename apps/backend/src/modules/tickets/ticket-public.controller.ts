import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { TicketsService } from './tickets.service';

/**
 * Public ticket validation (no auth). Used when user scans QR on ticket.
 * Full URL: GET /api/v1/t/:ticketNumber
 */
@ApiTags('tickets')
@Controller()
export class TicketPublicController {
  constructor(private tickets: TicketsService) {}

  @Get('t/:ticketNumber')
  @ApiOperation({ summary: 'Public ticket validation (QR scan)' })
  getPublicValidation(@Param('ticketNumber') ticketNumber: string) {
    return this.tickets.getPublicValidation(ticketNumber);
  }
}
