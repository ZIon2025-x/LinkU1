import React from 'react';
import styles from './AdminPagination.module.css';

export interface AdminPaginationProps {
  currentPage: number;
  totalPages: number;
  total: number;
  pageSize: number;
  onPageChange: (page: number) => void;
  onPageSizeChange?: (size: number) => void;
  pageSizeOptions?: number[];
  showPageSizeSelector?: boolean;
  showTotal?: boolean;
  className?: string;
}

/**
 * 通用管理后台分页组件
 */
export const AdminPagination: React.FC<AdminPaginationProps> = ({
  currentPage,
  totalPages,
  total,
  pageSize,
  onPageChange,
  onPageSizeChange,
  pageSizeOptions = [10, 20, 50, 100],
  showPageSizeSelector = true,
  showTotal = true,
  className = '',
}) => {
  const getPageNumbers = () => {
    const pages: (number | string)[] = [];
    const showPages = 5; // 最多显示5个页码

    if (totalPages <= showPages + 2) {
      // 如果总页数较少，显示所有页码
      for (let i = 1; i <= totalPages; i++) {
        pages.push(i);
      }
    } else {
      // 总是显示第一页
      pages.push(1);

      // 计算中间页码范围
      let start = Math.max(2, currentPage - 1);
      let end = Math.min(totalPages - 1, currentPage + 1);

      // 调整范围以保持显示5个页码
      if (currentPage <= 3) {
        end = Math.min(showPages, totalPages - 1);
      } else if (currentPage >= totalPages - 2) {
        start = Math.max(2, totalPages - showPages + 1);
      }

      // 添加省略号
      if (start > 2) {
        pages.push('...');
      }

      // 添加中间页码
      for (let i = start; i <= end; i++) {
        pages.push(i);
      }

      // 添加省略号
      if (end < totalPages - 1) {
        pages.push('...');
      }

      // 总是显示最后一页
      pages.push(totalPages);
    }

    return pages;
  };

  const handlePrevious = () => {
    if (currentPage > 1) {
      onPageChange(currentPage - 1);
    }
  };

  const handleNext = () => {
    if (currentPage < totalPages) {
      onPageChange(currentPage + 1);
    }
  };

  const handlePageClick = (page: number | string) => {
    if (typeof page === 'number') {
      onPageChange(page);
    }
  };

  const startItem = (currentPage - 1) * pageSize + 1;
  const endItem = Math.min(currentPage * pageSize, total);

  return (
    <div className={`${styles.pagination} ${className}`}>
      {showTotal && (
        <div className={styles.info}>
          显示 {startItem} - {endItem} 条，共 {total} 条
        </div>
      )}

      <div className={styles.controls}>
        <button
          className={styles.button}
          onClick={handlePrevious}
          disabled={currentPage === 1}
        >
          上一页
        </button>

        <div className={styles.pages}>
          {getPageNumbers().map((page, index) => (
            <button
              key={index}
              className={`${styles.pageButton} ${
                page === currentPage ? styles.active : ''
              } ${page === '...' ? styles.ellipsis : ''}`}
              onClick={() => handlePageClick(page)}
              disabled={page === '...'}
            >
              {page}
            </button>
          ))}
        </div>

        <button
          className={styles.button}
          onClick={handleNext}
          disabled={currentPage === totalPages}
        >
          下一页
        </button>
      </div>

      {showPageSizeSelector && onPageSizeChange && (
        <div className={styles.pageSizeSelector}>
          <label>每页显示：</label>
          <select
            value={pageSize}
            onChange={(e) => onPageSizeChange(Number(e.target.value))}
            className={styles.select}
          >
            {pageSizeOptions.map((size) => (
              <option key={size} value={size}>
                {size} 条
              </option>
            ))}
          </select>
        </div>
      )}
    </div>
  );
};

export default AdminPagination;
