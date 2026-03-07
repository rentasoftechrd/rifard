import { PrismaService } from '../../prisma/prisma.service';

const VOID_WINDOW_MINUTES = parseInt(process.env.VOID_WINDOW_MINUTES ?? '5', 10) || 5;

export async function getDrawCloseAndDrawAt(
  prisma: PrismaService,
  drawId: string,
  timezone: string,
): Promise<{ drawCloseAt: Date; drawAt: Date; closeMinutesBefore: number }> {
  const draw = await prisma.draw.findUniqueOrThrow({
    where: { id: drawId },
    include: { lottery: { include: { drawTimes: { where: { active: true } } } } },
  });
  const drawTimeRow = draw.lottery.drawTimes.find((dt) => dt.drawTime === draw.drawTime);
  const closeMinutesBefore = drawTimeRow?.closeMinutesBefore ?? 0;
  // draw_date is Date (day), draw_time is string "HH:mm:ss". Build local datetime then interpret as timezone.
  const dateStr = draw.drawDate instanceof Date ? draw.drawDate.toISOString().slice(0, 10) : String(draw.drawDate).slice(0, 10);
  const timePart = draw.drawTime.slice(0, 8);
  const tzOffset = timezone === 'America/Santo_Domingo' ? '-04:00' : '+00:00';
  const drawAt = new Date(`${dateStr}T${timePart}${tzOffset}`);
  const drawCloseAt = new Date(drawAt.getTime() - closeMinutesBefore * 60 * 1000);
  return { drawCloseAt, drawAt, closeMinutesBefore };
}

/**
 * @param soldAt - ticket creation/sale time (server); void window is from this time
 * @param printedAt - required (ticket must be printed before void)
 */
export function canVoid(soldAt: Date, printedAt: Date | null, now: Date, drawCloseAt: Date, drawAt: Date): { ok: boolean; code?: string } {
  if (!printedAt) return { ok: false, code: 'TICKET_NOT_PRINTED' };
  const elapsedMs = now.getTime() - soldAt.getTime();
  if (elapsedMs > VOID_WINDOW_MINUTES * 60 * 1000) return { ok: false, code: 'VOID_WINDOW_EXPIRED' };
  if (now >= drawCloseAt) return { ok: false, code: 'DRAW_ALREADY_CLOSED' };
  if (now >= drawAt) return { ok: false, code: 'DRAW_ALREADY_HELD' };
  return { ok: true };
}
