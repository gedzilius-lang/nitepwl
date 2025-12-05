import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // Prefix all routes with /api
  app.setGlobalPrefix('api');
  
  // Enable Cross-Origin Resource Sharing (for Frontend)
  app.enableCors();
  
  // Force listen on IPv4 (0.0.0.0) to fix WSL connectivity issues
  await app.listen(3000, '0.0.0.0');
  
  console.log('NiteOS v7.1 Backend is live: http://localhost:3000/api');
}
bootstrap();
