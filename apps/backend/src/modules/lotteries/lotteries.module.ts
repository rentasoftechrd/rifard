import { Module } from '@nestjs/common';
import { LotteriesController } from './lotteries.controller';
import { LotteriesService } from './lotteries.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [LotteriesController],
  providers: [LotteriesService],
  exports: [LotteriesService],
})
export class LotteriesModule {}
