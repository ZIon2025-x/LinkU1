// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { BottomSheet } from '../../src/components/BottomSheet.jsx';

describe('BottomSheet', () => {
  it('renders nothing when open=false', () => {
    const { container } = render(
      <BottomSheet open={false} onClose={() => {}}>
        <div>body</div>
      </BottomSheet>,
    );
    expect(container.firstChild).toBeNull();
  });

  it('renders children when open=true', () => {
    render(
      <BottomSheet open={true} onClose={() => {}}>
        <div>body content</div>
      </BottomSheet>,
    );
    expect(screen.getByText('body content')).toBeTruthy();
  });

  it('renders title when provided', () => {
    render(
      <BottomSheet open={true} onClose={() => {}} title="🎒 背包">
        <div>body</div>
      </BottomSheet>,
    );
    expect(screen.getByText('🎒 背包')).toBeTruthy();
  });

  it('renders footer when provided', () => {
    render(
      <BottomSheet open={true} onClose={() => {}} footer={<button>OK</button>}>
        <div>body</div>
      </BottomSheet>,
    );
    expect(screen.getByText('OK')).toBeTruthy();
  });

  it('calls onClose when backdrop clicked', () => {
    const onClose = vi.fn();
    render(
      <BottomSheet open={true} onClose={onClose} data-testid="bs">
        <div>body</div>
      </BottomSheet>,
    );
    fireEvent.click(screen.getByTestId('bs-backdrop'));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('does NOT call onClose when sheet body clicked', () => {
    const onClose = vi.fn();
    render(
      <BottomSheet open={true} onClose={onClose}>
        <div>body</div>
      </BottomSheet>,
    );
    fireEvent.click(screen.getByText('body'));
    expect(onClose).not.toHaveBeenCalled();
  });

  it('calls onClose when Escape pressed', () => {
    const onClose = vi.fn();
    render(
      <BottomSheet open={true} onClose={onClose}>
        <div>body</div>
      </BottomSheet>,
    );
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(onClose).toHaveBeenCalledOnce();
  });
});
