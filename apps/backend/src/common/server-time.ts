/**
 * Todas las validaciones de fecha/hora deben usar la hora del servidor (no la del dispositivo)
 * para evitar fraude. Zona horaria fija: República Dominicana (America/Santo_Domingo, UTC-4,
 * sin cambio de horario).
 */

import { BadRequestException } from '@nestjs/common';

/** Zona horaria del banco: República Dominicana (UTC-4, sin daylight saving). */
const TIMEZONE = process.env.BANCO_TIMEZONE ?? 'America/Santo_Domingo';

/** Fecha/hora actual del servidor (usar siempre esto en validaciones, nunca confiar en el cliente). */
export function serverNow(): Date {
  return new Date();
}

/**
 * Fecha "hoy" en la zona horaria del banco (República Dominicana), formato YYYY-MM-DD.
 * No usa UTC para evitar que de madrugada "hoy" cambie respecto a la hora local.
 */
export function serverTodayISO(): string {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = formatter.formatToParts(now);
  const y = parts.find((p) => p.type === 'year')?.value ?? '';
  const m = parts.find((p) => p.type === 'month')?.value ?? '';
  const d = parts.find((p) => p.type === 'day')?.value ?? '';
  return `${y}-${m}-${d}`;
}

/**
 * Valida que la fecha enviada por el cliente no sea futura respecto al servidor.
 * Retorna la fecha a usar (la del cliente si es válida, o la de hoy del servidor si se capa).
 * Si rejectFuture === true, lanza BadRequestException cuando dateStr > hoy servidor.
 */
export function ensureDateNotFuture(dateStr: string, rejectFuture = true): string {
  const today = serverTodayISO();
  if (dateStr > today) {
    if (rejectFuture) {
      throw new BadRequestException(
        `La fecha no puede ser futura. Fecha del servidor: ${today}. Use la fecha/hora del servidor para evitar fraude.`,
      );
    }
    return today;
  }
  return dateStr;
}

export function getTimezone(): string {
  return TIMEZONE;
}

/**
 * Calcula la hora de cierre del sorteo (hasta cuándo se puede vender) en la zona del banco.
 * drawDate: fecha del sorteo; drawTime: "HH:mm:ss"; closeMinutesBefore: minutos antes del sorteo que cierra.
 */
export function getDrawCloseAt(
  drawDate: Date,
  drawTime: string,
  closeMinutesBefore: number,
): Date {
  const dateStr =
    drawDate instanceof Date ? drawDate.toISOString().slice(0, 10) : String(drawDate).slice(0, 10);
  const timePart = String(drawTime).slice(0, 8);
  const tzOffset = TIMEZONE === 'America/Santo_Domingo' ? '-04:00' : '+00:00';
  const drawAt = new Date(`${dateStr}T${timePart}${tzOffset}`);
  return new Date(drawAt.getTime() - closeMinutesBefore * 60 * 1000);
}

/**
 * Hora del servidor formateada para mostrar en UI (DD/MM/YYYY HH:mm en zona del banco).
 */
export function serverTimeDisplay(): string {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('es-DO', {
    timeZone: TIMEZONE,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  return formatter.format(now);
}
