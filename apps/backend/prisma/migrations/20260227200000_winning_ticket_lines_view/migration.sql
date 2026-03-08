-- Vista: líneas de tickets que pertenecen a sorteos con resultados aprobados.
-- Permite listar todos los candidatos a ganador por fecha/lotería y calcular el monto en el backend.
-- Run in Supabase SQL Editor if using PgBouncer.

CREATE OR REPLACE VIEW v_winning_ticket_lines AS
SELECT
  t.id AS ticket_id,
  t.ticket_code,
  t.ticket_number,
  t.status AS ticket_status,
  t.total_amount,
  t.created_at AS ticket_created_at,
  t.paid_at,
  t.point_id,
  t.seller_user_id,
  tl.id AS line_id,
  tl.draw_id,
  tl.lottery_id,
  tl.bet_type,
  tl.numbers,
  tl.amount,
  tl.potential_payout,
  d.draw_date,
  d.draw_time,
  l.name AS lottery_name,
  (dr.results->>'primera') AS result_primera,
  (dr.results->>'segunda') AS result_segunda,
  (dr.results->>'tercera') AS result_tercera
FROM ticket_lines tl
JOIN draws d ON d.id = tl.draw_id
JOIN draw_results dr ON dr.draw_id = d.id AND dr.status = 'approved'
JOIN tickets t ON t.id = tl.ticket_id AND t.status != 'voided'
JOIN lotteries l ON l.id = tl.lottery_id;
