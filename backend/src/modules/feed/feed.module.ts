import { Module, Controller, Get } from '@nestjs/common';

@Controller('feed')
export class FeedController {
  @Get()
  getFeed() {
    return [
      { id: 1, type: 'news', title: 'Welcome to NiteOS v7', body: 'System operational.' },
      { id: 2, type: 'event', title: 'Friday Night', body: 'Double XP enabled.' }
    ];
  }
}

@Module({
  controllers: [FeedController],
})
export class FeedModule {}
