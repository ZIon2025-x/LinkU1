// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BagSheet } from '../../src/components/BagSheet.jsx';

const baseProps = {
  open: true,
  onClose: () => {},
  stats: { academic: 72, wallet: 420, energy: 60, stress: 40, belonging: 35 },
  mealsToday: 1,
  weekInfo: { type: 'term', cn: '学期' },
  attendanceRate: 82,
  classesAttendedThisWeek: 3,
  dissertationProgress: null,
  dissertationTopic: null,
  muted: false,
  onToggleMute: () => {},
  onRestart: () => {},
};

describe('BagSheet', () => {
  it('renders all 5 stat names', () => {
    render(<BagSheet {...baseProps} />);
    expect(screen.getByText(/学业/)).toBeTruthy();
    expect(screen.getByText(/钱包/)).toBeTruthy();
    expect(screen.getByText(/精力/)).toBeTruthy();
    expect(screen.getByText(/压力/)).toBeTruthy();
    expect(screen.getByText(/归属/)).toBeTruthy();
  });

  it('renders meal count', () => {
    render(<BagSheet {...baseProps} mealsToday={1} />);
    expect(screen.getByText(/1\s*\/\s*2/)).toBeTruthy();
  });

  it('renders week type and attendance', () => {
    render(<BagSheet {...baseProps} />);
    expect(screen.getByText(/学期/)).toBeTruthy();
    expect(screen.getByText(/82%/)).toBeTruthy();
    expect(screen.getByText(/3\s*\/\s*6/)).toBeTruthy();
  });

  it('does NOT render dissertation section when type !== dissertation', () => {
    render(<BagSheet {...baseProps} />);
    expect(screen.queryByText(/论文进度/)).toBeNull();
  });

  it('renders dissertation section when type === dissertation', () => {
    render(<BagSheet {...baseProps}
      weekInfo={{ type: 'dissertation', cn: '论文季' }}
      dissertationProgress={45}
      dissertationTopic={{ label: 'AI 在课堂的伦理影响' }}
    />);
    expect(screen.getByText(/论文进度/)).toBeTruthy();
    expect(screen.getByText(/45%/)).toBeTruthy();
    expect(screen.getByText(/AI 在课堂的伦理影响/)).toBeTruthy();
  });

  it('renders mute toggle and restart button', () => {
    render(<BagSheet {...baseProps} muted={false} />);
    expect(screen.getByText(/声音开|音乐|音效/)).toBeTruthy();
    expect(screen.getByText(/重新开始/)).toBeTruthy();
  });

  it('shows muted label when muted', () => {
    render(<BagSheet {...baseProps} muted={true} />);
    expect(screen.getByText(/已静音|🔇/)).toBeTruthy();
  });

  it('renders nothing when open=false', () => {
    const { container } = render(<BagSheet {...baseProps} open={false} />);
    expect(container.firstChild).toBeNull();
  });
});
