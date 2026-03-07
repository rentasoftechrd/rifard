-- CreateTable: secuencia diaria para ticketNumber (YYYYMMDD + correlativo)
CREATE TABLE IF NOT EXISTS "ticket_daily_sequence" (
    "date" DATE NOT NULL,
    "next_value" INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT "ticket_daily_sequence_pkey" PRIMARY KEY ("date")
);

-- AlterTable: añadir ticket_number a tickets (nullable para tickets existentes)
ALTER TABLE "tickets" ADD COLUMN IF NOT EXISTS "ticket_number" TEXT;

-- CreateIndex: único para ticket_number (permite NULL en PostgreSQL)
CREATE UNIQUE INDEX IF NOT EXISTS "tickets_ticket_number_key" ON "tickets"("ticket_number");
