import { describe, test, expect } from 'vitest';
import { ACADEMIC_CALENDAR, getWeekInfo, TOTAL_DAYS } from '../src/data/calendar.js';

describe('academic calendar', () => {
  test('covers exactly 52 weeks', () => {
    expect(ACADEMIC_CALENDAR.length).toBe(52);
    expect(ACADEMIC_CALENDAR[0].week).toBe(1);
    expect(ACADEMIC_CALENDAR[51].week).toBe(52);
  });

  test('TOTAL_DAYS = 364 (52 weeks)', () => {
    expect(TOTAL_DAYS).toBe(364);
  });

  test('getWeekInfo returns correct week', () => {
    expect(getWeekInfo(1).type).toBe('welcome');
    expect(getWeekInfo(7).type).toBe('reading');
    expect(getWeekInfo(13).isHoliday).toBe(true);
    expect(getWeekInfo(34).isExam).toBe(true);
    expect(getWeekInfo(52).deadline).toBe('dissertation');
  });

  test('getWeekInfo clamps out-of-range to last entry', () => {
    expect(getWeekInfo(99).week).toBe(52);
    expect(getWeekInfo(0).week).toBe(52);  // not in array, falls back to last
  });

  test('all reading weeks are non-required', () => {
    const reading = ACADEMIC_CALENDAR.filter(w => w.type === 'reading');
    expect(reading.length).toBeGreaterThan(0);
    reading.forEach(w => expect(w.requireClass).toBe(false));
  });

  test('there are exactly 3 exam weeks numbered 1-3', () => {
    const exams = ACADEMIC_CALENDAR.filter(w => w.isExam);
    expect(exams.length).toBe(3);
    expect(exams.map(e => e.examNumber).sort()).toEqual([1, 2, 3]);
  });
});
