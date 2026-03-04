import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MinLength, ValidateIf } from 'class-validator';

export class LoginDto {
  @ApiPropertyOptional()
  @ValidateIf((o) => !o.phone)
  @IsEmail()
  email?: string;

  @ApiPropertyOptional()
  @ValidateIf((o) => !o.email)
  @IsString()
  phone?: string;

  @ApiPropertyOptional()
  @IsString()
  @MinLength(6)
  password!: string;
}
