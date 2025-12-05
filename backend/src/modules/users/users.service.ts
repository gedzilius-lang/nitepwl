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

  async findByUsername(username: string) {
    // We explicitly select passwordHash for validation
    return this.usersRepository.findOne({ 
      where: { username },
      select: ['id', 'username', 'passwordHash', 'role', 'niteBalance', 'xp', 'level']
    });
  }

  async create(username: string, passwordHash: string) {
    const user = this.usersRepository.create({ username, passwordHash });
    return this.usersRepository.save(user);
  }

  async adjustBalance(userId: string, amount: number, manager?: any) {
    // Support transactional manager if provided
    const repo = manager ? manager.getRepository(User) : this.usersRepository;
    
    const user = await repo.findOneBy({ id: userId });
    if (!user) throw new Error('User not found');
    
    user.niteBalance += amount;
    return repo.save(user);
  }

  // XP System
  async addXp(userId: string, amount: number, manager?: any) {
    const repo = manager ? manager.getRepository(User) : this.usersRepository;
    const user = await repo.findOneBy({ id: userId });
    if (!user) return;

    const xpGained = Math.abs(amount) * 10;
    user.xp += xpGained;
    const newLevel = Math.floor(Math.sqrt(user.xp) * 0.1) + 1;

    if (newLevel > user.level) {
      user.level = newLevel;
    }
    await repo.save(user);
  }

  async createDemoUser() {
    // Legacy support
    const existing = await this.usersRepository.findOneBy({ username: 'demo_admin' });
    if (existing) return existing;
    const user = this.usersRepository.create({
      username: 'demo_admin',
      role: 'admin',
      xp: 1000,
      level: 5,
      niteBalance: 500
    });
    return this.usersRepository.save(user);
  }
}
