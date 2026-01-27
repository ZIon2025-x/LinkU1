import React, { useState, useCallback, useRef } from 'react';
import { Modal, Upload, Button, Progress, message, Typography, Space } from 'antd';
import { UploadOutlined, DeleteOutlined, CheckCircleOutlined, ExclamationCircleOutlined, FileOutlined } from '@ant-design/icons';
import type { UploadFile, UploadProps } from 'antd';
import { compressImage } from '../utils/imageCompression';
import { getErrorMessage } from '../utils/errorHandler';
import api, { confirmTaskCompletion } from '../api';
import { useLanguage } from '../contexts/LanguageContext';

const { Text } = Typography;

interface ConfirmCompletionModalProps {
  visible: boolean;
  taskId: number;
  onCancel: () => void;
  onSuccess: () => void;
}

const MAX_FILES = 5;
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5MB

const ConfirmCompletionModal: React.FC<ConfirmCompletionModalProps> = ({
  visible,
  taskId,
  onCancel,
  onSuccess
}) => {
  const { t, language } = useLanguage();
  const [fileList, setFileList] = useState<UploadFile[]>([]);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState({ current: 0, total: 0 });
  const [errors, setErrors] = useState<string[]>([]);
  const [sizeErrors, setSizeErrors] = useState<string[]>([]);
  const uploadAbortControllerRef = useRef<AbortController | null>(null);

  // 检查文件类型是否为图片
  const isImageFile = (file: File): boolean => {
    return file.type.startsWith('image/');
  };

  // 处理文件选择
  const handleChange: UploadProps['onChange'] = useCallback((info) => {
    const newFileList = [...info.fileList];
    
    // 限制文件数量
    if (newFileList.length > MAX_FILES) {
      message.warning(
        language === 'zh' 
          ? `最多只能上传 ${MAX_FILES} 个文件` 
          : `Maximum ${MAX_FILES} files allowed`
      );
      return;
    }

    // 检查文件大小
    const newSizeErrors: string[] = [];
    const validFiles: UploadFile[] = [];
    
    newFileList.forEach((file, index) => {
      if (file.originFileObj) {
        const fileSize = file.originFileObj.size;
        const maxSize = isImageFile(file.originFileObj) ? MAX_IMAGE_SIZE : MAX_FILE_SIZE;
        if (fileSize > maxSize) {
          const sizeInMB = (fileSize / (1024 * 1024)).toFixed(1);
          const maxSizeMB = (maxSize / (1024 * 1024)).toFixed(0);
          newSizeErrors.push(
            language === 'zh'
              ? `第 ${index + 1} 个文件过大 (${sizeInMB}MB)，请选择较小的文件（最大 ${maxSizeMB}MB）`
              : `File ${index + 1} is too large (${sizeInMB}MB), please select a smaller file (max ${maxSizeMB}MB)`
          );
        } else {
          validFiles.push(file);
        }
      } else {
        validFiles.push(file);
      }
    });

    setSizeErrors(newSizeErrors);
    setFileList(validFiles);
  }, [language]);

  // 上传文件
  const uploadFile = useCallback(async (file: File, taskId: number): Promise<string> => {
    try {
      let fileToUpload = file;
      
      // 如果是图片，先压缩
      if (isImageFile(file)) {
        const compressedFile = await compressImage(file, {
          maxSizeMB: 5,
          maxWidthOrHeight: 1920,
          initialQuality: 0.7,
        });

        // 检查压缩后的大小
        if (compressedFile.size > MAX_IMAGE_SIZE) {
          const sizeInMB = (compressedFile.size / (1024 * 1024)).toFixed(1);
          throw new Error(
            language === 'zh'
              ? `图片压缩后仍过大 (${sizeInMB}MB)，请选择较小的图片`
              : `Image is still too large after compression (${sizeInMB}MB), please select a smaller image`
          );
        }
        
        fileToUpload = compressedFile;
      }

      const formData = new FormData();
      formData.append('file', fileToUpload);

      const response = await api.post(`/api/upload/file?task_id=${taskId}`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        signal: uploadAbortControllerRef.current?.signal,
      });

      if (response.data.success && response.data.file_id) {
        return response.data.file_id;
      } else {
        throw new Error(
          language === 'zh'
            ? '服务器未返回文件ID'
            : 'Server did not return file ID'
        );
      }
    } catch (error: any) {
      if (error.name === 'AbortError') {
        throw new Error(
          language === 'zh'
            ? '上传已取消'
            : 'Upload cancelled'
        );
      }
      throw error;
    }
  }, [language]);

  // 获取详细错误信息
  const getDetailedErrorMessage = useCallback((error: any, index: number): string => {
    if (error.response) {
      const status = error.response.status;
      const errorData = error.response.data;
      const errorMessage = errorData?.detail || errorData?.message || error.message;

      switch (status) {
        case 400:
          return language === 'zh'
            ? `第 ${index + 1} 个文件：请求格式错误 - ${errorMessage}`
            : `File ${index + 1}: Bad request - ${errorMessage}`;
        case 401:
          return language === 'zh'
            ? `第 ${index + 1} 个文件：未授权，请重新登录`
            : `File ${index + 1}: Unauthorized, please login again`;
        case 403:
          return language === 'zh'
            ? `第 ${index + 1} 个文件：无权限上传`
            : `File ${index + 1}: No permission to upload`;
        case 413:
          return language === 'zh'
            ? `第 ${index + 1} 个文件：文件过大`
            : `File ${index + 1}: File too large`;
        case 500:
        case 502:
        case 503:
          return language === 'zh'
            ? `第 ${index + 1} 个文件：服务器错误 (${status})，请稍后重试`
            : `File ${index + 1}: Server error (${status}), please try again later`;
        default:
          return language === 'zh'
            ? `第 ${index + 1} 个文件：服务器错误 (${status}) - ${errorMessage}`
            : `File ${index + 1}: Server error (${status}) - ${errorMessage}`;
      }
    }

    if (error.message) {
      if (error.message.includes('Network Error') || error.message.includes('Failed to fetch')) {
        return language === 'zh'
          ? `第 ${index + 1} 个文件：网络连接失败，请检查网络设置`
          : `File ${index + 1}: Network connection failed, please check network settings`;
      }
      if (error.message.includes('timeout')) {
        return language === 'zh'
          ? `第 ${index + 1} 个文件：上传超时，请重试`
          : `File ${index + 1}: Upload timeout, please try again`;
      }
      return language === 'zh'
        ? `第 ${index + 1} 个文件：${error.message}`
        : `File ${index + 1}: ${error.message}`;
    }

    return language === 'zh'
      ? `第 ${index + 1} 个文件：上传失败`
      : `File ${index + 1}: Upload failed`;
  }, [language]);

  // 提交确认完成
  const handleSubmit = useCallback(async () => {
    if (fileList.length === 0) {
      // 没有文件，直接提交
      try {
        setUploading(true);
        await confirmTaskCompletion(taskId, []);
        message.success(
          language === 'zh'
            ? '任务已确认完成'
            : 'Task confirmed as complete'
        );
        onSuccess();
        handleCancel();
      } catch (error: any) {
        const errorMsg = getErrorMessage(error);
        message.error(errorMsg);
      } finally {
        setUploading(false);
      }
      return;
    }

    // 检查文件大小
    const newSizeErrors: string[] = [];
    const validFiles: UploadFile[] = [];

    for (let i = 0; i < fileList.length; i++) {
      const file = fileList[i];
      if (file.originFileObj) {
        try {
          const maxSize = isImageFile(file.originFileObj) ? MAX_IMAGE_SIZE : MAX_FILE_SIZE;
          if (file.originFileObj.size > maxSize) {
            const sizeInMB = (file.originFileObj.size / (1024 * 1024)).toFixed(1);
            const maxSizeMB = (maxSize / (1024 * 1024)).toFixed(0);
            newSizeErrors.push(
              language === 'zh'
                ? `第 ${i + 1} 个文件过大 (${sizeInMB}MB)，最大 ${maxSizeMB}MB`
                : `File ${i + 1} is too large (${sizeInMB}MB), max ${maxSizeMB}MB`
            );
          } else {
            // 如果是图片，尝试压缩以检查最终大小
            if (isImageFile(file.originFileObj)) {
              const compressedFile = await compressImage(file.originFileObj, {
                maxSizeMB: 5,
                maxWidthOrHeight: 1920,
                initialQuality: 0.7,
              });
              if (compressedFile.size > MAX_IMAGE_SIZE) {
                const sizeInMB = (compressedFile.size / (1024 * 1024)).toFixed(1);
                newSizeErrors.push(
                  language === 'zh'
                    ? `第 ${i + 1} 张图片压缩后仍过大 (${sizeInMB}MB)`
                    : `Image ${i + 1} is still too large after compression (${sizeInMB}MB)`
                );
              } else {
                validFiles.push(file);
              }
            } else {
              validFiles.push(file);
            }
          }
        } catch (error) {
          newSizeErrors.push(
            language === 'zh'
              ? `第 ${i + 1} 个文件无法处理`
              : `File ${i + 1} cannot be processed`
          );
        }
      } else {
        validFiles.push(file);
      }
    }

    if (newSizeErrors.length > 0) {
      setSizeErrors(newSizeErrors);
      return;
    }

    if (validFiles.length === 0) {
      message.error(
        language === 'zh'
          ? '没有可上传的文件'
          : 'No valid files to upload'
      );
      return;
    }

    // 上传文件
    setUploading(true);
    setErrors([]);
    setUploadProgress({ current: 0, total: validFiles.length });
    uploadAbortControllerRef.current = new AbortController();

    const uploadedFileIds: string[] = [];
    const uploadErrors: Array<{ error: any; index: number }> = [];

    for (let i = 0; i < validFiles.length; i++) {
      const file = validFiles[i];
      if (file.originFileObj) {
        try {
          const fileId = await uploadFile(file.originFileObj, taskId);
          uploadedFileIds.push(fileId);
          setUploadProgress(prev => ({ ...prev, current: prev.current + 1 }));
        } catch (error: any) {
          uploadErrors.push({ error, index: i + 1 });
        }
      }
    }

    if (uploadErrors.length > 0) {
      const errorMessages = uploadErrors.map(({ error, index }) =>
        getDetailedErrorMessage(error, index)
      );
      setErrors(errorMessages);
      setUploading(false);
      return;
    }

    // 提交确认完成
    try {
      await confirmTaskCompletion(taskId, uploadedFileIds);
      message.success(
        language === 'zh'
          ? '任务已确认完成'
          : 'Task confirmed as complete'
      );
      onSuccess();
      handleCancel();
    } catch (error: any) {
      const errorMsg = getErrorMessage(error);
      message.error(errorMsg);
    } finally {
      setUploading(false);
    }
  }, [fileList, taskId, language, uploadFile, getDetailedErrorMessage, onSuccess]);

  // 取消
  const handleCancel = useCallback(() => {
    if (uploadAbortControllerRef.current) {
      uploadAbortControllerRef.current.abort();
      uploadAbortControllerRef.current = null;
    }
    setFileList([]);
    setErrors([]);
    setSizeErrors([]);
    setUploadProgress({ current: 0, total: 0 });
    onCancel();
  }, [onCancel]);

  // 删除文件
  const handleRemove = useCallback((file: UploadFile) => {
    const newFileList = fileList.filter(item => item.uid !== file.uid);
    setFileList(newFileList);
    return true;
  }, [fileList]);

  return (
    <Modal
      title={
        <Space>
          <CheckCircleOutlined style={{ color: '#52c41a' }} />
          <span>{language === 'zh' ? '确认任务完成' : 'Confirm Task Completion'}</span>
        </Space>
      }
      open={visible}
      onCancel={handleCancel}
      footer={[
        <Button key="cancel" onClick={handleCancel} disabled={uploading}>
          {language === 'zh' ? '取消' : 'Cancel'}
        </Button>,
        <Button
          key="submit"
          type="primary"
          onClick={handleSubmit}
          loading={uploading}
          disabled={uploading}
        >
          {uploading
            ? language === 'zh'
              ? `上传中 ${uploadProgress.current}/${uploadProgress.total}...`
              : `Uploading ${uploadProgress.current}/${uploadProgress.total}...`
            : language === 'zh'
            ? '确认完成'
            : 'Confirm Complete'}
        </Button>
      ]}
      width={600}
    >
      <Space direction="vertical" size="large" style={{ width: '100%' }}>
        {/* 说明文字 */}
        <div>
          <Text>
            {language === 'zh'
              ? '您已确认此任务完成。可以上传相关证据文件（可选），如完成截图、验收记录等。'
              : 'You have confirmed this task is complete. You can upload relevant evidence files (optional), such as completion screenshots, acceptance records, etc.'}
          </Text>
        </div>

        {/* 文件大小限制提示 */}
        <div>
          <Space>
            <ExclamationCircleOutlined style={{ color: '#faad14' }} />
            <Text type="secondary" style={{ fontSize: '12px' }}>
              {language === 'zh'
                ? `图片不超过 5MB，其他文件不超过 10MB，最多上传 ${MAX_FILES} 个文件`
                : `Images max 5MB, other files max 10MB, up to ${MAX_FILES} files`}
            </Text>
          </Space>
        </div>

        {/* 文件上传 */}
        <Upload
          listType="picture-card"
          fileList={fileList}
          onChange={handleChange}
          onRemove={handleRemove}
          beforeUpload={() => false}
          accept="image/*,.pdf,.doc,.docx,.txt"
          multiple
          maxCount={MAX_FILES}
          iconRender={(file) => {
            if (file.type?.startsWith('image/')) {
              return <UploadOutlined />;
            }
            return <FileOutlined />;
          }}
        >
          {fileList.length < MAX_FILES && (
            <div>
              <UploadOutlined />
              <div style={{ marginTop: 8 }}>
                {language === 'zh' ? '上传文件' : 'Upload'}
              </div>
            </div>
          )}
        </Upload>

        {/* 文件数量提示 */}
        {fileList.length > 0 && (
          <Text type="secondary" style={{ fontSize: '12px' }}>
            {language === 'zh'
              ? `已选择 ${fileList.length}/${MAX_FILES} 个文件`
              : `${fileList.length}/${MAX_FILES} files selected`}
          </Text>
        )}

        {/* 上传进度 */}
        {uploading && uploadProgress.total > 0 && (
          <div>
            <Text strong style={{ fontSize: '12px' }}>
              {language === 'zh' ? '上传进度' : 'Upload Progress'}
            </Text>
            <Progress
              percent={Math.round((uploadProgress.current / uploadProgress.total) * 100)}
              status="active"
              format={(percent) => `${uploadProgress.current}/${uploadProgress.total}`}
            />
          </div>
        )}

        {/* 文件大小错误提示 */}
        {sizeErrors.length > 0 && (
          <div style={{ background: '#fff7e6', padding: '12px', borderRadius: '4px', border: '1px solid #ffd591' }}>
            <Space direction="vertical" size="small" style={{ width: '100%' }}>
              {sizeErrors.map((error, index) => (
                <div key={index} style={{ color: '#d46b08' }}>
                  <ExclamationCircleOutlined /> {error}
                </div>
              ))}
            </Space>
          </div>
        )}

        {/* 上传错误提示 */}
        {errors.length > 0 && (
          <div style={{ background: '#fff2f0', padding: '12px', borderRadius: '4px', border: '1px solid #ffccc7' }}>
            <Space direction="vertical" size="small" style={{ width: '100%' }}>
              {errors.map((error, index) => (
                <div key={index} style={{ color: '#cf1322' }}>
                  <ExclamationCircleOutlined /> {error}
                </div>
              ))}
            </Space>
          </div>
        )}
      </Space>
    </Modal>
  );
};

export default ConfirmCompletionModal;
