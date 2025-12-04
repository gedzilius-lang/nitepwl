import { Controller, Get } from '@nestjs/common';

@Controller('auth')
export class AuthController {
  @Get()
  ping() {
    return {
      ok: true,
      service: 'auth',
      message: 'Nite OS auth endpoint stub',
    };
  }
}
