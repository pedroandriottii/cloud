import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Request } from 'express';

@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly limit = 5;
  private readonly windowMs = 60_000;
  private readonly requestLog = new Map<string, number[]>();

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const key = this.resolveKey(request);
    const now = Date.now();
    const timestamps = (this.requestLog.get(key) ?? []).filter(
      (timestamp) => now - timestamp < this.windowMs,
    );

    if (timestamps.length >= this.limit) {
      throw new HttpException(
        'Limite de 5 solicitações por minuto atingido para esta origem.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    timestamps.push(now);
    this.requestLog.set(key, timestamps);

    return true;
  }

  private resolveKey(request: Request) {
    const forwarded = request.headers['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.length > 0) {
      return forwarded.split(',')[0].trim();
    }

    if (Array.isArray(forwarded) && forwarded.length > 0) {
      return forwarded[0];
    }

    return (
      request.ip ||
      request.socket?.remoteAddress ||
      request.headers.origin ||
      'anonymous'
    );
  }
}
