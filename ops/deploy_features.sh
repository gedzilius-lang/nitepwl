#!/usr/bin/env bash
set -e

APP_DIR="/opt/nite-os-v7"
BACKEND_DIR="$APP_DIR/backend/src"

echo ">>> [Phase 3] Injecting Economy & POS Logic..."

# 1. UPGRADE USERS SERVICE (Needs helper methods)
# ---------------------------------------------------------
cat << 'EOF' > "$BACKEND_DIR/modules/users/users.service.ts"
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  findAll() {
    return this.usersRepository.find();
  }

  findOne(id: string) {
    return this.usersRepository.findOneBy({ id });
  }

  async findByExternalId(externalId: string) {
    return this.usersRepository.findOneBy({ externalId });
  }

  async adjustBalance(userId: string, amount: number) {
    const user = await this.findOne(userId);
    if (!user) throw new Error('User not found');
    user.niteBalance += amount;
    return this.usersRepository.save(user);
  }

  async createDemoUser() {
    const existing = await this.usersRepository.findOneBy({ externalId: 'demo_admin' });
    if (existing) return existing;

    const user = this.usersRepository.create({
      externalId: 'demo_admin',
      role: 'admin',
      nitetapId: 'tap_demo_123',
      xp: 1000,
      level: 5,
      niteBalance: 500
    });
    return this.usersRepository.save(user);
  }
}
EOF

# 2. CREATE NITECOIN MODULE (The Ledger)
# ---------------------------------------------------------
mkdir -p "$BACKEND_DIR/modules/nitecoin"

# Entity
cat << 'EOF' > "$BACKEND_DIR/modules/nitecoin/nitecoin-transaction.entity.ts"
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('nitecoin_transactions')
export class NitecoinTransaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column({ nullable: true })
  venueId: string;

  @Column({ type: 'int' })
  amount: number;

  @Column()
  type: string; // 'earn', 'spend', 'adjust'

  @CreateDateColumn()
  createdAt: Date;
}
EOF

# Service
cat << 'EOF' > "$BACKEND_DIR/modules/nitecoin/nitecoin.service.ts"
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NitecoinTransaction } from './nitecoin-transaction.entity';
import { UsersService } from '../users/users.service';

@Injectable()
export class NitecoinService {
  constructor(
    @InjectRepository(NitecoinTransaction)
    private repo: Repository<NitecoinTransaction>,
    private usersService: UsersService,
  ) {}

  async createTransaction(userId: string, venueId: string, amount: number, type: string) {
    // 1. Log the transaction
    const tx = this.repo.create({ userId, venueId, amount, type });
    await this.repo.save(tx);

    // 2. Move the money
    await this.usersService.adjustBalance(userId, amount);
    
    return tx;
  }

  async getHistory(userId: string) {
    return this.repo.find({ where: { userId }, order: { createdAt: 'DESC' } });
  }
}
EOF

# Module
cat << 'EOF' > "$BACKEND_DIR/modules/nitecoin/nitecoin.module.ts"
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NitecoinTransaction } from './nitecoin-transaction.entity';
import { NitecoinService } from './nitecoin.service';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([NitecoinTransaction]),
    UsersModule
  ],
  providers: [NitecoinService],
  exports: [NitecoinService],
})
export class NitecoinModule {}
EOF


# 3. CREATE POS MODULE (Point of Sale)
# ---------------------------------------------------------
mkdir -p "$BACKEND_DIR/modules/pos"

# Entity
cat << 'EOF' > "$BACKEND_DIR/modules/pos/pos-transaction.entity.ts"
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('pos_transactions')
export class PosTransaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  venueId: string;

  @Column()
  userId: string;

  @Column({ type: 'int' })
  totalNite: number;

  @Column({ type: 'jsonb', nullable: true })
  itemsSnapshot: any;

  @CreateDateColumn()
  createdAt: Date;
}
EOF

# Controller
cat << 'EOF' > "$BACKEND_DIR/modules/pos/pos.controller.ts"
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
EOF

# Service
cat << 'EOF' > "$BACKEND_DIR/modules/pos/pos.service.ts"
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PosTransaction } from './pos-transaction.entity';
import { NitecoinService } from '../nitecoin/nitecoin.service';
import { UsersService } from '../users/users.service';

@Injectable()
export class PosService {
  constructor(
    @InjectRepository(PosTransaction)
    private repo: Repository<PosTransaction>,
    private nitecoinService: NitecoinService,
    private usersService: UsersService
  ) {}

  async processCheckout(venueId: string, userId: string, amount: number, items: any) {
    // 1. Validate User Balance
    const user = await this.usersService.findOne(userId);
    if (!user) throw new Error('User not found');
    if (user.niteBalance < amount) throw new Error('Insufficient NITE balance');

    // 2. Charge User (Negative amount for spend)
    await this.nitecoinService.createTransaction(userId, venueId, -amount, 'spend');

    // 3. Record POS Receipt
    const tx = this.repo.create({
      venueId,
      userId,
      totalNite: amount,
      itemsSnapshot: items || []
    });
    return this.repo.save(tx);
  }

  async getVenueHistory(venueId: string) {
    return this.repo.find({ where: { venueId }, order: { createdAt: 'DESC' } });
  }
}
EOF

# Module
cat << 'EOF' > "$BACKEND_DIR/modules/pos/pos.module.ts"
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PosTransaction } from './pos-transaction.entity';
import { PosService } from './pos.service';
import { PosController } from './pos.controller';
import { NitecoinModule } from '../nitecoin/nitecoin.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([PosTransaction]),
    NitecoinModule,
    UsersModule
  ],
  controllers: [PosController],
  providers: [PosService],
})
export class PosModule {}
EOF


# 4. WIRE IT ALL TOGETHER (App Module)
# ---------------------------------------------------------
cat << 'EOF' > "$BACKEND_DIR/app.module.ts"
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersModule } from './modules/users/users.module';
import { FeedModule } from './modules/feed/feed.module';
import { VenuesModule } from './modules/venues/venues.module';
import { MarketModule } from './modules/market/market.module';
import { NitecoinModule } from './modules/nitecoin/nitecoin.module';
import { PosModule } from './modules/pos/pos.module';

import { User } from './modules/users/user.entity';
import { Venue } from './modules/venues/venue.entity';
import { MarketItem } from './modules/market/market-item.entity';
import { NitecoinTransaction } from './modules/nitecoin/nitecoin-transaction.entity';
import { PosTransaction } from './modules/pos/pos-transaction.entity';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5432,
      username: 'nite',
      password: 'nitepassword',
      database: 'nite_os',
      entities: [User, Venue, MarketItem, NitecoinTransaction, PosTransaction],
      synchronize: true, // v7 Dev Mode - Auto Sync Schema
    }),
    UsersModule,
    FeedModule,
    VenuesModule,
    MarketModule,
    NitecoinModule,
    PosModule
  ],
})
export class AppModule {}
EOF

# 5. DEPLOY VIA GIT
# ---------------------------------------------------------
echo ">>> [Git] Staging changes..."
cd "$APP_DIR"
git add .

echo ">>> [Git] Committing..."
git commit -m "Feat: Add Nitecoin Economy and POS modules"

echo ">>> [Git] Pushing to GitHub (Triggering CI/CD)..."
git push origin main

echo "--------------------------------------------------------"
echo ">>> DONE! Logic injected."
echo ">>> GitHub Action is now deploying this code to the server."
echo ">>> Wait ~2 minutes, then run 'pm2 logs nite-backend'."
echo "--------------------------------------------------------"
