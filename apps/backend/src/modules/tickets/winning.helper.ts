import { BetType } from '@prisma/client';

/** Resultados aprobados de un sorteo: primera, segunda, tercera (números 01-99 o 00). */
export interface DrawResultsApproved {
  primera: string;
  segunda: string;
  tercera: string;
}

/** Normaliza número para comparación (01, 02, ..., 00). */
function n(s: string): string {
  const t = String(s).trim();
  if (t === '' || t === '0') return '00';
  const num = parseInt(t, 10);
  if (Number.isNaN(num) || num < 1 || num > 100) return t;
  return num === 100 ? '00' : num >= 1 && num <= 9 ? `0${num}` : String(num);
}

/**
 * Indica si una línea de ticket gana según los resultados aprobados del sorteo.
 * Quiniela: un número que coincida con 1ra, 2da o 3ra.
 * Palé: dos números que coincidan con dos de los tres (cualquier orden).
 * Tripleta: tres números en orden 1ra, 2da, 3ra.
 * Superpalé: tres números que coincidan con los tres en cualquier orden.
 */
export function isLineWinner(
  betType: BetType,
  numbers: string,
  results: DrawResultsApproved,
): boolean {
  const parts = numbers.trim().split(/\s+/).filter(Boolean).map(n);
  const P = n(results.primera);
  const S = n(results.segunda);
  const T = n(results.tercera);
  const setResults = new Set([P, S, T]);

  switch (betType) {
    case 'quiniela':
      return parts.length >= 1 && (parts[0] === P || parts[0] === S || parts[0] === T);
    case 'pale':
      if (parts.length < 2) return false;
      const [a, b] = parts;
      return (
        (a === P && b === S) || (a === S && b === P) ||
        (a === P && b === T) || (a === T && b === P) ||
        (a === S && b === T) || (a === T && b === S)
      );
    case 'tripleta':
      return parts.length >= 3 && parts[0] === P && parts[1] === S && parts[2] === T;
    case 'superpale':
      if (parts.length < 3) return false;
      return setResults.has(parts[0]) && setResults.has(parts[1]) && setResults.has(parts[2]) &&
        new Set(parts).size === 3;
    default:
      return false;
  }
}
