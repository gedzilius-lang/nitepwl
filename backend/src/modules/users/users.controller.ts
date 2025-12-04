import { Controller, Get } from '@nestjs/common';

@Controller('users')
export class UsersController {
  @Get()
  ping() {
    return {
      ok: true,
      service: 'users',
      message: 'Nite OS users endpoint stub',
    };
  }
}
