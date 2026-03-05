import { Body, Controller, Get, Param, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ROLE_ADMIN, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { VendorsService, VendorAssignmentDto } from './vendors.service';

@ApiTags('vendors')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN)
@Controller('vendors')
export class VendorsController {
  constructor(private vendors: VendorsService) {}

  @Get()
  @ApiOperation({ summary: 'List sellers (POS_SELLER/POS_ADMIN) with point assignments' })
  findAll() {
    return this.vendors.findAll();
  }

  @Get('points')
  @ApiOperation({ summary: 'List all POS points (for assignment modal)' })
  findAllPoints() {
    return this.vendors.findAllPoints();
  }

  @Put(':userId/assignments')
  @ApiOperation({ summary: 'Set point assignments and commission % for a seller' })
  setAssignments(@Param('userId') userId: string, @Body() body: { assignments: VendorAssignmentDto[] }) {
    return this.vendors.setAssignments(userId, body.assignments ?? []);
  }
}
