import React, { ReactNode } from 'react';
import styles from './AdminTable.module.css';

export interface Column<T> {
  key: string;
  title: string;
  dataIndex?: keyof T;
  width?: string | number;
  align?: 'left' | 'center' | 'right';
  render?: (value: any, record: T, index: number) => ReactNode;
  sorter?: boolean;
  fixed?: 'left' | 'right';
}

export interface AdminTableProps<T> {
  columns: Column<T>[];
  data: T[];
  loading?: boolean;
  /** Background refresh in progress — shows a subtle top bar instead of full overlay. */
  refreshing?: boolean;
  rowKey?: keyof T | ((record: T) => string | number);
  onRowClick?: (record: T) => void;
  emptyText?: string;
  className?: string;
  maxHeight?: string | number;
  striped?: boolean;
  hoverable?: boolean;
  bordered?: boolean;
}

/**
 * 通用管理后台表格组件
 * 支持自定义列、排序、固定列等功能
 */
export function AdminTable<T extends Record<string, any>>({
  columns,
  data,
  loading = false,
  refreshing = false,
  rowKey = 'id' as keyof T,
  onRowClick,
  emptyText = '暂无数据',
  className = '',
  maxHeight,
  striped = true,
  hoverable = true,
  bordered = false,
}: AdminTableProps<T>) {
  const getRowKey = (record: T, index: number): string | number => {
    if (typeof rowKey === 'function') {
      return rowKey(record);
    }
    return record[rowKey] ?? index;
  };

  const renderCell = (column: Column<T>, record: T, index: number) => {
    if (column.render) {
      return column.render(
        column.dataIndex ? record[column.dataIndex] : record,
        record,
        index
      );
    }
    return column.dataIndex ? String(record[column.dataIndex] ?? '') : '';
  };

  const tableClasses = [
    styles.table,
    className,
    striped && styles.striped,
    hoverable && styles.hoverable,
    bordered && styles.bordered,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <div className={styles.tableContainer}>
      {loading && (
        <div className={styles.loadingOverlay}>
          <div className={styles.spinner}>加载中...</div>
        </div>
      )}
      {!loading && refreshing && <div className={styles.refreshBar} />}

      <div
        className={styles.tableWrapper}
        style={maxHeight ? { maxHeight, overflowY: 'auto' } : undefined}
      >
        <table className={tableClasses}>
          <thead className={styles.thead}>
            <tr>
              {columns.map((column) => (
                <th
                  key={column.key}
                  style={{
                    width: column.width,
                    textAlign: column.align || 'left',
                  }}
                  className={column.fixed ? styles[`fixed-${column.fixed}`] : ''}
                >
                  {column.title}
                  {column.sorter && (
                    <span className={styles.sorterIcon}>⇅</span>
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className={styles.tbody}>
            {data.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className={styles.emptyCell}>
                  {emptyText}
                </td>
              </tr>
            ) : (
              data.map((record, index) => (
                <tr
                  key={getRowKey(record, index)}
                  onClick={() => onRowClick?.(record)}
                  className={onRowClick ? styles.clickable : ''}
                >
                  {columns.map((column) => (
                    <td
                      key={column.key}
                      style={{
                        width: column.width,
                        textAlign: column.align || 'left',
                      }}
                      className={column.fixed ? styles[`fixed-${column.fixed}`] : ''}
                    >
                      {renderCell(column, record, index)}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default AdminTable;
