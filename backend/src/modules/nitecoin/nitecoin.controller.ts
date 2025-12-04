import { Controller, Get, Param } from '@nestjs/common';
import { NitecoinService } from './nitecoin.service';

@Controller('nitecoin')
export class NitecoinController {
  constructor(private readonly service: NitecoinService) {}

  @Get('history/:userId')
  getHistory(@Param('userId') userId: string) {
    return this.service.getHistory(userId);
  }
}
