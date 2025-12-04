import { Module } from '@nestjs/common';
import { VenuesController } from './venues.controller';

@Module({
  controllers: [VenuesController],
  providers: [],
})
export class VenuesModule {}
