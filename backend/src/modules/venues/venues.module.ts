import { Module, Controller, Get } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Venue } from './venue.entity';

@Controller('venues')
export class VenuesController {
  constructor(@InjectRepository(Venue) private repo: Repository<Venue>) {}

  @Get()
  async findAll() {
    const count = await this.repo.count();
    if (count === 0) {
        await this.repo.save({ slug: 'supermarket', title: 'Supermarket', city: 'Zurich' });
    }
    return this.repo.find();
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([Venue])],
  controllers: [VenuesController],
})
export class VenuesModule {}
