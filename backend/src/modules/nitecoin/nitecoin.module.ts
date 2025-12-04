import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NitecoinTransaction } from './nitecoin-transaction.entity';
import { NitecoinService } from './nitecoin.service';
import { NitecoinController } from './nitecoin.controller';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([NitecoinTransaction]),
    UsersModule
  ],
  controllers: [NitecoinController],
  providers: [NitecoinService],
  exports: [NitecoinService],
})
export class NitecoinModule {}
