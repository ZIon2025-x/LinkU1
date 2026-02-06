/**
 * 输入验证工具函数测试
 */

import {
  validateEmail,
  validateName,
  validatePhone,
  validateUrl,
  sanitizeInput,
  validateLength,
  validateTaskTitle,
  validateTaskDescription,
  validatePostTitle,
  validatePostContent,
  validatePrice,
  combineValidators
} from './inputValidators';

describe('输入验证工具函数', () => {
  describe('validateEmail', () => {
    test('有效邮箱应该通过验证', () => {
      expect(validateEmail('test@example.com')).toEqual({ valid: true });
      expect(validateEmail('user.name@domain.co.uk')).toEqual({ valid: true });
      expect(validateEmail('user+tag@gmail.com')).toEqual({ valid: true });
    });

    test('空邮箱应该失败', () => {
      expect(validateEmail('')).toEqual({ valid: false, message: '邮箱不能为空' });
      expect(validateEmail('   ')).toEqual({ valid: false, message: '邮箱不能为空' });
    });

    test('无效邮箱格式应该失败', () => {
      expect(validateEmail('notanemail')).toEqual({ valid: false, message: '邮箱格式不正确' });
      expect(validateEmail('missing@domain')).toEqual({ valid: false, message: '邮箱格式不正确' });
      expect(validateEmail('@nodomain.com')).toEqual({ valid: false, message: '邮箱格式不正确' });
    });

    test('超长邮箱应该失败', () => {
      const longEmail = 'a'.repeat(250) + '@test.com';
      expect(validateEmail(longEmail)).toEqual({ valid: false, message: '邮箱长度不能超过255个字符' });
    });
  });

  describe('validateName', () => {
    test('有效姓名应该通过验证', () => {
      expect(validateName('张三')).toEqual({ valid: true });
      expect(validateName('John Doe')).toEqual({ valid: true });
      expect(validateName('李四五')).toEqual({ valid: true });
    });

    test('空姓名应该失败', () => {
      expect(validateName('')).toEqual({ valid: false, message: '姓名不能为空' });
      expect(validateName('   ')).toEqual({ valid: false, message: '姓名不能为空' });
    });

    test('太短的姓名应该失败', () => {
      expect(validateName('A')).toEqual({ valid: false, message: '姓名至少需要2个字符' });
    });

    test('太长的姓名应该失败', () => {
      const longName = 'A'.repeat(51);
      expect(validateName(longName)).toEqual({ valid: false, message: '姓名不能超过50个字符' });
    });

    test('包含HTML标签应该失败', () => {
      expect(validateName('<script>alert(1)</script>')).toEqual({ valid: false, message: '姓名不能包含HTML标签' });
      expect(validateName('John<b>Doe</b>')).toEqual({ valid: false, message: '姓名不能包含HTML标签' });
    });

    test('包含危险字符应该失败', () => {
      expect(validateName('John"Doe')).toEqual({ valid: false, message: '姓名包含不允许的字符' });
      expect(validateName("John'Doe")).toEqual({ valid: false, message: '姓名包含不允许的字符' });
    });
  });

  describe('validatePhone', () => {
    test('有效手机号应该通过验证', () => {
      expect(validatePhone('13800138000')).toEqual({ valid: true });
      expect(validatePhone('+8613800138000')).toEqual({ valid: true });
      expect(validatePhone('+44 7911 123456')).toEqual({ valid: true });
    });

    test('空手机号应该失败', () => {
      expect(validatePhone('')).toEqual({ valid: false, message: '手机号不能为空' });
    });

    test('包含非法字符应该失败', () => {
      expect(validatePhone('138abc')).toEqual({ valid: false, message: '手机号格式不正确' });
    });

    test('太短的手机号应该失败', () => {
      expect(validatePhone('123456')).toEqual({ valid: false, message: '手机号长度不正确（7-15位）' });
    });

    test('太长的手机号应该失败', () => {
      expect(validatePhone('1234567890123456')).toEqual({ valid: false, message: '手机号长度不正确（7-15位）' });
    });
  });

  describe('validateUrl', () => {
    test('有效URL应该通过验证', () => {
      expect(validateUrl('https://example.com')).toEqual({ valid: true });
      expect(validateUrl('http://example.com/path?query=1')).toEqual({ valid: true });
      expect(validateUrl('https://sub.domain.com:8080/path')).toEqual({ valid: true });
    });

    test('空URL应该失败', () => {
      expect(validateUrl('')).toEqual({ valid: false, message: 'URL不能为空' });
    });

    test('无效URL格式应该失败', () => {
      expect(validateUrl('not-a-url')).toEqual({ valid: false, message: 'URL格式不正确' });
      expect(validateUrl('ftp://example.com')).toEqual({ valid: false, message: '只支持HTTP和HTTPS协议' });
    });

    test('非HTTP/HTTPS协议应该失败', () => {
      expect(validateUrl('javascript:alert(1)')).toEqual({ valid: false, message: '只支持HTTP和HTTPS协议' });
      expect(validateUrl('file:///etc/passwd')).toEqual({ valid: false, message: '只支持HTTP和HTTPS协议' });
    });
  });

  describe('sanitizeInput', () => {
    test('移除HTML标签', () => {
      expect(sanitizeInput('<script>alert(1)</script>')).toBe('alert(1)');
      expect(sanitizeInput('<b>Bold</b> text')).toBe('Bold text');
    });

    test('转义特殊字符', () => {
      // 注意：sanitizeInput 先移除 HTML 标签，所以 < > 会被当作标签的一部分处理
      // 测试不包含标签样式的特殊字符
      expect(sanitizeInput('"quoted"')).toBe('&quot;quoted&quot;');
      expect(sanitizeInput("it's")).toBe('it&#x27;s');
      expect(sanitizeInput('a & b')).toBe('a &amp; b');
    });

    test('处理空输入', () => {
      expect(sanitizeInput('')).toBe('');
      expect(sanitizeInput(null as any)).toBe('');
    });

    test('修剪空白', () => {
      expect(sanitizeInput('  hello  ')).toBe('hello');
    });
  });

  describe('validateLength', () => {
    test('长度在范围内应该通过', () => {
      expect(validateLength('hello', 1, 10)).toEqual({ valid: true });
      expect(validateLength('ab', 2, 5)).toEqual({ valid: true });
    });

    test('太短应该失败', () => {
      expect(validateLength('a', 5, 10, '标题')).toEqual({ valid: false, message: '标题至少需要5个字符' });
    });

    test('太长应该失败', () => {
      expect(validateLength('a'.repeat(20), 5, 10, '标题')).toEqual({ valid: false, message: '标题不能超过10个字符' });
    });

    test('空文本应该失败', () => {
      expect(validateLength('', 1, 10, '内容')).toEqual({ valid: false, message: '内容不能为空' });
    });
  });

  describe('validateTaskTitle', () => {
    test('有效任务标题应该通过', () => {
      expect(validateTaskTitle('帮我买杯咖啡')).toEqual({ valid: true });
      expect(validateTaskTitle('需要帮忙搬家，时间紧急')).toEqual({ valid: true });
    });

    test('太短的任务标题应该失败', () => {
      expect(validateTaskTitle('帮忙')).toEqual({ valid: false, message: '任务标题至少需要5个字符' });
    });
  });

  describe('validateTaskDescription', () => {
    test('有效任务描述应该通过', () => {
      expect(validateTaskDescription('这是一个详细的任务描述，说明了具体需求')).toEqual({ valid: true });
    });

    test('太短的任务描述应该失败', () => {
      expect(validateTaskDescription('短描述')).toEqual({ valid: false, message: '任务描述至少需要10个字符' });
    });
  });

  describe('validatePostTitle', () => {
    test('有效帖子标题应该通过', () => {
      expect(validatePostTitle('求推荐好吃的餐厅')).toEqual({ valid: true });
    });

    test('太短的帖子标题应该失败', () => {
      expect(validatePostTitle('求推')).toEqual({ valid: false, message: '帖子标题至少需要5个字符' });
    });
  });

  describe('validatePostContent', () => {
    test('有效帖子内容应该通过', () => {
      expect(validatePostContent('这是一个详细的帖子内容，分享了很多有用的信息')).toEqual({ valid: true });
    });

    test('太短的帖子内容应该失败', () => {
      expect(validatePostContent('短内容')).toEqual({ valid: false, message: '帖子内容至少需要10个字符' });
    });
  });

  describe('validatePrice', () => {
    test('有效价格应该通过', () => {
      expect(validatePrice(100)).toEqual({ valid: true });
      expect(validatePrice('50.5')).toEqual({ valid: true });
      expect(validatePrice(0)).toEqual({ valid: true });
    });

    test('负数价格应该失败', () => {
      expect(validatePrice(-10)).toEqual({ valid: false, message: '价格不能为负数' });
    });

    test('超大价格应该失败', () => {
      expect(validatePrice(1000001)).toEqual({ valid: false, message: '价格不能超过1,000,000' });
    });

    test('非数字应该失败', () => {
      expect(validatePrice('abc')).toEqual({ valid: false, message: '价格必须是数字' });
    });
  });

  describe('combineValidators', () => {
    test('所有验证通过时返回成功', () => {
      const validator = combineValidators(
        (v) => validateLength(v, 5, 100),
        (v) => validateName(v)
      );
      expect(validator('Valid Name')).toEqual({ valid: true });
    });

    test('第一个验证失败时返回错误', () => {
      const validator = combineValidators(
        (v) => validateLength(v, 10, 100),
        (v) => validateName(v)
      );
      const result = validator('Short');
      expect(result.valid).toBe(false);
    });
  });
});
