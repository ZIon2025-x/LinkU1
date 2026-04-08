/**
 * London local datetime → UTC ISO string conversion.
 *
 * 用于把"用户在 London 时区填写的日期+时间"转成后端需要的 UTC ISO 字符串。
 * 服务端仍以 Europe/London 作为达人服务时间段的本地时区基准（含 BST/GMT 切换）。
 *
 * Inputs:
 *   dateStr — "YYYY-MM-DD"
 *   timeStr — "HH:MM" or "HH:MM:SS"
 *
 * Returns:
 *   ISO 8601 UTC string with 'Z' suffix.
 */
export const londonLocalToUtcIso = (dateStr: string, timeStr: string): string => {
  const t = timeStr.length === 5 ? `${timeStr}:00` : timeStr;
  // Step 1: parse the input as if it were UTC. This gives us a Date instance
  // whose UTC fields equal the user-typed local fields.
  const naive = new Date(`${dateStr}T${t}Z`);

  // Step 2: render that same instant in Europe/London. The rendered fields
  // tell us what the London wall clock would read for this instant.
  const fmt = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/London',
    hour12: false,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  });
  const parts: Record<string, string> = {};
  for (const p of fmt.formatToParts(naive)) {
    if (p.type !== 'literal') parts[p.type] = p.value;
  }
  // Step 3: turn the rendered London-wall-clock into a UTC instant for comparison.
  const tzAsUtc = Date.UTC(
    Number(parts.year), Number(parts.month) - 1, Number(parts.day),
    Number(parts.hour) % 24, Number(parts.minute), Number(parts.second),
  );
  // Step 4: the difference between (London wall clock viewed as UTC) and
  // (input viewed as UTC) is the offset that London applies to UTC at this
  // moment (e.g. +60 min in BST, 0 in GMT).
  const offset = tzAsUtc - naive.getTime();

  // Step 5: subtract the offset from the naive UTC interpretation to land on
  // the true UTC instant the user meant.
  return new Date(naive.getTime() - offset).toISOString();
};
