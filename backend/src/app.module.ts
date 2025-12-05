import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MongooseModule } from '@nestjs/mongoose';

import { UsersModule } from './modules/users/users.module';
import { AuthModule } from './modules/auth/auth.module';
import { FeedModule } from './modules/feed/feed.module';
import { VenuesModule } from './modules/venues/venues.module';
import { MarketModule } from './modules/market/market.module';
import { NitecoinModule } from './modules/nitecoin/nitecoin.module';
import { PosModule } from './modules/pos/pos.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';

import { User } from './modules/users/user.entity';
import { Venue } from './modules/venues/venue.entity';
import { MarketItem } from './modules/market/market-item.entity';
import { NitecoinTransaction } from './modules/nitecoin/nitecoin-transaction.entity';
import { PosTransaction } from './modules/pos/pos-transaction.entity';
import { FeedItem } from './modules/feed/feed-item.entity';

@Module({
  imports: [
    // PostgreSQL (Relational Data)
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: 5432,
      username: 'nite',
      password: 'nitepassword',
      database: 'nite_os',
      entities: [User, Venue, MarketItem, NitecoinTransaction, PosTransaction, FeedItem],
      synchronize: true, 
    }),
    // MongoDB (Analytics Data)
    MongooseModule.forRoot('mongodb://localhost:27017/nite_analytics'),
    
    // Core Modules
    UsersModule,
    AuthModule,
    FeedModule,
    VenuesModule,
    MarketModule,
    NitecoinModule,
    PosModule,
    AnalyticsModule
  ],
})
export class AppModule {}
