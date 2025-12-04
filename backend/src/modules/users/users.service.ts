import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  findAll() {
    return this.usersRepository.find();
  }

  findOne(id: string) {
    return this.usersRepository.findOneBy({ id });
  }

  async findByExternalId(externalId: string) {
    return this.usersRepository.findOneBy({ externalId });
  }

  async adjustBalance(userId: string, amount: number) {
    const user = await this.findOne(userId);
    if (!user) throw new Error('User not found');
    
    user.niteBalance += amount;
    return this.usersRepository.save(user);
  }

  // --- NEW: XP SYSTEM ---
  async addXp(userId: string, amount: number) {
    const user = await this.findOne(userId);
    if (!user) return;

    // 1 Nite Spent = 10 XP
    const xpGained = Math.abs(amount) * 10;
    user.xp += xpGained;

    // Simple Level Formula: Level = sqrt(XP) * 0.1
    // e.g. 100 XP = Lvl 1, 400 XP = Lvl 2
    const newLevel = Math.floor(Math.sqrt(user.xp) * 0.1) + 1;

    if (newLevel > user.level) {
      this.logger.log(`User ${user.externalId} leveled up! ${user.level} -> ${newLevel}`);
      user.level = newLevel;
    }

    await this.usersRepository.save(user);
    return { xpGained, newLevel };
  }

  async createDemoUser() {
    const existing = await this.usersRepository.findOneBy({ externalId: 'demo_admin' });
    if (existing) return existing;

    const user = this.usersRepository.create({
      externalId: 'demo_admin',
      role: 'admin',
      nitetapId: 'tap_demo_123',
      xp: 1000,
      level: 5,
      niteBalance: 500
    });
    return this.usersRepository.save(user);
  }
}
