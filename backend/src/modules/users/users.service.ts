import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  findAll() {
    return this.usersRepository.find();
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
