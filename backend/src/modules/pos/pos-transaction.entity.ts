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
