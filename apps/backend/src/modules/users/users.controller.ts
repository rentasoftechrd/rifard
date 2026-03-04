import { Body, Controller, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ROLE_ADMIN, ROLE_SUPER_ADMIN } from '../../common/constants/roles';
import { UsersService } from './users.service';
import { CreateUserDto, UpdateUserDto, AssignRolesDto } from './dto';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(ROLE_SUPER_ADMIN, ROLE_ADMIN)
@Controller('users')
export class UsersController {
  constructor(private users: UsersService) {}

  @Post()
  @ApiOperation({ summary: 'Create user' })
  create(@Body() dto: CreateUserDto) {
    return this.users.create(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List users (paginated)' })
  findAll(@Query('page') page?: string, @Query('limit') limit?: string) {
    return this.users.findAll(+(page || 1), +(limit || 20));
  }

  @Get('roles')
  @ApiOperation({ summary: 'List all roles' })
  getRoles() {
    return this.users.getRoles();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user by id' })
  findOne(@Param('id') id: string) {
    return this.users.findOne(id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update user' })
  update(@Param('id') id: string, @Body() dto: UpdateUserDto) {
    return this.users.update(id, dto);
  }

  @Put(':id/roles')
  @ApiOperation({ summary: 'Assign roles to user' })
  assignRoles(@Param('id') id: string, @Body() dto: AssignRolesDto) {
    return this.users.assignRoles(id, dto);
  }

  @Put(':id/activate')
  @ApiOperation({ summary: 'Activate or deactivate user' })
  setActive(@Param('id') id: string, @Body('active') active: boolean) {
    return this.users.setActive(id, active);
  }
}
