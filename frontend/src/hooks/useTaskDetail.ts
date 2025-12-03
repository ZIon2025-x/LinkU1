/**
 * 任务详情相关 React Query Hooks
 * P1 优化：集成 React Query 统一数据层，提供请求去重、重试、失效、预取等能力
 */
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api, { fetchCurrentUser, getTaskReviews } from '../api';

// 查询键工厂（使用 as const 确保类型安全）
export const taskKeys = {
  all: ['tasks'] as const,
  detail: (id: number) => [...taskKeys.all, 'detail', id] as const,
  reviews: (id: number) => [...taskKeys.all, 'reviews', id] as const,
  user: () => ['user', 'current'] as const,
} as const;

/**
 * 任务详情查询
 */
export const useTaskDetail = (taskId: number | null) => {
  return useQuery({
    queryKey: taskKeys.detail(taskId!),
    queryFn: async ({ signal }) => {
      if (!taskId) return null;
      const res = await api.get(`/api/tasks/${taskId}`, { signal });
      return res.data;
    },
    enabled: !!taskId,
    staleTime: 5 * 60 * 1000,  // 5分钟内认为数据新鲜
    gcTime: 10 * 60 * 1000,    // 10分钟后垃圾回收（原 cacheTime）
    retry: 2,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
  });
};

/**
 * 用户信息查询
 */
export const useCurrentUser = () => {
  return useQuery({
    queryKey: taskKeys.user(),
    queryFn: fetchCurrentUser,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
};

/**
 * 任务评价查询
 */
export const useTaskReviews = (taskId: number | null) => {
  return useQuery({
    queryKey: taskKeys.reviews(taskId!),
    queryFn: async ({ signal }) => {
      if (!taskId) return [];
      // 注意：getTaskReviews 需要支持 AbortSignal
      // 如果 API 函数不支持，需要修改 api.ts
      try {
        return await getTaskReviews(taskId);
      } catch (error) {
                return [];
      }
    },
    enabled: !!taskId,
    staleTime: 2 * 60 * 1000,
  });
};

/**
 * 并行查询任务和用户
 */
export const useTaskDetailWithUser = (taskId: number | null) => {
  const taskQuery = useTaskDetail(taskId);
  const userQuery = useCurrentUser();
  
  return {
    task: taskQuery.data,
    user: userQuery.data,
    isLoading: taskQuery.isLoading || userQuery.isLoading,
    isFetching: taskQuery.isFetching || userQuery.isFetching,
    error: taskQuery.error || userQuery.error,
    refetch: () => {
      taskQuery.refetch();
      userQuery.refetch();
    },
  };
};

