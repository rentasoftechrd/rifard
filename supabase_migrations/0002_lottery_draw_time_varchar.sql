-- Evitar problemas de serialización Prisma/Node con tipo TIME.
-- draw_time como VARCHAR(10) almacena 'HH24:MI:SS' (ej. 15:00:00).
ALTER TABLE lottery_draw_times
  ALTER COLUMN draw_time TYPE VARCHAR(10)
  USING to_char(draw_time, 'HH24:MI:SS');
