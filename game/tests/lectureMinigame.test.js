// tests/lectureMinigame.test.js
import { describe, it, expect } from 'vitest';
import {
  lectureDirTier,
  lectureDirInfo,
  isLectureAdjacent,
} from '../src/data/lectureMinigame.js';

describe('lectureDirTier', () => {
  it('W1-10 returns tier 1', () => {
    expect(lectureDirTier(1)).toBe(1);
    expect(lectureDirTier(10)).toBe(1);
  });
  it('W11-22 returns tier 2', () => {
    expect(lectureDirTier(11)).toBe(2);
    expect(lectureDirTier(22)).toBe(2);
  });
  it('W23+ returns tier 3', () => {
    expect(lectureDirTier(23)).toBe(3);
    expect(lectureDirTier(40)).toBe(3);
  });
});

describe('lectureDirInfo', () => {
  it('tier 1 only allows horizontal', () => {
    const info = lectureDirInfo(5);
    expect(info.tier).toBe(1);
    expect(info.dirs).toEqual(['h']);
  });
  it('tier 2 allows horizontal + vertical', () => {
    const info = lectureDirInfo(15);
    expect(info.tier).toBe(2);
    expect(info.dirs).toEqual(['h', 'v']);
  });
  it('tier 3 allows all 8 directions', () => {
    const info = lectureDirInfo(30);
    expect(info.tier).toBe(3);
    expect(info.dirs).toEqual(['h', 'v', 'd']);
  });
});

describe('isLectureAdjacent', () => {
  const a = { r: 5, c: 5 };
  it('tier 1 (h only) — horizontal yes, vertical no, diagonal no', () => {
    expect(isLectureAdjacent(a, { r: 5, c: 6 }, ['h'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 5 }, ['h'])).toBe(false);
    expect(isLectureAdjacent(a, { r: 6, c: 6 }, ['h'])).toBe(false);
  });
  it('tier 2 (h+v) — horizontal yes, vertical yes, diagonal no', () => {
    expect(isLectureAdjacent(a, { r: 5, c: 6 }, ['h', 'v'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 5 }, ['h', 'v'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 6 }, ['h', 'v'])).toBe(false);
  });
  it('tier 3 (h+v+d) — all 8 directions allowed', () => {
    expect(isLectureAdjacent(a, { r: 5, c: 6 }, ['h', 'v', 'd'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 5 }, ['h', 'v', 'd'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 6 }, ['h', 'v', 'd'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 4, c: 4 }, ['h', 'v', 'd'])).toBe(true);
  });
  it('rejects same cell, non-adjacent, null', () => {
    expect(isLectureAdjacent(a, { r: 5, c: 5 }, ['h', 'v', 'd'])).toBe(false);
    expect(isLectureAdjacent(a, { r: 7, c: 5 }, ['h', 'v', 'd'])).toBe(false);
    expect(isLectureAdjacent(null, a, ['h', 'v', 'd'])).toBe(false);
    expect(isLectureAdjacent(a, null, ['h', 'v', 'd'])).toBe(false);
  });
});
