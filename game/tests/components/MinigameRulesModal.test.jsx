// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import {
  MinigameRulesModal,
  MinigameHelpButton,
} from '../../src/components/MinigameRulesModal.jsx';

describe('MinigameRulesModal', () => {
  it('renders nothing when open=false', () => {
    const { container } = render(
      <MinigameRulesModal open={false} onClose={() => {}} title="T">
        body
      </MinigameRulesModal>,
    );
    expect(container.firstChild).toBeNull();
  });

  it('renders title + children when open=true', () => {
    render(
      <MinigameRulesModal open={true} onClose={() => {}} title="LECTURE 玩法">
        <p>规则正文</p>
      </MinigameRulesModal>,
    );
    expect(screen.getByText(/LECTURE 玩法/)).toBeTruthy();
    expect(screen.getByText('规则正文')).toBeTruthy();
  });

  it('calls onClose when backdrop clicked', () => {
    const onClose = vi.fn();
    render(
      <MinigameRulesModal open={true} onClose={onClose} title="T">
        body
      </MinigameRulesModal>,
    );
    fireEvent.click(screen.getByTestId('rules-modal-backdrop'));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('calls onClose when 明白了 button clicked', () => {
    const onClose = vi.fn();
    render(
      <MinigameRulesModal open={true} onClose={onClose} title="T">
        body
      </MinigameRulesModal>,
    );
    fireEvent.click(screen.getByText('明白了'));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('does NOT call onClose when modal body clicked', () => {
    const onClose = vi.fn();
    render(
      <MinigameRulesModal open={true} onClose={onClose} title="T">
        <p>body</p>
      </MinigameRulesModal>,
    );
    fireEvent.click(screen.getByText('body'));
    expect(onClose).not.toHaveBeenCalled();
  });
});

describe('MinigameHelpButton', () => {
  it('renders ? glyph and calls onClick', () => {
    const onClick = vi.fn();
    render(<MinigameHelpButton onClick={onClick} />);
    const btn = screen.getByRole('button', { name: /玩法说明/i });
    expect(btn.textContent).toContain('?');
    fireEvent.click(btn);
    expect(onClick).toHaveBeenCalledOnce();
  });
});
