import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class VoidTicketDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  reason?: string;
}
