import { Body, Controller, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ROLE_ADMIN, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { PersonasService } from './personas.service';
import { CreatePersonaDto, UpdatePersonaDto } from './dto';
import { TipoPersona } from '@prisma/client';

@ApiTags('personas')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN)
@Controller('personas')
export class PersonasController {
  constructor(private personas: PersonasService) {}

  @Post()
  @ApiOperation({ summary: 'Create persona (vendedor/empleado data)' })
  create(@Body() dto: CreatePersonaDto) {
    return this.personas.create(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List personas, optional filter by tipo or sinUsuario (sin cuenta vinculada)' })
  findAll(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('tipo') tipo?: string,
    @Query('sinUsuario') sinUsuario?: string,
  ) {
    return this.personas.findAll(
      +(page || 1),
      +(limit || 50),
      tipo as TipoPersona | undefined,
      sinUsuario === 'true' || sinUsuario === '1',
    );
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get persona by id' })
  findOne(@Param('id') id: string) {
    return this.personas.findOne(id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update persona' })
  update(@Param('id') id: string, @Body() dto: UpdatePersonaDto) {
    return this.personas.update(id, dto);
  }
}
