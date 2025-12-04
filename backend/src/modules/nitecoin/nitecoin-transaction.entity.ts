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
