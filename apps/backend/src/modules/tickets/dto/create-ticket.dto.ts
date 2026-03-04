import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsArray, IsNumber, IsOptional, IsString, IsUUID, Min, ValidateNested } from 'class-validator';
import { BetType } from '@prisma/client';

export class TicketLineDto {
  @ApiProperty()
  @IsUUID()
  lotteryId!: string;

  @ApiProperty()
  @IsUUID()
  drawId!: string;

  @ApiProperty({ enum: ['quiniela', 'pale', 'tripleta', 'superpale'] })
  @IsString()
  betType!: BetType;

  @ApiProperty()
  @IsString()
  numbers!: string;

  @ApiProperty()
  @IsNumber()
  @Min(0)
  amount!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  potentialPayout?: number;
}

export class CreateTicketDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  ticketCode?: string;

  @ApiProperty()
  @IsUUID()
  pointId!: string;

  @ApiProperty()
  @IsString()
  deviceId!: string;

  @ApiProperty({ type: [TicketLineDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TicketLineDto)
  lines!: TicketLineDto[];
}
