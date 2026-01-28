import { useState, useEffect, useCallback } from 'react';

/** ISO string (UTC) or null. Updates every second. */
export function usePaymentCountdown(expiresAt: string | null) {
  const [secondsLeft, setSecondsLeft] = useState<number | null>(null);
  const [formatted, setFormatted] = useState<string>('');
  const [isExpired, setIsExpired] = useState(false);

  const compute = useCallback(() => {
    if (!expiresAt) {
      setSecondsLeft(null);
      setFormatted('');
      setIsExpired(false);
      return;
    }
    const expires = new Date(expiresAt).getTime();
    const now = Date.now();
    const diff = Math.floor((expires - now) / 1000);
    if (diff <= 0) {
      setSecondsLeft(0);
      setFormatted('0:00');
      setIsExpired(true);
      return;
    }
    setSecondsLeft(diff);
    const m = Math.floor(diff / 60);
    const s = diff % 60;
    setFormatted(`${m}:${s.toString().padStart(2, '0')}`);
    setIsExpired(false);
  }, [expiresAt]);

  useEffect(() => {
    compute();
    if (!expiresAt) return;
    const interval = setInterval(compute, 1000);
    return () => clearInterval(interval);
  }, [expiresAt, compute]);

  return { secondsLeft, formatted, isExpired };
}
