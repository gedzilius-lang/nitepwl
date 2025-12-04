import { Controller, Post, Body, Param, Get, HttpException, HttpStatus } from '@nestjs/common';
import { PosService } from './pos.service';

@Controller('pos')
export class PosController {
  constructor(private readonly posService: PosService) {}

  @Post(':venueId/checkout')
  async checkout(
    @Param('venueId') venueId: string,
    @Body() body: { userId: string; amount: number; items?: any }
  ) {
    try {
      return await this.posService.processCheckout(venueId, body.userId, body.amount, body.items);
    } catch (e) {
      throw new HttpException(e.message, HttpStatus.BAD_REQUEST);
    }
  }

  @Get('history/:venueId')
  async getVenueHistory(@Param('venueId') venueId: string) {
    return this.posService.getVenueHistory(venueId);
  }
}
