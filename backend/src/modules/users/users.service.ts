import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly repo: Repository<User>,
  ) {}

  findAll() {
    return this.repo.find({
      order: { id: 'ASC' },
    });
  }

  async createDemo() {
    const count = await this.repo.count();
    const email = `demo+${count + 1}@nite.local`;
    const user = this.repo.create({ email });
    return this.repo.save(user);
  }
}
