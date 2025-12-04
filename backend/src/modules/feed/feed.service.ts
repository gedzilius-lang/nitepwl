import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FeedItem } from './feed-item.entity';

@Injectable()
export class FeedService {
  constructor(
    @InjectRepository(FeedItem)
    private repo: Repository<FeedItem>,
  ) {}

  async findAll() {
    return this.repo.find({ order: { createdAt: 'DESC' } });
  }

  async create(data: Partial<FeedItem>) {
    return this.repo.save(this.repo.create(data));
  }

  async seed() {
    const count = await this.repo.count();
    if (count === 0) {
      await this.create({ type: 'news', title: 'Welcome to NiteOS v7', body: 'System Online. Economy Active.' });
      await this.create({ type: 'event', title: 'Launch Party', body: 'Double XP is now ENABLED.' });
    }
  }
}
