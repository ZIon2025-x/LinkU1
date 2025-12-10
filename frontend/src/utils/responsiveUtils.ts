/**
 * 响应式设计工具函数
 * 提供移动端适配和响应式布局辅助函数
 */

import React from 'react';
import { theme } from '../styles/theme';

/**
 * 检查是否为移动设备
 */
export const isMobile = (): boolean => {
  if (typeof window === 'undefined') return false;
  return window.innerWidth < parseInt(theme.breakpoints.md);
};

/**
 * 检查是否为平板设备
 */
export const isTablet = (): boolean => {
  if (typeof window === 'undefined') return false;
  const width = window.innerWidth;
  return width >= parseInt(theme.breakpoints.md) && width < parseInt(theme.breakpoints.lg);
};

/**
 * 检查是否为桌面设备
 */
export const isDesktop = (): boolean => {
  if (typeof window === 'undefined') return false;
  return window.innerWidth >= parseInt(theme.breakpoints.lg);
};

/**
 * 获取当前屏幕尺寸类别
 */
export const getScreenSize = (): 'xs' | 'sm' | 'md' | 'lg' | 'xl' => {
  if (typeof window === 'undefined') return 'lg';
  
  const width = window.innerWidth;
  
  if (width < parseInt(theme.breakpoints.xs)) return 'xs';
  if (width < parseInt(theme.breakpoints.sm)) return 'sm';
  if (width < parseInt(theme.breakpoints.md)) return 'md';
  if (width < parseInt(theme.breakpoints.lg)) return 'lg';
  return 'xl';
};

/**
 * 响应式值（根据屏幕尺寸返回不同的值）
 */
export const responsiveValue = <T,>(
  values: {
    xs?: T;
    sm?: T;
    md?: T;
    lg?: T;
    xl?: T;
    default: T;
  }
): T => {
  const size = getScreenSize();
  return values[size] ?? values.default;
};

/**
 * 移动端优化的间距
 */
export const getResponsiveSpacing = (desktop: string, mobile: string): string => {
  return isMobile() ? mobile : desktop;
};

/**
 * 移动端优化的字体大小
 */
export const getResponsiveFontSize = (desktop: string, mobile: string): string => {
  return isMobile() ? mobile : desktop;
};

/**
 * 移动端优化的列数（用于Grid布局）
 */
export const getResponsiveColumns = (desktop: number, tablet: number, mobile: number): number => {
  if (isMobile()) return mobile;
  if (isTablet()) return tablet;
  return desktop;
};

/**
 * Hook: 监听窗口大小变化
 */
export const useWindowSize = () => {
  const [size, setSize] = React.useState({
    width: typeof window !== 'undefined' ? window.innerWidth : 0,
    height: typeof window !== 'undefined' ? window.innerHeight : 0,
  });

  React.useEffect(() => {
    const handleResize = () => {
      setSize({
        width: window.innerWidth,
        height: window.innerHeight,
      });
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return size;
};


