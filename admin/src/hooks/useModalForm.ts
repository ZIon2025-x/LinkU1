import { useState, useCallback } from 'react';

export interface UseModalFormConfig<T> {
  initialValues: T;
  onSubmit: (values: T, isEdit: boolean) => Promise<void>;
  onSuccess?: () => void;
  onError?: (error: any) => void;
  resetOnClose?: boolean;
}

export interface UseModalFormReturn<T> {
  isOpen: boolean;
  isEdit: boolean;
  formData: T;
  loading: boolean;
  /** 打开模态框。editData: 编辑数据；forceCreate: 为true时即使有数据也视为创建模式 */
  open: (editData?: T, forceCreate?: boolean) => void;
  close: () => void;
  setFormData: (data: T | ((prev: T) => T)) => void;
  updateField: <K extends keyof T>(field: K, value: T[K]) => void;
  handleSubmit: () => Promise<void>;
  reset: () => void;
}

/**
 * 通用模态框表单管理 Hook
 * 处理模态框的打开/关闭、表单数据、提交等逻辑
 */
export function useModalForm<T extends Record<string, any>>(
  config: UseModalFormConfig<T>
): UseModalFormReturn<T> {
  const {
    initialValues,
    onSubmit,
    onSuccess,
    onError,
    resetOnClose = true,
  } = config;

  const [isOpen, setIsOpen] = useState(false);
  const [isEdit, setIsEdit] = useState(false);
  const [formData, setFormData] = useState<T>(initialValues);
  const [loading, setLoading] = useState(false);

  const open = useCallback((editData?: T, forceCreate?: boolean) => {
    if (editData && !forceCreate) {
      // 编辑模式：有数据且不是强制创建
      setIsEdit(true);
      setFormData(editData);
    } else {
      // 创建模式：用传入的数据或默认值
      setIsEdit(false);
      setFormData(editData || initialValues);
    }
    setIsOpen(true);
  }, [initialValues]);

  const close = useCallback(() => {
    setIsOpen(false);
    if (resetOnClose) {
      setTimeout(() => {
        setFormData(initialValues);
        setIsEdit(false);
      }, 300); // 延迟重置，等待关闭动画完成
    }
  }, [initialValues, resetOnClose]);

  const updateField = useCallback(<K extends keyof T>(field: K, value: T[K]) => {
    setFormData((prev) => ({
      ...prev,
      [field]: value,
    }));
  }, []);

  const handleSubmit = useCallback(async () => {
    setLoading(true);
    try {
      await onSubmit(formData, isEdit);
      if (onSuccess) {
        onSuccess();
      }
      close();
    } catch (error) {
      console.error('Form submission failed:', error);
      if (onError) {
        onError(error);
      }
    } finally {
      setLoading(false);
    }
  }, [formData, isEdit, onSubmit, onSuccess, onError, close]);

  const reset = useCallback(() => {
    setFormData(initialValues);
    setIsEdit(false);
  }, [initialValues]);

  return {
    isOpen,
    isEdit,
    formData,
    loading,
    open,
    close,
    setFormData,
    updateField,
    handleSubmit,
    reset,
  };
}
