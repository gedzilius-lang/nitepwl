import { Controller, Get } from '@nestjs/common';

@Controller('nitecoin')
export class NitecoinController {
  @Get()
  ping() {
    return {
      ok: true,
      service: 'nitecoin',
      message: 'Nite OS nitecoin endpoint stub',
    };
  }
}
