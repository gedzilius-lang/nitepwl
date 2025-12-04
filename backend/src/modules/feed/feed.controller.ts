import { Controller, Get } from '@nestjs/common';

@Controller('feed')
export class FeedController {
  @Get()
  ping() {
    return {
      ok: true,
      service: 'feed',
      message: 'Nite OS feed endpoint stub',
    };
  }
}
