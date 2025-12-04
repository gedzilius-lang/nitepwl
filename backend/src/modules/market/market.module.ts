import { Module, Controller, Get, Param } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MarketItem } from './market-item.entity';

@Controller('market')
export class MarketController {
  constructor(@InjectRepository(MarketItem) private repo: Repository<MarketItem>) {}

  @Get(':venueId/items')
  async findByVenue(@Param('venueId') venueId: string) {
    const count = await this.repo.count();
    if (count === 0) {
        await this.repo.save({ title: 'Nite Shot', priceNite: 50, venueId: 1 });
        await this.repo.save({ title: 'VIP Access', priceNite: 500, venueId: 1 });
    }
    return this.repo.find({ where: { venueId: Number(venueId) } });
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([MarketItem])],
  controllers: [MarketController],
})
export class MarketModule {}
