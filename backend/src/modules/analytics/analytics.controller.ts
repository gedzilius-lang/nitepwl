import { Controller, Get } from '@nestjs/common';

@Controller('analytics')
export class AnalyticsController {
  @Get()
  ping() {
    return {
      ok: true,
      service: 'analytics',
      message: 'Nite OS analytics endpoint stub',
    };
  }
}
