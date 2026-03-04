import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as argon2 from 'argon2';
import { createHash } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';

export interface LoginDto {
  email?: string;
  phone?: string;
  password: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  async validateUser(identifier: string, password: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        active: true,
        OR: [{ email: identifier }, { phone: identifier }],
      },
      include: { userRoles: { include: { role: true } } },
    });
    if (!user || !(await argon2.verify(user.passwordHash, password))) return null;
    return user;
  }

  async login(dto: LoginDto): Promise<TokenPair> {
    const identifier = dto.email ?? dto.phone;
    if (!identifier || !dto.password) throw new UnauthorizedException('Email/phone and password required');
    const user = await this.validateUser(identifier, dto.password);
    if (!user) throw new UnauthorizedException('Invalid credentials');
    return this.issueTokens(user);
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const payload = this.jwt.decode(refreshToken) as { sub?: string; type?: string } | null;
    if (!payload?.sub || payload.type !== 'refresh') throw new UnauthorizedException('Invalid refresh token');
    const tokenHash = this.hashRefreshToken(refreshToken);
    const stored = await this.prisma.refreshToken.findFirst({
      where: { userId: payload.sub, tokenHash, expiresAt: { gt: new Date() } },
      include: { user: { include: { userRoles: { include: { role: true } } } } },
    });
    if (!stored) throw new UnauthorizedException('Refresh token expired or invalid');
    await this.prisma.refreshToken.delete({ where: { id: stored.id } });
    return this.issueTokens(stored.user);
  }

  private async issueTokens(user: { id: string; email: string; userRoles: { role: { code: string } }[] }): Promise<TokenPair> {
    const expiresIn = 900; // 15m in seconds
    const accessToken = this.jwt.sign(
      { sub: user.id, email: user.email, type: 'access', roles: user.userRoles.map((ur) => ur.role.code) },
      { expiresIn },
    );
    const refreshExpires = this.config.get<string>('REFRESH_EXPIRES_IN', '7d');
    const refreshSeconds = refreshExpires.endsWith('d') ? parseInt(refreshExpires, 10) * 86400 : 604800;
    const refreshToken = this.jwt.sign(
      { sub: user.id, type: 'refresh' },
      { secret: this.config.get('REFRESH_SECRET'), expiresIn: refreshSeconds },
    );
    const tokenHash = this.hashRefreshToken(refreshToken);
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt: new Date(Date.now() + refreshSeconds * 1000),
      },
    });
    return { accessToken, refreshToken, expiresIn };
  }

  private hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId, active: true },
      select: {
        id: true,
        email: true,
        phone: true,
        fullName: true,
        active: true,
        userRoles: { include: { role: { select: { code: true, name: true } } } },
      },
    });
    if (!user) throw new UnauthorizedException('User not found');
    return user;
  }
}
