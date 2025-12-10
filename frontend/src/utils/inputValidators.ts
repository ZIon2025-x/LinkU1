/**
 * 输入验证工具函数
 * 提供统一的输入验证逻辑，防止XSS和注入攻击
 */

/**
 * 验证邮箱格式
 */
export const validateEmail = (email: string): { valid: boolean; message?: string } => {
  if (!email || email.trim().length === 0) {
    return { valid: false, message: '邮箱不能为空' };
  }
  
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return { valid: false, message: '邮箱格式不正确' };
  }
  
  // 检查长度
  if (email.length > 255) {
    return { valid: false, message: '邮箱长度不能超过255个字符' };
  }
  
  return { valid: true };
};

/**
 * 验证用户名/姓名
 */
export const validateName = (name: string): { valid: boolean; message?: string } => {
  if (!name || name.trim().length === 0) {
    return { valid: false, message: '姓名不能为空' };
  }
  
  const trimmedName = name.trim();
  
  // 检查长度
  if (trimmedName.length < 2) {
    return { valid: false, message: '姓名至少需要2个字符' };
  }
  
  if (trimmedName.length > 50) {
    return { valid: false, message: '姓名不能超过50个字符' };
  }
  
  // 检查是否包含HTML标签（防止XSS）
  if (/<[^>]*>/g.test(trimmedName)) {
    return { valid: false, message: '姓名不能包含HTML标签' };
  }
  
  // 检查是否包含危险字符
  const dangerousChars = /[<>'"&]/;
  if (dangerousChars.test(trimmedName)) {
    return { valid: false, message: '姓名包含不允许的字符' };
  }
  
  return { valid: true };
};

/**
 * 验证手机号（支持国际格式）
 */
export const validatePhone = (phone: string): { valid: boolean; message?: string } => {
  if (!phone || phone.trim().length === 0) {
    return { valid: false, message: '手机号不能为空' };
  }
  
  // 移除空格和连字符
  const cleanedPhone = phone.replace(/[\s-]/g, '');
  
  // 检查是否只包含数字和+号
  if (!/^\+?[0-9]+$/.test(cleanedPhone)) {
    return { valid: false, message: '手机号格式不正确' };
  }
  
  // 检查长度（最少7位，最多15位，包括国家代码）
  if (cleanedPhone.length < 7 || cleanedPhone.length > 15) {
    return { valid: false, message: '手机号长度不正确（7-15位）' };
  }
  
  return { valid: true };
};

/**
 * 验证URL
 */
export const validateUrl = (url: string): { valid: boolean; message?: string } => {
  if (!url || url.trim().length === 0) {
    return { valid: false, message: 'URL不能为空' };
  }
  
  try {
    const urlObj = new URL(url);
    // 只允许http和https协议
    if (!['http:', 'https:'].includes(urlObj.protocol)) {
      return { valid: false, message: '只支持HTTP和HTTPS协议' };
    }
    return { valid: true };
  } catch {
    return { valid: false, message: 'URL格式不正确' };
  }
};

/**
 * 清理用户输入（防止XSS）
 */
export const sanitizeInput = (input: string): string => {
  if (!input) return '';
  
  // 移除HTML标签
  let sanitized = input.replace(/<[^>]*>/g, '');
  
  // 转义特殊字符
  sanitized = sanitized
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
  
  return sanitized.trim();
};

/**
 * 验证文本长度
 */
export const validateLength = (
  text: string,
  min: number,
  max: number,
  fieldName: string = '文本'
): { valid: boolean; message?: string } => {
  if (!text) {
    return { valid: false, message: `${fieldName}不能为空` };
  }
  
  const length = text.trim().length;
  
  if (length < min) {
    return { valid: false, message: `${fieldName}至少需要${min}个字符` };
  }
  
  if (length > max) {
    return { valid: false, message: `${fieldName}不能超过${max}个字符` };
  }
  
  return { valid: true };
};

/**
 * 验证任务标题
 */
export const validateTaskTitle = (title: string): { valid: boolean; message?: string } => {
  return validateLength(title, 5, 100, '任务标题');
};

/**
 * 验证任务描述
 */
export const validateTaskDescription = (description: string): { valid: boolean; message?: string } => {
  return validateLength(description, 10, 5000, '任务描述');
};

/**
 * 验证论坛帖子标题
 */
export const validatePostTitle = (title: string): { valid: boolean; message?: string } => {
  return validateLength(title, 5, 200, '帖子标题');
};

/**
 * 验证论坛帖子内容
 */
export const validatePostContent = (content: string): { valid: boolean; message?: string } => {
  return validateLength(content, 10, 10000, '帖子内容');
};

/**
 * 验证价格/金额
 */
export const validatePrice = (price: string | number): { valid: boolean; message?: string } => {
  const priceNum = typeof price === 'string' ? parseFloat(price) : price;
  
  if (isNaN(priceNum)) {
    return { valid: false, message: '价格必须是数字' };
  }
  
  if (priceNum < 0) {
    return { valid: false, message: '价格不能为负数' };
  }
  
  if (priceNum > 1000000) {
    return { valid: false, message: '价格不能超过1,000,000' };
  }
  
  return { valid: true };
};

/**
 * 组合验证器（多个验证规则）
 */
export const combineValidators = (
  ...validators: Array<(value: string) => { valid: boolean; message?: string }>
) => {
  return (value: string): { valid: boolean; message?: string } => {
    for (const validator of validators) {
      const result = validator(value);
      if (!result.valid) {
        return result;
      }
    }
    return { valid: true };
  };
};

