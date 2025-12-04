import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NitecoinTransaction } from './nitecoin-transaction.entity';
import { UsersService } from '../users/users.service';

@Injectable()
export class NitecoinService {
  constructor(
    @InjectRepository(NitecoinTransaction)
    private repo: Repository<NitecoinTransaction>,
    private usersService: UsersService,
  ) {}

  async createTransaction(userId: string, venueId: string, amount: number, type: string) {
    // 1. Log the transaction
    const tx = this.repo.create({ userId, venueId, amount, type });
    await this.repo.save(tx);

    // 2. Move the money
    await this.usersService.adjustBalance(userId, amount);
    
    return tx;
  }

  async getHistory(userId: string) {
    return this.repo.find({ where: { userId }, order: { createdAt: 'DESC' } });
  }
}
