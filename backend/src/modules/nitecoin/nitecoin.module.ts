import { Module } from '@nestjs/common';
import { NitecoinController } from './nitecoin.controller';

@Module({
  controllers: [NitecoinController],
  providers: [],
})
export class NitecoinModule {}
