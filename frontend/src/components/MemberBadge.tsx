import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';

export type MemberLevel = 'normal' | 'vip' | 'super';
export type MemberBadgeVariant = 'full' | 'compact' | 'avatar-corner';

interface MemberBadgeProps {
  /** 会员等级：字符串 'normal' | 'vip' | 'super'，或数字 1=普通 2=VIP 3=超级；API 返回的 string 也可传入 */
  level: MemberLevel | number | string;
  /** 展示形态：full=完整徽章(图标+文字) compact=紧凑徽章 avatar-corner=头像角标 */
  variant?: MemberBadgeVariant;
  /** 用于达人等场景的文案键：如 taskExperts.vipExpert；不传则用 profile.vip / profile.superVip */
  labelKey?: string;
  /** 单独指定 VIP / 超级 的文案键，如 userProfile.vipMember、userProfile.superMember */
  labelVip?: string;
  labelSuper?: string;
  className?: string;
  style?: React.CSSProperties;
}

const LEVEL_MAP: Record<string, MemberLevel> = {
  normal: 'normal',
  vip: 'vip',
  super: 'super',
  '1': 'normal',
  '2': 'vip',
  '3': 'super',
};

function normalizeLevel(level: MemberLevel | number | string): MemberLevel {
  if (typeof level === 'number') {
    const key = String(level) as '1' | '2' | '3';
    return LEVEL_MAP[key] ?? 'normal';
  }
  return LEVEL_MAP[String(level)] ?? 'normal';
}

const MemberBadge: React.FC<MemberBadgeProps> = ({
  level,
  variant = 'compact',
  labelKey,
  labelVip,
  labelSuper,
  className,
  style = {},
}) => {
  const { t } = useLanguage();
  const normalized = normalizeLevel(level);

  if (normalized === 'normal') {
    if (variant === 'avatar-corner') return null;
    if (variant === 'compact') return null;
    if (variant === 'full') {
      return (
        <span
          className={className}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: '6px',
            padding: '6px 14px',
            borderRadius: '20px',
            fontSize: '14px',
            fontWeight: '600',
            color: '#64748b',
            background: 'linear-gradient(135deg, #f8fafc, #e2e8f0)',
            border: '1px solid #cbd5e1',
            ...style,
          }}
        >
          {t('profile.normalUser')}
        </span>
      );
    }
    return null;
  }

  const isSuper = normalized === 'super';
  const bgVip = 'linear-gradient(135deg, #fbbf24, #f59e0b)';
  const bgSuper = 'linear-gradient(135deg, #a78bfa, #8b5cf6)';
  const bg = isSuper ? bgSuper : bgVip;
  const color = '#fff';
  const icon = isSuper ? '👑' : '⭐';
  const label =
    (isSuper && labelSuper ? t(labelSuper) : null) ??
    (!isSuper && labelVip ? t(labelVip) : null) ??
    (labelKey ? t(labelKey) : null) ??
    (isSuper ? t('profile.superVip') : t('profile.vip'));

  if (variant === 'avatar-corner') {
    return (
      <div
        className={className}
        style={{
          position: 'absolute',
          bottom: -2,
          right: -2,
          width: 28,
          height: 28,
          borderRadius: '50%',
          background: bg,
          border: '2px solid #fff',
          boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 14,
          zIndex: 5,
          ...style,
        }}
        title={label}
      >
        {icon}
      </div>
    );
  }

  if (variant === 'compact') {
    return (
      <span
        className={className}
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: '4px',
          padding: '3px 10px',
          borderRadius: '12px',
          fontSize: '12px',
          fontWeight: '600',
          color,
          background: bg,
          boxShadow: '0 1px 4px rgba(0,0,0,0.1)',
          whiteSpace: 'nowrap',
          ...style,
        }}
      >
        <span style={{ fontSize: '10px' }}>{icon}</span>
        {label}
      </span>
    );
  }

  // full
  return (
    <span
      className={className}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '8px',
        padding: '8px 18px',
        borderRadius: '24px',
        fontSize: '15px',
        fontWeight: '700',
        color,
        background: bg,
        boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
        border: '1px solid rgba(255,255,255,0.3)',
        ...style,
      }}
    >
      <span style={{ fontSize: '16px' }}>{icon}</span>
      {label}
    </span>
  );
};

export default MemberBadge;
