/**
 * Reglas de números para lotería dominicana:
 * - Números del 1 al 100.
 * - El 100 se representa como "00" (dos dígitos).
 * - Del 1 al 9 se representan con cero a la izquierda: "01", "02", ..., "09".
 * - No se permiten números fuera de 1-100 (ni "101", ni más de 2 dígitos salvo "00").
 */

/** Convierte un valor (1-100 o "00","01",...,"99") a formato de 2 dígitos: "01"-"99" o "00" para 100. */
export function normalizeLotteryNumber(value: string | number): string {
  const s = String(value).trim();
  if (s === '' || s === '00') return '00'; // 100
  const n = parseInt(s, 10);
  if (Number.isNaN(n) || n < 1 || n > 100) return s; // invalid, caller will validate
  if (n === 100) return '00';
  return n >= 1 && n <= 9 ? `0${n}` : String(n);
}

/** Valida que un string sea un número válido (1-100 o "00","01"-"99"). Devuelve el normalizado o lanza. */
export function validateAndNormalizeOne(num: string): string {
  const s = num.trim();
  if (s === '00') return '00';
  const n = parseInt(s, 10);
  if (Number.isNaN(n) || n < 1 || n > 99) {
    throw new Error(`Número inválido: "${num}". Solo se permiten 1-100 (00 = 100, 01-09 con cero a la izquierda).`);
  }
  return n >= 1 && n <= 9 ? `0${n}` : String(n);
}

/** Valida y normaliza una cadena de números separados por espacio (ej. "12 34" para palé). Cada parte 1-100. */
export function validateAndNormalizeNumbers(numbers: string, betType: string): string {
  const parts = numbers.trim().split(/\s+/).filter(Boolean);
  const required = betType === 'quiniela' ? 1 : betType === 'pale' ? 2 : betType === 'tripleta' ? 3 : betType === 'superpale' ? 3 : 1;
  if (parts.length !== required) {
    throw new Error(`Se requieren ${required} número(s) para ${betType}.`);
  }
  const normalized = parts.map((p) => validateAndNormalizeOne(p));
  return normalized.join(' ');
}
