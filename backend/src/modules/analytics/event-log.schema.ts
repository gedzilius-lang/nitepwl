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
