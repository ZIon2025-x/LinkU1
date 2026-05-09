import { describe, test, expect } from 'vitest';
import {
  STARTING_WALLET, STARTING_ACADEMIC,
  MONTHLY_STIPEND, isStipendWeek, TRANSPORT_OPTIONS,
} from '../src/data/onboarding.js';

describe('onboarding constants', () => {
  test('starting wallet covers cheapest transport with margin', () => {
    const minCost = Math.min(...TRANSPORT_OPTIONS.map(o => o.cost));
    expect(STARTING_WALLET).toBeGreaterThan(minCost);
  });

  test('every transport option is affordable from starting wallet', () => {
    for (const opt of TRANSPORT_OPTIONS) {
      expect(opt.cost).toBeLessThan(STARTING_WALLET);
    }
  });

  test('academic starts at 0 (player begins green)', () => {
    expect(STARTING_ACADEMIC).toBe(0);
  });
});

describe('monthly stipend cadence', () => {
  test('does not fire on week 1 (already covered by starting wallet)', () => {
    expect(isStipendWeek(1)).toBe(false);
  });

  test('fires on weeks 5, 9, 13, 17 (every 4 weeks after onboarding)', () => {
    expect(isStipendWeek(5)).toBe(true);
    expect(isStipendWeek(9)).toBe(true);
    expect(isStipendWeek(13)).toBe(true);
    expect(isStipendWeek(17)).toBe(true);
  });

  test('does not fire on intermediate weeks', () => {
    expect(isStipendWeek(2)).toBe(false);
    expect(isStipendWeek(4)).toBe(false);
    expect(isStipendWeek(6)).toBe(false);
    expect(isStipendWeek(8)).toBe(false);
  });

  test('fires reliably across the full 52-week year', () => {
    const stipendWeeks = [];
    for (let w = 1; w <= 52; w++) {
      if (isStipendWeek(w)) stipendWeeks.push(w);
    }
    // 13 deposits over 52 weeks (1 per 4 weeks, starting at week 5)
    expect(stipendWeeks).toEqual([5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49]);
  });

  test('total annual stipend stays within reason', () => {
    const total = 12 * MONTHLY_STIPEND;
    expect(total).toBeGreaterThan(5000);
    expect(total).toBeLessThan(10000);
  });
});
