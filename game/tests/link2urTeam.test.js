import { describe, test, expect } from 'vitest';
import {
  LINK2UR_TEAM_MEMBERS,
  getMiniArcScene,
} from '../src/data/link2urTeam.js';

describe('5 个可招团员 NPC', () => {
  test('恰好 5 个', () => {
    expect(LINK2UR_TEAM_MEMBERS.length).toBe(5);
  });

  test('5 个专精全覆盖 AI 广告分工', () => {
    const specialties = LINK2UR_TEAM_MEMBERS.map((m) => m.specialty);
    expect(specialties).toContain('ai_copywriting_bilingual');
    expect(specialties).toContain('ai_video_generation');
    expect(specialties).toContain('ads_strategy_data');
    expect(specialties).toContain('account_management');
    expect(specialties).toContain('ai_visual_design');
  });

  test('每个团员有 4 个 mini-arc 场景', () => {
    for (const m of LINK2UR_TEAM_MEMBERS) {
      expect(m.miniArc.length).toBe(4);
      for (const a of m.miniArc) {
        expect(['recruited', 'mentored', 'clash', 'departure']).toContain(a.phase);
        expect(a.body).toBeTruthy();
      }
    }
  });

  test('Eric 标记需要王凯介绍', () => {
    const eric = LINK2UR_TEAM_MEMBERS.find((m) => m.id === 'team_eric');
    expect(eric.recruitedVia).toBe('wangkai_referral');
  });

  test('getMiniArcScene 按 phase 取场景', () => {
    const scene = getMiniArcScene('team_xiaoyu', 'recruited');
    expect(scene).toBeTruthy();
    expect(scene.body).toBeTruthy();
  });
});
