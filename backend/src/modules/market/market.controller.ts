import { Controller, Get } from '@nestjs/common';

@Controller('market')
export class MarketController {
  @Get()
  ping() {
    return {
      ok: true,
      service: 'market',
      message: 'Nite OS market endpoint stub',
    };
  }
}
