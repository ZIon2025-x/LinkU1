/**
 * SafeContent 组件
 * 安全渲染 HTML 内容，防止 XSS 攻击
 * DOMPurify hook 配置在模块级，只初始化一次
 */
import React from 'react';
import DOMPurify from 'dompurify';

// ⚠️ 重要：DOMPurify hook 配置放在模块级，只初始化一次
// 避免在组件渲染时重复注册 hook
let hookInitialized = false;

function initializeDOMPurifyHooks() {
  if (hookInitialized) return;
  
  DOMPurify.addHook('uponSanitizeElement', (node: any, data: any) => {
    // 处理链接：强制安全协议和 rel 属性
    if (data.tagName === 'a') {
      const href = node.getAttribute('href');
      if (href) {
        // 只允许 http/https/mailto 协议
        if (!/^(https?|mailto):/i.test(href)) {
          node.removeAttribute('href');
        }
        
        // 如果是外部链接或 target=_blank，强制添加 rel
        const target = node.getAttribute('target');
        if (target === '_blank' || href.startsWith('http')) {
          node.setAttribute('rel', 'noopener noreferrer nofollow ugc');
        }
      }
    }
    
    // 处理图片：限制 src 协议
    if (data.tagName === 'img') {
      const src = node.getAttribute('src');
      if (src && !/^(https?|data):/i.test(src)) {
        node.removeAttribute('src');
      }
    }
  });
  
  hookInitialized = true;
}

// 模块加载时初始化
if (typeof window !== 'undefined') {
  initializeDOMPurifyHooks();
}

interface SafeContentProps {
  content: string;
  allowHtml?: boolean;  // 是否允许HTML（如Markdown渲染后）
  className?: string;
}

const SafeContent: React.FC<SafeContentProps> = ({ 
  content, 
  allowHtml = false,
  className 
}) => {
  if (!content) return null;
  
  if (allowHtml) {
    // 确保 hook 已初始化（双重检查）
    if (typeof window !== 'undefined') {
      initializeDOMPurifyHooks();
    }
    
    // 富文本/Markdown 内容：使用 DOMPurify 白名单清洗
    const sanitized = DOMPurify.sanitize(content, {
      ALLOWED_TAGS: [
        'p', 'br', 'strong', 'em', 'u', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'ul', 'ol', 'li', 'blockquote', 'code', 'pre', 'a', 'img'
      ],
      ALLOWED_ATTR: {
        'a': ['href', 'title', 'target'],  // 允许 target（但会通过 hook 强制 rel）
        'img': ['src', 'alt', 'title'],
        '*': ['class']  // 所有标签允许 class
      },
      ALLOW_DATA_ATTR: false,  // 禁止 data-* 属性
      FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'form'],
      FORBID_ATTR: ['onerror', 'onload', 'onclick', 'onmouseover'],
      ADD_ATTR: ['target'],  // 允许 target 属性（hook 会处理）
    });
    
    return (
      <div 
        className={className}
        dangerouslySetInnerHTML={{ __html: sanitized }}
      />
    );
  } else {
    // 纯文本内容：保留换行符
    // 使用 CSS white-space: pre-wrap 来保留换行和空格
    // React 会自动转义 HTML 特殊字符（默认安全）
    return (
      <div 
        className={className}
        style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}
      >
        {content}
      </div>
    );
  }
};

export default SafeContent;

