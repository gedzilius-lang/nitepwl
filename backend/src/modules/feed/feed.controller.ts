import { Controller, Get, Post, Body } from '@nestjs/common';
import { FeedService } from './feed.service';

@Controller('feed')
export class FeedController {
  constructor(private readonly service: FeedService) {}

  @Get()
  async getFeed() {
    await this.service.seed(); // Auto-seed if empty
    return this.service.findAll();
  }

  @Post()
  createPost(@Body() body: any) {
    return this.service.create(body);
  }
}
