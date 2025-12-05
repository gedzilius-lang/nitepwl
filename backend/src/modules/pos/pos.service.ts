import { Injectable, BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { PosTransaction } from './pos-transaction.entity';
import { NitecoinTransaction } from '../nitecoin/nitecoin-transaction.entity';
import { User } from '../users/user.entity';
import { UsersService } from '../users/users.service';

@Injectable()
export class PosService {
  constructor(
    private dataSource: DataSource,
    private usersService: UsersService
  ) {}

  async processCheckout(venueId: string, userId: string, amount: number, items: any) {
    // Execute everything in a single database transaction
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 1. Lock and Get User (Prevent race conditions)
      const user = await queryRunner.manager.findOne(User, { 
        where: { id: userId },
        lock: { mode: 'pessimistic_write' } // Locks row until commit
      });

      if (!user) throw new BadRequestException('User not found');
      if (user.niteBalance < amount) throw new BadRequestException('Insufficient Funds');

      // 2. Create Ledger Entry
      const coinTx = queryRunner.manager.create(NitecoinTransaction, {
        userId,
        venueId,
        amount: -amount,
        type: 'spend'
      });
      await queryRunner.manager.save(coinTx);

      // 3. Update Balance
      user.niteBalance -= amount;
      
      // 4. Calculate XP & Level
      const xpGained = Math.abs(amount) * 10;
      user.xp += xpGained;
      user.level = Math.floor(Math.sqrt(user.xp) * 0.1) + 1;
      
      await queryRunner.manager.save(user);

      // 5. Create POS Receipt
      const posTx = queryRunner.manager.create(PosTransaction, {
        venueId,
        userId,
        totalNite: amount,
        itemsSnapshot: items || []
      });
      await queryRunner.manager.save(posTx);

      // Commit
      await queryRunner.commitTransaction();
      return posTx;

    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async getVenueHistory(venueId: string) {
    return this.dataSource.getRepository(PosTransaction).find({ 
      where: { venueId }, 
      order: { createdAt: 'DESC' } 
    });
  }
}
