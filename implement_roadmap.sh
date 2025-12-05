#!/bin/bash
set -e

APP_DIR="$HOME/nitepwl"
BACKEND_DIR="$APP_DIR/backend"
FRONTEND_DIR="$APP_DIR/frontend"

echo ">>> [Roadmap] Starting NiteOS v7.1 Upgrade..."

# ==========================================
# 1. INFRASTRUCTURE (Add MongoDB)
# ==========================================
echo ">>> [1/5] Updating Docker Infrastructure..."

cat << 'DOCKER' > "$APP_DIR/docker-compose.yml"
version: '3.8'
services:
  postgres:
    image: postgres:15
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: nite
      POSTGRES_PASSWORD: nitepassword
      POSTGRES_DB: nite_os
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

  mongo:
    image: mongo:6.0
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db

volumes:
  postgres_data:
  mongo_data:
DOCKER

# ==========================================
# 2. DEPENDENCIES
# ==========================================
echo ">>> [2/5] Installing Backend Packages..."
cd "$BACKEND_DIR"
npm install --save @nestjs/jwt @nestjs/passport passport passport-jwt bcrypt @types/bcrypt @nestjs/mongoose mongoose
cd "$APP_DIR"

# ==========================================
# 3. AUTHENTICATION MODULE (JWT)
# ==========================================
echo ">>> [3/5] Building Auth Module..."

mkdir -p "$BACKEND_DIR/src/modules/auth"

# --- User Entity Update (Password Support) ---
cat << 'TS' > "$BACKEND_DIR/src/modules/users/user.entity.ts"
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', nullable: true })
  username: string; // Changed from externalId for clarity, acts as login

  @Column({ type: 'varchar', select: false, nullable: true }) 
  passwordHash: string; // Hidden by default

  @Index({ unique: true })
  @Column({ type: 'varchar', nullable: true })
  nitetapId: string;

  @Column({ type: 'int', default: 1 })
  level: number;

  @Column({ type: 'int', default: 0 })
  xp: number;

  @Column({ type: 'int', default: 0 })
  niteBalance: number;

  @Column({ type: 'varchar', default: 'user' })
  role: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
TS

# --- Auth Service ---
cat << 'TS' > "$BACKEND_DIR/src/modules/auth/auth.service.ts"
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService
  ) {}

  async validateUser(username: string, pass: string): Promise<any> {
    const user = await this.usersService.findByUsername(username);
    if (user && user.passwordHash && await bcrypt.compare(pass, user.passwordHash)) {
      const { passwordHash, ...result } = user;
      return result;
    }
    return null;
  }

  async login(user: any) {
    const payload = { username: user.username, sub: user.id, role: user.role };
    return {
      access_token: this.jwtService.sign(payload),
      user: user
    };
  }

  async register(username: string, pass: string) {
    const hash = await bcrypt.hash(pass, 10);
    return this.usersService.create(username, hash);
  }
}
TS

# --- Auth Controller ---
cat << 'TS' > "$BACKEND_DIR/src/modules/auth/auth.controller.ts"
import { Controller, Post, Body, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  async login(@Body() body: any) {
    const user = await this.authService.validateUser(body.username, body.password);
    if (!user) {
      throw new UnauthorizedException();
    }
    return this.authService.login(user);
  }

  @Post('register')
  async register(@Body() body: any) {
    return this.authService.register(body.username, body.password);
  }
}
TS

# --- JWT Strategy ---
cat << 'TS' > "$BACKEND_DIR/src/modules/auth/jwt.strategy.ts"
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable } from '@nestjs/common';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: 'SECRET_KEY_DEV_ONLY', // Move to env in prod
    });
  }

  async validate(payload: any) {
    return { userId: payload.sub, username: payload.username, role: payload.role };
  }
}
TS

# --- Auth Module Def ---
cat << 'TS' > "$BACKEND_DIR/src/modules/auth/auth.module.ts"
import { Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { UsersModule } from '../users/users.module';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { JwtStrategy } from './jwt.strategy';

@Module({
  imports: [
    UsersModule,
    PassportModule,
    JwtModule.register({
      secret: 'SECRET_KEY_DEV_ONLY',
      signOptions: { expiresIn: '60m' },
    }),
  ],
  providers: [AuthService, JwtStrategy],
  controllers: [AuthController],
  exports: [AuthService],
})
export class AuthModule {}
TS

# --- Update User Service for Auth ---
cat << 'TS' > "$BACKEND_DIR/src/modules/users/users.service.ts"
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

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

  async findByUsername(username: string) {
    // We explicitly select passwordHash for validation
    return this.usersRepository.findOne({ 
      where: { username },
      select: ['id', 'username', 'passwordHash', 'role', 'niteBalance', 'xp', 'level']
    });
  }

  async create(username: string, passwordHash: string) {
    const user = this.usersRepository.create({ username, passwordHash });
    return this.usersRepository.save(user);
  }

  async adjustBalance(userId: string, amount: number, manager?: any) {
    // Support transactional manager if provided
    const repo = manager ? manager.getRepository(User) : this.usersRepository;
    
    const user = await repo.findOneBy({ id: userId });
    if (!user) throw new Error('User not found');
    
    user.niteBalance += amount;
    return repo.save(user);
  }

  // XP System
  async addXp(userId: string, amount: number, manager?: any) {
    const repo = manager ? manager.getRepository(User) : this.usersRepository;
    const user = await repo.findOneBy({ id: userId });
    if (!user) return;

    const xpGained = Math.abs(amount) * 10;
    user.xp += xpGained;
    const newLevel = Math.floor(Math.sqrt(user.xp) * 0.1) + 1;

    if (newLevel > user.level) {
      user.level = newLevel;
    }
    await repo.save(user);
  }

  async createDemoUser() {
    // Legacy support
    const existing = await this.usersRepository.findOneBy({ username: 'demo_admin' });
    if (existing) return existing;
    const user = this.usersRepository.create({
      username: 'demo_admin',
      role: 'admin',
      xp: 1000,
      level: 5,
      niteBalance: 500
    });
    return this.usersRepository.save(user);
  }
}
TS

# ==========================================
# 4. ECONOMY HARDENING (Transactions)
# ==========================================
echo ">>> [4/5] Hardening Economy (ACID Transactions)..."

cat << 'TS' > "$BACKEND_DIR/src/modules/pos/pos.service.ts"
import { Injectable, BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { PosTransaction } from './pos-transaction.entity';
import { NitecoinTransaction } from '../nitecoin/nitecoin-transaction.entity';
import { User } from '../users/user.entity';
import { UsersService } from '../users/users.service';

@Injectable()
export class PosService {
  constructor(
    private dataSource: DataSource,
    private usersService: UsersService
  ) {}

  async processCheckout(venueId: string, userId: string, amount: number, items: any) {
    // Execute everything in a single database transaction
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 1. Lock and Get User (Prevent race conditions)
      const user = await queryRunner.manager.findOne(User, { 
        where: { id: userId },
        lock: { mode: 'pessimistic_write' } // Locks row until commit
      });

      if (!user) throw new BadRequestException('User not found');
      if (user.niteBalance < amount) throw new BadRequestException('Insufficient Funds');

      // 2. Create Ledger Entry
      const coinTx = queryRunner.manager.create(NitecoinTransaction, {
        userId,
        venueId,
        amount: -amount,
        type: 'spend'
      });
      await queryRunner.manager.save(coinTx);

      // 3. Update Balance
      user.niteBalance -= amount;
      
      // 4. Calculate XP & Level
      const xpGained = Math.abs(amount) * 10;
      user.xp += xpGained;
      user.level = Math.floor(Math.sqrt(user.xp) * 0.1) + 1;
      
      await queryRunner.manager.save(user);

      // 5. Create POS Receipt
      const posTx = queryRunner.manager.create(PosTransaction, {
        venueId,
        userId,
        totalNite: amount,
        itemsSnapshot: items || []
      });
      await queryRunner.manager.save(posTx);

      // Commit
      await queryRunner.commitTransaction();
      return posTx;

    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async getVenueHistory(venueId: string) {
    return this.dataSource.getRepository(PosTransaction).find({ 
      where: { venueId }, 
      order: { createdAt: 'DESC' } 
    });
  }
}
TS

# ==========================================
# 5. ANALYTICS (MongoDB)
# ==========================================
echo ">>> [5/5] Building Analytics Module..."

mkdir -p "$BACKEND_DIR/src/modules/analytics"

# --- Schema ---
cat << 'TS' > "$BACKEND_DIR/src/modules/analytics/event-log.schema.ts"
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type EventLogDocument = HydratedDocument<EventLog>;

@Schema({ timestamps: true })
export class EventLog {
  @Prop({ required: true })
  userId: string;

  @Prop({ required: true })
  action: string; // 'login', 'purchase', 'view_feed'

  @Prop({ type: Object })
  metadata: any;
}

export const EventLogSchema = SchemaFactory.createForClass(EventLog);
TS

# --- Service ---
cat << 'TS' > "$BACKEND_DIR/src/modules/analytics/analytics.service.ts"
import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { EventLog } from './event-log.schema';

@Injectable()
export class AnalyticsService {
  constructor(@InjectModel(EventLog.name) private eventModel: Model<EventLog>) {}

  async logEvent(userId: string, action: string, metadata: any = {}) {
    const createdEvent = new this.eventModel({ userId, action, metadata });
    return createdEvent.save();
  }

  async getStats() {
    return this.eventModel.find().sort({ createdAt: -1 }).limit(50).exec();
  }
}
TS

# --- Module ---
cat << 'TS' > "$BACKEND_DIR/src/modules/analytics/analytics.module.ts"
import { Module, Global } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { EventLog, EventLogSchema } from './event-log.schema';
import { AnalyticsService } from './analytics.service';

@Global() // Make analytics available everywhere
@Module({
  imports: [
    MongooseModule.forFeature([{ name: EventLog.name, schema: EventLogSchema }])
  ],
  providers: [AnalyticsService],
  exports: [AnalyticsService]
})
export class AnalyticsModule {}
TS

# --- Update App Module (Wire Everything Up) ---
cat << 'TS' > "$BACKEND_DIR/src/app.module.ts"
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
TS

echo ">>> UPGRADE SCRIPT COMPLETE."
chmod +x implement_roadmap.sh
