export interface ExportColumn {
  key: string;
  label: string;
  /** Optional transform function for the cell value */
  format?: (value: any, row: Record<string, any>) => string;
}

/**
 * Export data as CSV and trigger browser download.
 * UTF-8 BOM is prepended so Excel opens Chinese characters correctly.
 */
export function exportToCSV(
  data: Record<string, any>[],
  filename: string,
  columns: ExportColumn[]
): void {
  const header = columns.map(c => `"${c.label}"`).join(',');
  const rows = data.map(row =>
    columns
      .map(c => {
        const raw = c.format ? c.format(row[c.key], row) : row[c.key];
        const value = raw == null ? '' : String(raw);
        return `"${value.replace(/"/g, '""')}"`;
      })
      .join(',')
  );
  const csv = [header, ...rows].join('\r\n');
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${filename}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
