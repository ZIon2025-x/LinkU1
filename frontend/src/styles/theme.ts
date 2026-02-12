/**
 * 统一设计系统
 * 定义项目的颜色、间距、字体等设计规范
 */

export const theme = {
  // 颜色系统
  colors: {
    // 主色调
    primary: '#007AFF',
    primaryHover: '#409CFF',
    primaryActive: '#0059B3',
    
    // 辅助色
    secondary: '#52c41a',
    secondaryHover: '#73d13d',
    secondaryActive: '#389e0d',
    
    // 功能色
    success: '#52c41a',
    warning: '#faad14',
    error: '#ff4d4f',
    info: '#007AFF',
    
    // 中性色
    text: {
      primary: 'rgba(0, 0, 0, 0.85)',
      secondary: 'rgba(0, 0, 0, 0.65)',
      disabled: 'rgba(0, 0, 0, 0.25)',
      inverse: '#ffffff',
    },
    
    background: {
      default: '#ffffff',
      secondary: '#fafafa',
      tertiary: '#f5f5f5',
      disabled: '#f5f5f5',
    },
    
    border: {
      default: '#d9d9d9',
      light: '#f0f0f0',
      dark: '#bfbfbf',
    },
  },
  
  // 间距系统
  spacing: {
    xs: '4px',
    sm: '8px',
    md: '16px',
    lg: '24px',
    xl: '32px',
    xxl: '48px',
  },
  
  // 圆角系统
  borderRadius: {
    small: '4px',
    medium: '8px',
    large: '12px',
    round: '50%',
  },
  
  // 字体系统
  typography: {
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"',
    fontSize: {
      xs: '12px',
      sm: '14px',
      md: '16px',
      lg: '18px',
      xl: '20px',
      xxl: '24px',
      xxxl: '32px',
    },
    fontWeight: {
      normal: 400,
      medium: 500,
      semibold: 600,
      bold: 700,
    },
    lineHeight: {
      tight: 1.25,
      normal: 1.5,
      relaxed: 1.75,
    },
  },
  
  // 阴影系统
  shadows: {
    sm: '0 1px 2px rgba(0, 0, 0, 0.05)',
    md: '0 2px 8px rgba(0, 0, 0, 0.1)',
    lg: '0 4px 16px rgba(0, 0, 0, 0.1)',
    xl: '0 8px 24px rgba(0, 0, 0, 0.12)',
  },
  
  // 过渡动画
  transitions: {
    fast: '0.15s ease-in-out',
    normal: '0.3s ease-in-out',
    slow: '0.5s ease-in-out',
  },
  
  // 断点系统（用于响应式设计）
  breakpoints: {
    xs: '480px',
    sm: '576px',
    md: '768px',
    lg: '992px',
    xl: '1200px',
    xxl: '1600px',
  },
  
  // Z-index层级
  zIndex: {
    dropdown: 1000,
    sticky: 1020,
    fixed: 1030,
    modalBackdrop: 1040,
    modal: 1050,
    popover: 1060,
    tooltip: 1070,
  },
} as const;

// 类型导出
export type Theme = typeof theme;
export type ThemeColors = typeof theme.colors;
export type ThemeSpacing = typeof theme.spacing;

// 响应式工具函数
export const mediaQuery = {
  xs: `@media (max-width: ${theme.breakpoints.xs})`,
  sm: `@media (max-width: ${theme.breakpoints.sm})`,
  md: `@media (max-width: ${theme.breakpoints.md})`,
  lg: `@media (max-width: ${theme.breakpoints.lg})`,
  xl: `@media (max-width: ${theme.breakpoints.xl})`,
  minXs: `@media (min-width: ${theme.breakpoints.xs})`,
  minSm: `@media (min-width: ${theme.breakpoints.sm})`,
  minMd: `@media (min-width: ${theme.breakpoints.md})`,
  minLg: `@media (min-width: ${theme.breakpoints.lg})`,
  minXl: `@media (min-width: ${theme.breakpoints.xl})`,
};

// Ant Design主题配置（用于ConfigProvider）
export const antdTheme = {
  token: {
    colorPrimary: theme.colors.primary,
    colorSuccess: theme.colors.success,
    colorWarning: theme.colors.warning,
    colorError: theme.colors.error,
    colorInfo: theme.colors.info,
    borderRadius: 8, // 使用数字类型，对应 theme.borderRadius.medium (8px)
    fontFamily: theme.typography.fontFamily,
  },
};

