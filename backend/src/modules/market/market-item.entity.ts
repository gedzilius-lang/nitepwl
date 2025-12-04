import { Entity, Column, PrimaryGeneratedColumn } from 'typeorm';

@Entity('market_items')
export class MarketItem {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  title: string;

  @Column({ type: 'int' })
  priceNite: number;

  @Column({ type: 'int', default: 1 })
  venueId: number;
}
