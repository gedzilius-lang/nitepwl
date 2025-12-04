import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PosTransaction } from './pos-transaction.entity';
import { PosService } from './pos.service';
import { PosController } from './pos.controller';
import { NitecoinModule } from '../nitecoin/nitecoin.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([PosTransaction]),
    NitecoinModule,
    UsersModule
  ],
  controllers: [PosController],
  providers: [PosService],
})
export class PosModule {}
