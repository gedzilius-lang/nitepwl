import { Module } from '@nestjs/common';
import { UsersModule } from './modules/users/users.module';
import { VenuesModule } from './modules/venues/venues.module';
import { NitecoinModule } from './modules/nitecoin/nitecoin.module';
import { MarketModule } from './modules/market/market.module';
import { FeedModule } from './modules/feed/feed.module';
import { PosModule } from './modules/pos/pos.module';
import { AuthModule } from './modules/auth/auth.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';

@Module({
  imports: [
    UsersModule,
    VenuesModule,
    NitecoinModule,
    MarketModule,
    FeedModule,
    PosModule,
    AuthModule,
    AnalyticsModule,
  ],
})
export class AppModule {}
