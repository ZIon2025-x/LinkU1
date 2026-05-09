import { describe, test, expect } from 'vitest';
import { pronounize, pronounizeEvent } from '../src/engine/pronouns.js';

describe('pronounize · core substitutions', () => {
  test('null gender → no change', () => {
    expect(pronounize('他 / 她 走过来', null)).toBe('他 / 她 走过来');
    expect(pronounize('学弟/学妹', null)).toBe('学弟/学妹');
  });

  test('male picks left side of all paired terms', () => {
    expect(pronounize('他 / 她', 'male')).toBe('他');
    expect(pronounize('学弟 / 学妹', 'male')).toBe('学弟');
    expect(pronounize('学弟/学妹', 'male')).toBe('学弟');
    expect(pronounize('男生 / 女生', 'male')).toBe('男生');
    expect(pronounize('男朋友 / 女朋友', 'male')).toBe('男朋友');
    expect(pronounize('儿子 / 女儿', 'male')).toBe('儿子');
    expect(pronounize('哥们 / 姐们', 'male')).toBe('哥们');
    expect(pronounize('哥 / 姐', 'male')).toBe('哥');
    expect(pronounize('男孩子 / 女孩子', 'male')).toBe('男孩子');
    expect(pronounize('侄子 / 侄女', 'male')).toBe('侄子');
    expect(pronounize('学长 / 学姐', 'male')).toBe('学长');
  });

  test('partner name placeholder picks opposite-gender name', () => {
    // 林可儿 (女) / 林楠 (男) — male player gets the female partner name
    expect(pronounize('林可儿 / 林楠', 'male')).toBe('林可儿');
    expect(pronounize('林可儿 / 林楠', 'female')).toBe('林楠');
    expect(pronounize('你和林可儿 / 林楠在 South Bank 接吻', 'male')).toBe('你和林可儿在 South Bank 接吻');
    expect(pronounize('你和林可儿 / 林楠在 South Bank 接吻', 'female')).toBe('你和林楠在 South Bank 接吻');
  });

  test('female picks right side of all paired terms', () => {
    expect(pronounize('他 / 她', 'female')).toBe('她');
    expect(pronounize('学弟 / 学妹', 'female')).toBe('学妹');
    expect(pronounize('学弟/学妹', 'female')).toBe('学妹');
    expect(pronounize('男生 / 女生', 'female')).toBe('女生');
    expect(pronounize('男朋友 / 女朋友', 'female')).toBe('女朋友');
    expect(pronounize('儿子 / 女儿', 'female')).toBe('女儿');
    expect(pronounize('哥们 / 姐们', 'female')).toBe('姐们');
    expect(pronounize('哥 / 姐', 'female')).toBe('姐');
    expect(pronounize('男孩子 / 女孩子', 'female')).toBe('女孩子');
    expect(pronounize('侄子 / 侄女', 'female')).toBe('侄女');
    expect(pronounize('学长 / 学姐', 'female')).toBe('学姐');
  });

  test('handles multiple pairs in one sentence', () => {
    expect(pronounize('他 / 她 是学弟 / 学妹', 'male')).toBe('他 是学弟');
    expect(pronounize('他 / 她 是学弟 / 学妹', 'female')).toBe('她 是学妹');
  });

  test('handles real-world body text', () => {
    const text = '一个戴眼镜的男生 / 女生主动转过头："学弟/学妹？我看你像第一年的。"';
    expect(pronounize(text, 'male')).toBe('一个戴眼镜的男生主动转过头："学弟？我看你像第一年的。"');
    expect(pronounize(text, 'female')).toBe('一个戴眼镜的女生主动转过头："学妹？我看你像第一年的。"');
  });

  test('safe on empty/null/non-string input', () => {
    expect(pronounize('', 'male')).toBe('');
    expect(pronounize(null, 'male')).toBe(null);
    expect(pronounize(undefined, 'male')).toBe(undefined);
    expect(pronounize(123, 'male')).toBe(123);
  });

  test('pass-through for text without slashes', () => {
    expect(pronounize('你今天去 Tesco 买黄标', 'male')).toBe('你今天去 Tesco 买黄标');
    expect(pronounize('Sarah 在 Pub 等你', 'female')).toBe('Sarah 在 Pub 等你');
  });
});

describe('pronounizeEvent · object-shape passthrough', () => {
  test('processes title / body / feedback / choices in event shape', () => {
    const ev = {
      id: 'x',
      title: '@Lily 看到学弟 / 学妹',
      body: '凌晨 1 点。他 / 她 给你视频电话。',
      feedback: '你说"我也喜欢你 男朋友 / 女朋友"',
      choices: [
        { label: '"是我！" 学弟 / 学妹', feedback: '他 / 她 笑了' },
        { label: '"不是" hhh', feedback: 'Lily 没追' },
      ],
    };
    const male = pronounizeEvent(ev, 'male');
    expect(male.title).toBe('@Lily 看到学弟');
    expect(male.body).toBe('凌晨 1 点。他 给你视频电话。');
    expect(male.feedback).toBe('你说"我也喜欢你 男朋友"');
    expect(male.choices[0].label).toBe('"是我！" 学弟');
    expect(male.choices[0].feedback).toBe('他 笑了');
    expect(male.choices[1].label).toBe('"不是" hhh');  // unchanged

    const female = pronounizeEvent(ev, 'female');
    expect(female.title).toBe('@Lily 看到学妹');
    expect(female.body).toBe('凌晨 1 点。她 给你视频电话。');
    expect(female.feedback).toBe('你说"我也喜欢你 女朋友"');
    expect(female.choices[0].label).toBe('"是我！" 学妹');
    expect(female.choices[0].feedback).toBe('她 笑了');
  });

  test('null event passes through', () => {
    expect(pronounizeEvent(null, 'male')).toBe(null);
    expect(pronounizeEvent(undefined, 'male')).toBe(undefined);
  });

  test('null gender passes through unchanged', () => {
    const ev = { title: '他 / 她' };
    expect(pronounizeEvent(ev, null)).toBe(ev);
  });
});
