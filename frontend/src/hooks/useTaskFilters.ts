import { useState, useCallback, useRef, useEffect } from 'react';

interface UseTaskFiltersReturn {
  type: string;
  city: string;
  keyword: string;
  debouncedKeyword: string;
  taskLevel: string;
  cityInitialized: boolean;
  setType: (type: string) => void;
  setCity: (city: string) => void;
  setKeyword: (keyword: string) => void;
  setTaskLevel: (level: string) => void;
  setCityInitialized: (initialized: boolean) => void;
  handleLevelChange: (newLevel: string) => string;
}

export const useTaskFilters = (initialTaskLevel: string): UseTaskFiltersReturn => {
  const [type, setType] = useState('all');
  const [city, setCity] = useState('all');
  const [keyword, setKeyword] = useState('');
  const [debouncedKeyword, setDebouncedKeyword] = useState('');
  const [taskLevel, setTaskLevel] = useState(initialTaskLevel);
  const [cityInitialized, setCityInitialized] = useState(false);
  const keywordDebounceRef = useRef<NodeJS.Timeout | null>(null);

  // 防抖处理搜索关键词
  useEffect(() => {
    if (keywordDebounceRef.current) {
      clearTimeout(keywordDebounceRef.current);
    }
    
    keywordDebounceRef.current = setTimeout(() => {
      setDebouncedKeyword(keyword);
    }, 300);
    
    return () => {
      if (keywordDebounceRef.current) {
        clearTimeout(keywordDebounceRef.current);
      }
    };
  }, [keyword]);

  const handleLevelChange = useCallback((newLevel: string): string => {
    setTaskLevel(newLevel);
    return newLevel;
  }, []);

  return {
    type,
    city,
    keyword,
    debouncedKeyword,
    taskLevel,
    cityInitialized,
    setType,
    setCity,
    setKeyword,
    setTaskLevel,
    setCityInitialized,
    handleLevelChange
  };
};

