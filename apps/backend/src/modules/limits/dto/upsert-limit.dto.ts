import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNumber, IsOptional, IsString, IsUUID } from 'class-validator';
import { LimitType } from '@prisma/client';

export class UpsertLimitDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  id?: string;

  @ApiProperty({ enum: ['global', 'by_number', 'by_bet_type'] })
  @IsEnum(LimitType)
  type!: LimitType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  lotteryId?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  drawId?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  betType?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  numberKey?: string | null;

  @ApiProperty()
  @IsNumber()
  maxPayout!: number;

  @ApiPropertyOptional()
  @IsOptional()
  active?: boolean;
}
