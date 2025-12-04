import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ length: 120, unique: true })
  email!: string;

  @CreateDateColumn()
  createdAt!: Date;
}
