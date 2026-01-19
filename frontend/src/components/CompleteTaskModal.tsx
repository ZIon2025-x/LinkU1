import React, { useState, useCallback, useRef } from 'react';
import { Modal, Upload, Button, Progress, message, Typography, Space } from 'antd';
import { UploadOutlined, DeleteOutlined, CheckCircleOutlined, ExclamationCircleOutlined } from '@ant-design/icons';
import type { UploadFile, UploadProps } from 'antd';
import { compressImage } from '../utils/imageCompression';
import { getErrorMessage } from '../utils/errorHandler';
import api, { completeTask } from '../api';
import { useLanguage } from '../contexts/LanguageContext';

const { Text } = Typography;

interface CompleteTaskModalProps {
  visible: boolean;
  taskId: number;
  onCancel: () => void;
  onSuccess: () => void;
}

const MAX_IMAGES = 5;
const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5MB

const CompleteTaskModal: React.FC<CompleteTaskModalProps> = ({
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

  // 处理文件选择
  const handleChange: UploadProps['onChange'] = useCallback((info) => {
    const newFileList = [...info.fileList];
    
    // 限制文件数量
    if (newFileList.length > MAX_IMAGES) {
      message.warning(
        language === 'zh' 
          ? `最多只能上传 ${MAX_IMAGES} 张图片` 
          : `Maximum ${MAX_IMAGES} images allowed`
      );
      return;
    }

    // 检查文件大小（压缩前）
    const newSizeErrors: string[] = [];
    const validFiles: UploadFile[] = [];
    
    newFileList.forEach((file, index) => {
      if (file.originFileObj) {
        const fileSize = file.originFileObj.size;
        if (fileSize > MAX_IMAGE_SIZE) {
          const sizeInMB = (fileSize / (1024 * 1024)).toFixed(1);
          newSizeErrors.push(
            language === 'zh'
              ? `第 ${index + 1} 张图片过大 (${sizeInMB}MB)，请选择较小的图片`
              : `Image ${index + 1} is too large (${sizeInMB}MB), please select a smaller image`
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

  // 上传图片
  const uploadImage = useCallback(async (file: File, taskId: number): Promise<string> => {
    try {
      // 压缩图片
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

      const formData = new FormData();
      formData.append('image', compressedFile);

      const response = await api.post(`/api/upload/image?task_id=${taskId}`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        signal: uploadAbortControllerRef.current?.signal,
      });

      if (response.data.success) {
        // 返回图片URL
        if (response.data.url) {
          return response.data.url;
        } else if (response.data.image_id) {
          // 如果没有URL但有image_id，需要生成URL
          // 这里暂时返回image_id，后端应该已经返回URL
          throw new Error(
            language === 'zh'
              ? '图片上传成功但无法获取访问URL'
              : 'Image uploaded but cannot get access URL'
          );
        } else {
          throw new Error(
            language === 'zh'
              ? '服务器未返回图片URL'
              : 'Server did not return image URL'
          );
        }
      } else {
        throw new Error(response.data.detail || '上传失败');
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
            ? `第 ${index + 1} 张图片：请求格式错误 - ${errorMessage}`
            : `Image ${index + 1}: Bad request - ${errorMessage}`;
        case 401:
          return language === 'zh'
            ? `第 ${index + 1} 张图片：未授权，请重新登录`
            : `Image ${index + 1}: Unauthorized, please login again`;
        case 403:
          return language === 'zh'
            ? `第 ${index + 1} 张图片：无权限上传`
            : `Image ${index + 1}: No permission to upload`;
        case 413:
          return language === 'zh'
            ? `第 ${index + 1} 张图片：文件过大`
            : `Image ${index + 1}: File too large`;
        case 500:
        case 502:
        case 503:
          return language === 'zh'
            ? `第 ${index + 1} 张图片：服务器错误 (${status})，请稍后重试`
            : `Image ${index + 1}: Server error (${status}), please try again later`;
        default:
          return language === 'zh'
            ? `第 ${index + 1} 张图片：服务器错误 (${status}) - ${errorMessage}`
            : `Image ${index + 1}: Server error (${status}) - ${errorMessage}`;
      }
    }

    if (error.message) {
      if (error.message.includes('Network Error') || error.message.includes('Failed to fetch')) {
        return language === 'zh'
          ? `第 ${index + 1} 张图片：网络连接失败，请检查网络设置`
          : `Image ${index + 1}: Network connection failed, please check network settings`;
      }
      if (error.message.includes('timeout')) {
        return language === 'zh'
          ? `第 ${index + 1} 张图片：上传超时，请重试`
          : `Image ${index + 1}: Upload timeout, please try again`;
      }
      return language === 'zh'
        ? `第 ${index + 1} 张图片：${error.message}`
        : `Image ${index + 1}: ${error.message}`;
    }

    return language === 'zh'
      ? `第 ${index + 1} 张图片：上传失败`
      : `Image ${index + 1}: Upload failed`;
  }, [language]);

  // 提交完成任务
  const handleSubmit = useCallback(async () => {
    if (fileList.length === 0) {
      // 没有图片，直接提交
      try {
        setUploading(true);
        await completeTask(taskId, []);
        message.success(
          language === 'zh'
            ? '任务已标记为完成'
            : 'Task marked as complete'
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

    // 检查压缩后的大小
    const newSizeErrors: string[] = [];
    const validFiles: UploadFile[] = [];

    for (let i = 0; i < fileList.length; i++) {
      const file = fileList[i];
      if (file.originFileObj) {
        try {
          // 尝试压缩以检查最终大小
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
        } catch (error) {
          newSizeErrors.push(
            language === 'zh'
              ? `第 ${i + 1} 张图片无法处理`
              : `Image ${i + 1} cannot be processed`
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
          ? '没有可上传的图片'
          : 'No valid images to upload'
      );
      return;
    }

    // 上传图片
    setUploading(true);
    setErrors([]);
    setUploadProgress({ current: 0, total: validFiles.length });
    uploadAbortControllerRef.current = new AbortController();

    const uploadedUrls: string[] = [];
    const uploadErrors: Array<{ error: any; index: number }> = [];

    for (let i = 0; i < validFiles.length; i++) {
      const file = validFiles[i];
      if (file.originFileObj) {
        try {
          const url = await uploadImage(file.originFileObj, taskId);
          uploadedUrls.push(url);
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

    // 提交完成任务
    try {
      await completeTask(taskId, uploadedUrls);
      message.success(
        language === 'zh'
          ? '任务已标记为完成'
          : 'Task marked as complete'
      );
      onSuccess();
      handleCancel();
    } catch (error: any) {
      const errorMsg = getErrorMessage(error);
      message.error(errorMsg);
    } finally {
      setUploading(false);
    }
  }, [fileList, taskId, language, uploadImage, getDetailedErrorMessage, onSuccess]);

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
          <span>{language === 'zh' ? '完成任务' : 'Complete Task'}</span>
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
            ? '确认完成任务'
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
              ? '您已完成此任务。请上传相关证据图片（可选），以便发布者确认任务完成情况。'
              : 'You have completed this task. Please upload relevant evidence images (optional) for the poster to confirm task completion.'}
          </Text>
        </div>

        {/* 图片大小限制提示 */}
        <div>
          <Space>
            <ExclamationCircleOutlined style={{ color: '#faad14' }} />
            <Text type="secondary" style={{ fontSize: '12px' }}>
              {language === 'zh'
                ? `单张图片不超过 5MB，最多上传 ${MAX_IMAGES} 张`
                : `Maximum 5MB per image, up to ${MAX_IMAGES} images`}
            </Text>
          </Space>
        </div>

        {/* 图片上传 */}
        <Upload
          listType="picture-card"
          fileList={fileList}
          onChange={handleChange}
          onRemove={handleRemove}
          beforeUpload={() => false}
          accept="image/*"
          multiple
          maxCount={MAX_IMAGES}
        >
          {fileList.length < MAX_IMAGES && (
            <div>
              <UploadOutlined />
              <div style={{ marginTop: 8 }}>
                {language === 'zh' ? '上传图片' : 'Upload'}
              </div>
            </div>
          )}
        </Upload>

        {/* 图片数量提示 */}
        {fileList.length > 0 && (
          <Text type="secondary" style={{ fontSize: '12px' }}>
            {language === 'zh'
              ? `已选择 ${fileList.length}/${MAX_IMAGES} 张图片`
              : `${fileList.length}/${MAX_IMAGES} images selected`}
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

        {/* 图片大小错误提示 */}
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

export default CompleteTaskModal;
