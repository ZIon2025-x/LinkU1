import { londonLocalToUtcIso } from './londonTime';

describe('londonLocalToUtcIso', () => {
  // April: BST is in effect (+1 hour). London 14:30 = UTC 13:30.
  test('BST: April 14:30 London = 13:30 UTC', () => {
    expect(londonLocalToUtcIso('2026-04-08', '14:30')).toBe('2026-04-08T13:30:00.000Z');
  });

  // January: GMT (+0). London 14:30 = UTC 14:30.
  test('GMT: January 14:30 London = 14:30 UTC', () => {
    expect(londonLocalToUtcIso('2026-01-15', '14:30')).toBe('2026-01-15T14:30:00.000Z');
  });

  // Spring forward 2026 — Europe/London switches to BST at 2026-03-29 01:00 UTC
  // (= 02:00 local jumps to 03:00). 09:00 on the morning of the change is BST.
  test('DST spring-forward day morning is BST', () => {
    expect(londonLocalToUtcIso('2026-03-29', '09:00')).toBe('2026-03-29T08:00:00.000Z');
  });

  // Day before spring-forward is still GMT.
  test('Day before spring-forward is GMT', () => {
    expect(londonLocalToUtcIso('2026-03-28', '12:00')).toBe('2026-03-28T12:00:00.000Z');
  });

  // Fall back 2026 — Europe/London returns to GMT at 2026-10-25 01:00 UTC
  // (= 02:00 BST drops to 01:00 GMT). Morning of change is GMT.
  test('DST fall-back day afternoon is GMT', () => {
    expect(londonLocalToUtcIso('2026-10-25', '14:00')).toBe('2026-10-25T14:00:00.000Z');
  });

  // Day before fall-back is still BST.
  test('Day before fall-back is BST', () => {
    expect(londonLocalToUtcIso('2026-10-24', '14:00')).toBe('2026-10-24T13:00:00.000Z');
  });

  // Accepts HH:MM:SS format
  test('Accepts HH:MM:SS format', () => {
    expect(londonLocalToUtcIso('2026-04-08', '14:30:45')).toBe('2026-04-08T13:30:45.000Z');
  });

  // Midnight in BST
  test('Midnight in BST', () => {
    expect(londonLocalToUtcIso('2026-06-15', '00:00')).toBe('2026-06-14T23:00:00.000Z');
  });
});
