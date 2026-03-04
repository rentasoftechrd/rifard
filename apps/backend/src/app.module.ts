import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { LotteriesModule } from './modules/lotteries/lotteries.module';
import { DrawsModule } from './modules/draws/draws.module';
import { ResultsModule } from './modules/results/results.module';
import { LimitsModule } from './modules/limits/limits.module';
import { PayoutsModule } from './modules/payouts/payouts.module';
import { TicketsModule } from './modules/tickets/tickets.module';
import { PosModule } from './modules/pos/pos.module';
import { ReportsModule } from './modules/reports/reports.module';
import { AuditModule } from './modules/audit/audit.module';
import { HealthModule } from './modules/health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: ['.env', '.env.local'] }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 10 }]),
    PrismaModule,
    AuthModule,
    UsersModule,
    LotteriesModule,
    DrawsModule,
    ResultsModule,
    LimitsModule,
    PayoutsModule,
    TicketsModule,
    PosModule,
    ReportsModule,
    AuditModule,
    HealthModule,
  ],
})
export class AppModule {}
