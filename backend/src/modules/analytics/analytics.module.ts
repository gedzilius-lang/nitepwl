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
