import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PosTransaction } from './pos-transaction.entity';
import { NitecoinService } from '../nitecoin/nitecoin.service';
import { UsersService } from '../users/users.service';

@Injectable()
export class PosService {
  constructor(
    @InjectRepository(PosTransaction)
    private repo: Repository<PosTransaction>,
    private nitecoinService: NitecoinService,
    private usersService: UsersService
  ) {}

  async processCheckout(venueId: string, userId: string, amount: number, items: any) {
    // 1. Validate User Balance
    const user = await this.usersService.findOne(userId);
    if (!user) throw new Error('User not found');
    if (user.niteBalance < amount) throw new Error('Insufficient NITE balance');

    // 2. Charge User (Negative amount for spend)
    await this.nitecoinService.createTransaction(userId, venueId, -amount, 'spend');

    // 3. Record POS Receipt
    const tx = this.repo.create({
      venueId,
      userId,
      totalNite: amount,
      itemsSnapshot: items || []
    });
    return this.repo.save(tx);
  }

  async getVenueHistory(venueId: string) {
    return this.repo.find({ where: { venueId }, order: { createdAt: 'DESC' } });
  }
}
