import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  const config = new DocumentBuilder()
    .setTitle('Rifard Loteria API')
    .setDescription('Backend API for Dominican lottery backoffice and POS')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const corsOrigins = (process.env.CORS_ORIGINS?.split(',') ?? []).map((s) => s.trim()).filter(Boolean);
  const isDev = process.env.NODE_ENV !== 'production';
  app.enableCors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      const fromLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
      if (isDev && fromLocalhost) return callback(null, true);
      if (corsOrigins.length === 0) return callback(null, true);
      if (corsOrigins.includes(origin)) return callback(null, true);
      callback(new Error('CORS not allowed'));
    },
    credentials: true,
  });

  const port = process.env.PORT ?? 3000;
  const host = process.env.HOST ?? '0.0.0.0';
  await app.listen(port, host);
  console.log(`Application is running on: http://${host}:${port}/api/v1`);
  console.log(`POS conexión (público): GET http://<IP>:${port}/api/v1/health/pos-connect`);
  console.log(`Swagger: http://localhost:${port}/api/docs`);
}
bootstrap();
