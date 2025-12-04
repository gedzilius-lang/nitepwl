import { Controller, Get } from '@nestjs/common';

@Controller('pos')
export class PosController {
  @Get()
  ping() {
    return {
      ok: true,
      service: 'pos',
      message: 'Nite OS pos endpoint stub',
    };
  }
}
