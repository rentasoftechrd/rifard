const TIMEZONE = 'America/Santo_Domingo';

/**
 * Format a date for ticket display in America/Santo_Domingo.
 * - date: DD/MM/YYYY
 * - time: h:mm AM/PM
 */
export function formatTicketDateAndTime(utcDate: Date): { date: string; time: string } {
  const dateFormatted = new Intl.DateTimeFormat('en-GB', {
    timeZone: TIMEZONE,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(utcDate);
  // en-GB gives DD/MM/YYYY
  const timeFormatted = new Intl.DateTimeFormat('en-US', {
    timeZone: TIMEZONE,
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  }).format(utcDate);
  return { date: dateFormatted, time: timeFormatted };
}

/**
 * Build QR URL for a ticket number (configurable base URL).
 * Example: base https://dominio.com → https://dominio.com/t/2026070300001
 */
export function getTicketQrUrl(ticketNumber: string): string {
  const base = (process.env.TICKET_QR_BASE_URL ?? 'https://ejemplo.com').replace(/\/$/, '');
  return `${base}/t/${ticketNumber}`;
}
