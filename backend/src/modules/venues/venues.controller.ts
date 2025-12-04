import { Controller, Get } from '@nestjs/common';

@Controller('venues')
export class VenuesController {
  @Get()
  ping() {
    return {
      ok: true,
      service: 'venues',
      message: 'Nite OS venues endpoint stub',
    };
  }
}
