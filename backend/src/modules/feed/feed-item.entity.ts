import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('feed_items')
export class FeedItem {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  type: string; // 'news', 'event'

  @Column()
  title: string;

  @Column()
  body: string;

  @Column({ nullable: true })
  venueId: string;

  @CreateDateColumn()
  createdAt: Date;
}
