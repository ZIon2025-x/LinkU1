import { useState, useCallback, useRef, useEffect } from 'react';

interface UseTaskSortingReturn {
  sortBy: string;
  sortByRef: React.MutableRefObject<string>;
  rewardSort: string;
  deadlineSort: string;
  showRewardDropdown: boolean;
  showDeadlineDropdown: boolean;
  setShowRewardDropdown: (show: boolean) => void;
  setShowDeadlineDropdown: (show: boolean) => void;
  handleRewardSortChange: (value: string) => void;
  handleDeadlineSortChange: (value: string) => void;
  handleLatestSort: () => void;
}

export const useTaskSorting = (
  loadTasks: (isLoadMore: boolean, targetPage?: number, overrideSortBy?: string) => void
): UseTaskSortingReturn => {
  const [sortBy, setSortBy] = useState('latest');
  const sortByRef = useRef('latest');
  const [rewardSort, setRewardSort] = useState('');
  const [deadlineSort, setDeadlineSort] = useState('');
  const [showRewardDropdown, setShowRewardDropdown] = useState(false);
  const [showDeadlineDropdown, setShowDeadlineDropdown] = useState(false);

  // 同步 sortBy 到 ref
  useEffect(() => {
    sortByRef.current = sortBy;
  }, [sortBy]);

  const handleRewardSortChange = useCallback((value: string) => {
    setRewardSort(value);
    setDeadlineSort('');
    const newSortBy = value ? `reward_${value}` : 'latest';
    setSortBy(newSortBy);
    setShowRewardDropdown(false);
    loadTasks(false, undefined, newSortBy);
  }, [loadTasks]);

  const handleDeadlineSortChange = useCallback((value: string) => {
    setDeadlineSort(value);
    setRewardSort('');
    const newSortBy = value ? `deadline_${value}` : 'latest';
    setSortBy(newSortBy);
    setShowDeadlineDropdown(false);
    loadTasks(false, undefined, newSortBy);
  }, [loadTasks]);

  const handleLatestSort = useCallback(() => {
    setSortBy('latest');
    setRewardSort('');
    setDeadlineSort('');
    loadTasks(false, undefined, 'latest');
  }, [loadTasks]);

  return {
    sortBy,
    sortByRef,
    rewardSort,
    deadlineSort,
    showRewardDropdown,
    showDeadlineDropdown,
    setShowRewardDropdown,
    setShowDeadlineDropdown,
    handleRewardSortChange,
    handleDeadlineSortChange,
    handleLatestSort
  };
};

