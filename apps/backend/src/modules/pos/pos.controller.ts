import { Body, Controller, Delete, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ROLE_POS_SELLER, ROLE_POS_ADMIN, ROLE_ADMIN, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { PosService } from './pos.service';
import { CreatePosPointDto } from './dto/create-pos-point.dto';
import { UpdatePosPointDto } from './dto/update-pos-point.dto';

@ApiTags('pos')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('pos')
export class PosController {
  constructor(private pos: PosService) {}

  @Get('points-admin')
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN)
  @ApiOperation({ summary: 'List all POS points for backoffice (create/edit points)' })
  findAllPointsForAdmin() {
    return this.pos.findAllPointsForAdmin();
  }

  @Post('points')
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN)
  @ApiOperation({ summary: 'Create a new POS point' })
  createPoint(@Body() dto: CreatePosPointDto) {
    return this.pos.createPoint(dto);
  }

  @Put('points/:id')
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN)
  @ApiOperation({ summary: 'Update a POS point' })
  updatePoint(@Param('id') id: string, @Body() dto: UpdatePosPointDto) {
    return this.pos.updatePoint(id, dto);
  }

  @Delete('points/:id')
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN)
  @ApiOperation({ summary: 'Deactivate a POS point (soft delete)' })
  deactivatePoint(@Param('id') id: string) {
    return this.pos.deactivatePoint(id);
  }

  @Post('register-device')
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN, ROLE_POS_ADMIN, ROLE_POS_SELLER)
  @ApiOperation({ summary: 'Register device for point (if user has point assigned)' })
  registerDevice(
    @CurrentUser('sub') userId: string,
    @Body() body: { deviceId: string; pointId: string; name?: string },
  ) {
    return this.pos.registerDevice(userId, body);
  }

  @Post('heartbeat')
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN, ROLE_POS_ADMIN, ROLE_POS_SELLER)
  @ApiOperation({ summary: 'POS heartbeat' })
  heartbeat(
    @Body() body: { deviceId: string; pointId: string; sellerId?: string; appVersion?: string },
  ) {
    return this.pos.heartbeat(body);
  }

  @Get('connected')
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN, ROLE_POS_ADMIN, ROLE_POS_SELLER)
  @ApiOperation({ summary: 'List connected POS (online/offline by last_seen)' })
  getConnected() {
    return this.pos.getConnected();
  }

  @Get('points')
  @Roles(ROLE_ADMIN, ROLE_SUPER_ADMIN, ROLE_POS_ADMIN, ROLE_POS_SELLER)
  @ApiOperation({ summary: 'Points assigned to current user' })
  getPoints(@CurrentUser('sub') userId: string) {
    return this.pos.getPointsForUser(userId);
  }

  @Get('my-session')
  @Roles(ROLE_POS_SELLER)
  @ApiOperation({ summary: 'Current point + seller + device' })
  getMySession(@CurrentUser('sub') userId: string, @Query('deviceId') deviceId?: string) {
    return this.pos.getMySession(userId, deviceId);
  }
}
