import { Module } from '@nestjs/common';
import { MarketController } from './market.controller';

@Module({
  controllers: [MarketController],
  providers: [],
})
export class MarketModule {}
