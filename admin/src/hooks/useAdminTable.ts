import { useState, useCallback, useEffect } from 'react';

export interface TableConfig<T> {
  fetchData: (params: FetchParams) => Promise<{ data: T[]; total: number }>;
  initialPageSize?: number;
  onError?: (error: any) => void;
}

export interface FetchParams {
  page: number;
  pageSize: number;
  searchTerm?: string;
  filters?: Record<string, any>;
  sortField?: string;
  sortOrder?: 'asc' | 'desc';
}

export interface UseAdminTableReturn<T> {
  data: T[];
  loading: boolean;
  currentPage: number;
  pageSize: number;
  total: number;
  totalPages: number;
  searchTerm: string;
  filters: Record<string, any>;
  sortField: string | undefined;
  sortOrder: 'asc' | 'desc' | undefined;
  setCurrentPage: (page: number) => void;
  setPageSize: (size: number) => void;
  setSearchTerm: (term: string) => void;
  setFilters: (filters: Record<string, any>) => void;
  setSorting: (field: string, order: 'asc' | 'desc') => void;
  refresh: () => Promise<void>;
  reset: () => void;
}

/**
 * 通用表格数据管理 Hook
 * 处理分页、搜索、筛选、排序等常见表格操作
 */
export function useAdminTable<T = any>(config: TableConfig<T>): UseAdminTableReturn<T> {
  const { fetchData, initialPageSize = 10, onError } = config;

  const [data, setData] = useState<T[]>([]);
  const [loading, setLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(initialPageSize);
  const [total, setTotal] = useState(0);
  const [searchTerm, setSearchTerm] = useState('');
  const [filters, setFilters] = useState<Record<string, any>>({});
  const [sortField, setSortField] = useState<string | undefined>();
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc' | undefined>();

  const totalPages = Math.ceil(total / pageSize);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const result = await fetchData({
        page: currentPage,
        pageSize,
        searchTerm,
        filters,
        sortField,
        sortOrder,
      });
      setData(result.data);
      setTotal(result.total);
    } catch (error) {
      if (onError) {
        onError(error);
      }
      setData([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [currentPage, pageSize, searchTerm, filters, sortField, sortOrder, fetchData, onError]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handlePageChange = useCallback((page: number) => {
    setCurrentPage(page);
  }, []);

  const handlePageSizeChange = useCallback((size: number) => {
    setPageSize(size);
    setCurrentPage(1); // 重置到第一页
  }, []);

  const handleSearchChange = useCallback((term: string) => {
    setSearchTerm(term);
    setCurrentPage(1); // 搜索时重置到第一页
  }, []);

  const handleFiltersChange = useCallback((newFilters: Record<string, any>) => {
    setFilters(newFilters);
    setCurrentPage(1); // 筛选时重置到第一页
  }, []);

  const handleSorting = useCallback((field: string, order: 'asc' | 'desc') => {
    setSortField(field);
    setSortOrder(order);
  }, []);

  const refresh = useCallback(async () => {
    await loadData();
  }, [loadData]);

  const reset = useCallback(() => {
    setCurrentPage(1);
    setSearchTerm('');
    setFilters({});
    setSortField(undefined);
    setSortOrder(undefined);
  }, []);

  return {
    data,
    loading,
    currentPage,
    pageSize,
    total,
    totalPages,
    searchTerm,
    filters,
    sortField,
    sortOrder,
    setCurrentPage: handlePageChange,
    setPageSize: handlePageSizeChange,
    setSearchTerm: handleSearchChange,
    setFilters: handleFiltersChange,
    setSorting: handleSorting,
    refresh,
    reset,
  };
}
