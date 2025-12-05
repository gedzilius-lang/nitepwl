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
