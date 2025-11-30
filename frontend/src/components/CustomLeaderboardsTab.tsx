import React, { useState, useEffect, useCallback } from 'react';
import { Card, Button, Select, Modal, Form, message, Empty, Tag, Input, Pagination, Spin, Upload, Image } from 'antd';
import { PlusOutlined, TrophyOutlined, FireOutlined, ClockCircleOutlined, UploadOutlined, DeleteOutlined } from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import {
  applyCustomLeaderboard,
  getCustomLeaderboards
} from '../api';
import { fetchCurrentUser } from '../api';
import { LOCATIONS } from '../constants/leaderboard';
import LoginModal from './LoginModal';
import { compressImage } from '../utils/imageCompression';
import api from '../api';

const { Option } = Select;

interface CustomLeaderboardsTabProps {
  onShowLogin?: () => void;
}

const CustomLeaderboardsTab: React.FC<CustomLeaderboardsTabProps> = ({ onShowLogin }) => {
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const [leaderboards, setLeaderboards] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [selectedLocation, setSelectedLocation] = useState<string>('');
  const [searchKeyword, setSearchKeyword] = useState<string>('');
  const [sortBy, setSortBy] = useState<'latest' | 'hot' | 'votes' | 'items'>('latest');
  const [user, setUser] = useState<any>(null);
  const [form] = Form.useForm();
  const [pagination, setPagination] = useState({
    current: 1,
    pageSize: 20,
    total: 0,
    hasMore: false
  });
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [coverImageUrl, setCoverImageUrl] = useState<string>('');
  const [uploadingCoverImage, setUploadingCoverImage] = useState(false);

  // 防抖搜索
  const [searchTimer, setSearchTimer] = useState<NodeJS.Timeout | null>(null);

  useEffect(() => {
    loadLeaderboards();
    fetchCurrentUser().then(setUser).catch(() => setUser(null));
  }, [selectedLocation, sortBy]);

  useEffect(() => {
    // 搜索防抖
    if (searchTimer) {
      clearTimeout(searchTimer);
    }
    const timer = setTimeout(() => {
      loadLeaderboards();
    }, 500);
    setSearchTimer(timer);
    return () => {
      if (timer) clearTimeout(timer);
    };
  }, [searchKeyword]);

  const loadLeaderboards = async (page: number = 1) => {
    try {
      setLoading(true);
      const offset = (page - 1) * pagination.pageSize;
      const response = await getCustomLeaderboards({
        location: selectedLocation || undefined,
        keyword: searchKeyword || undefined,
        status: 'active',
        sort: sortBy,
        limit: pagination.pageSize,
        offset
      });
      
      if (response && response.items) {
        setLeaderboards(response.items || []);
        setPagination(prev => ({
          ...prev,
          current: page,
          total: response.total || 0,
          hasMore: response.has_more || false
        }));
      } else {
        // 兼容旧格式
        setLeaderboards(response || []);
      }
    } catch (error: any) {
      console.error('加载排行榜失败:', error);
      
      // 处理不同类型的错误
      if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限访问');
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.warning(`请求过于频繁，请在 ${retryAfter} 秒后重试`);
      } else if (error.response?.status >= 500) {
        message.error('服务器错误，请稍后重试');
      } else {
        message.error(error.response?.data?.detail || '加载失败，请稍后重试');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleImageUpload = async (file: File): Promise<string> => {
    try {
      setUploadingCoverImage(true);
      console.log('开始压缩图片:', file.name, file.size);
      
      // 压缩图片
      const compressedFile = await compressImage(file, {
        maxSizeMB: 1,
        maxWidthOrHeight: 1920,
      });
      
      console.log('图片压缩完成:', compressedFile.name, compressedFile.size);
      
      const formData = new FormData();
      formData.append('image', compressedFile);
      
      // 使用 leaderboard_cover category
      const resourceId = user?.id ? `temp_${user.id}` : 'temp_anonymous';
      const uploadUrl = `/api/upload/public-image?category=leaderboard_cover&resource_id=${encodeURIComponent(resourceId)}`;
      console.log('上传URL:', uploadUrl);
      console.log('resourceId:', resourceId);
      
      const response = await api.post(
        uploadUrl,
        formData,
        {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        }
      );
      
      console.log('上传响应:', response.data);
      
      if (response.data.success && response.data.url) {
        console.log('上传成功，URL:', response.data.url);
        return response.data.url;
      } else {
        console.error('上传响应格式错误:', response.data);
        throw new Error('上传失败：响应格式错误');
      }
    } catch (error: any) {
      console.error('图片上传失败:', error);
      const errorMessage = error.response?.data?.detail || error.response?.data?.message || error.message || '上传失败';
      message.error(`图片上传失败: ${errorMessage}`);
      throw error;
    } finally {
      setUploadingCoverImage(false);
    }
  };

  const handleCoverImageChange = async (info: any) => {
    const { file, fileList } = info;
    
    console.log('handleCoverImageChange 触发:', {
      fileStatus: file.status,
      hasOriginFileObj: !!file.originFileObj,
      fileUid: file.uid,
      fileListLength: fileList.length
    });
    
    // 处理文件删除
    if (file.status === 'removed') {
      setCoverImageUrl('');
      form.setFieldsValue({ cover_image: '' });
      return;
    }
    
    // 当用户选择新文件时（beforeUpload 返回 false 时，file 对象本身就是 File 对象）
    const fileToUpload = file.originFileObj || (file instanceof File ? file : null);
    
    if (fileToUpload) {
      // 检查是否已经在处理中（避免重复上传）
      if (uploadingCoverImage) {
        console.log('正在上传中，跳过');
        return;
      }
      
      try {
        console.log('开始上传封面图片:', fileToUpload.name);
        const url = await handleImageUpload(fileToUpload);
        console.log('封面图片上传成功:', url);
        setCoverImageUrl(url);
        form.setFieldsValue({ cover_image: url });
        message.success('图片上传成功');
      } catch (error) {
        console.error('封面图片上传失败:', error);
        // 错误已在handleImageUpload中处理
      }
    } else {
      console.log('无法获取文件对象，跳过处理:', file);
    }
  };

  const handleRemoveCoverImage = () => {
    setCoverImageUrl('');
    form.setFieldsValue({ cover_image: '' });
  };

  const handleApply = async (values: any) => {
    try {
      // 确保 cover_image 被包含在提交的数据中
      const submitData = {
        ...values,
        cover_image: coverImageUrl || values.cover_image || null
      };
      await applyCustomLeaderboard(submitData);
      message.success('榜单申请已提交，等待审核');
      setShowApplyModal(false);
      form.resetFields();
      setCoverImageUrl('');
      loadLeaderboards();
    } catch (error: any) {
      console.error('申请榜单失败:', error);
      const errorMsg = error.response?.data?.detail || error.message || '申请失败';
      
      // 处理不同类型的错误
      if (error.response?.status === 400) {
        if (errorMsg.includes('已存在')) {
          message.error('该地区已存在相同名称的榜单');
        } else {
          message.error(errorMsg);
        }
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(`操作过于频繁，请在 ${retryAfter} 秒后重试`);
      } else {
        message.error(errorMsg);
      }
    }
  };

  const handlePageChange = (page: number) => {
    loadLeaderboards(page);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <div>
      {/* 筛选、搜索和申请按钮 */}
      <div style={{ marginBottom: 16, display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <Select
          placeholder="选择地区"
          style={{ width: 150 }}
          allowClear
          value={selectedLocation}
          onChange={(value) => {
            setSelectedLocation(value || '');
          }}
          onClear={() => {
            setSelectedLocation('');
          }}
          getPopupContainer={(triggerNode) => triggerNode.parentElement || document.body}
        >
          {LOCATIONS.map(loc => (
            <Option key={loc} value={loc}>{loc}</Option>
          ))}
        </Select>
        
        <Select
          placeholder="排序方式"
          style={{ width: 150 }}
          value={sortBy}
          onChange={setSortBy}
        >
          <Option value="latest">
            <ClockCircleOutlined /> 最新
          </Option>
          <Option value="hot">
            <FireOutlined /> 热门
          </Option>
          <Option value="votes">投票数</Option>
          <Option value="items">竞品数</Option>
        </Select>
        
        <Input.Search
          placeholder="搜索榜单名称或描述"
          style={{ flex: 1, minWidth: 200, maxWidth: 400 }}
          value={searchKeyword}
          onChange={(e) => setSearchKeyword(e.target.value)}
          allowClear
        />
        
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={() => {
            if (!user) {
              if (onShowLogin) {
                onShowLogin();
              } else {
                setShowLoginModal(true);
              }
              return;
            }
            setShowApplyModal(true);
          }}
        >
          申请新榜单
        </Button>
      </div>

      {/* 榜单列表 */}
      <Spin spinning={loading}>
        {leaderboards.length === 0 && !loading ? (
          <Empty description="暂无榜单" />
        ) : (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))', gap: 20 }}>
              {leaderboards.map(leaderboard => (
                <div
                  key={leaderboard.id}
                  style={{
                    background: 'white',
                    borderRadius: 12,
                    overflow: 'hidden',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                    transition: 'transform 0.2s, box-shadow 0.2s',
                    cursor: 'pointer'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'translateY(-4px)';
                    e.currentTarget.style.boxShadow = '0 8px 20px rgba(0,0,0,0.15)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.1)';
                  }}
                  onClick={() => {
                    const lang = language || 'zh';
                    navigate(`/${lang}/leaderboard/custom/${leaderboard.id}`);
                  }}
                >
                  {/* Header Section - 使用封面图片或渐变色背景 */}
                  <div style={{
                    background: leaderboard.cover_image 
                      ? `linear-gradient(rgba(0,0,0,0.4), rgba(0,0,0,0.4)), url(${leaderboard.cover_image})`
                      : 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                    padding: '20px',
                    color: 'white',
                    minHeight: '120px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between'
                  }}>
                    <div style={{
                      fontSize: 22,
                      fontWeight: 'bold',
                      marginBottom: 8,
                      textShadow: '0 2px 4px rgba(0,0,0,0.3)'
                    }}>
                      {leaderboard.name}
                    </div>
                    <div style={{
                      fontSize: 14,
                      opacity: 0.95,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 4,
                      textShadow: '0 1px 2px rgba(0,0,0,0.3)'
                    }}>
                      <span>📍</span>
                      <span>{leaderboard.location}</span>
                    </div>
                  </div>

                  {/* Content Section */}
                  <div style={{ padding: '20px' }}>
                    {leaderboard.description && (
                      <div style={{
                        fontSize: 14,
                        color: '#666',
                        lineHeight: 1.6,
                        marginBottom: 20,
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden'
                      }}>
                        {leaderboard.description}
                      </div>
                    )}

                    {/* Stats Grid */}
                    <div style={{
                      display: 'grid',
                      gridTemplateColumns: 'repeat(3, 1fr)',
                      gap: 16,
                      marginBottom: 16
                    }}>
                      <div style={{
                        textAlign: 'center',
                        padding: 12,
                        background: '#f5f5f5',
                        borderRadius: 8
                      }}>
                        <div style={{
                          fontSize: 20,
                          fontWeight: 'bold',
                          color: '#667eea',
                          marginBottom: 4
                        }}>
                          {leaderboard.item_count || 0}
                        </div>
                        <div style={{
                          fontSize: 12,
                          color: '#999'
                        }}>
                          竞品数
                        </div>
                      </div>
                      <div style={{
                        textAlign: 'center',
                        padding: 12,
                        background: '#f5f5f5',
                        borderRadius: 8
                      }}>
                        <div style={{
                          fontSize: 20,
                          fontWeight: 'bold',
                          color: '#667eea',
                          marginBottom: 4
                        }}>
                          {leaderboard.vote_count || 0}
                        </div>
                        <div style={{
                          fontSize: 12,
                          color: '#999'
                        }}>
                          投票数
                        </div>
                      </div>
                      <div style={{
                        textAlign: 'center',
                        padding: 12,
                        background: '#f5f5f5',
                        borderRadius: 8
                      }}>
                        <div style={{
                          fontSize: 20,
                          fontWeight: 'bold',
                          color: '#667eea',
                          marginBottom: 4
                        }}>
                          {leaderboard.view_count || 0}
                        </div>
                        <div style={{
                          fontSize: 12,
                          color: '#999'
                        }}>
                          浏览量
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Footer */}
                  <div style={{
                    padding: '16px 20px',
                    background: '#f9f9f9',
                    borderTop: '1px solid #eee',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center'
                  }}>
                    <div style={{
                      fontSize: 12,
                      color: '#999'
                    }}>
                      申请者：{leaderboard.applicant?.name || leaderboard.applicant_id || '匿名'}
                    </div>
                    <button
                      style={{
                        padding: '6px 16px',
                        background: '#667eea',
                        color: 'white',
                        border: 'none',
                        borderRadius: 6,
                        fontSize: 14,
                        cursor: 'pointer',
                        transition: 'background 0.2s'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#5568d3';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = '#667eea';
                      }}
                      onClick={(e) => {
                        e.stopPropagation();
                        const lang = language || 'zh';
                        navigate(`/${lang}/leaderboard/custom/${leaderboard.id}`);
                      }}
                    >
                      查看详情
                    </button>
                  </div>
                </div>
              ))}
            </div>
            
            {/* 分页 */}
            {pagination.total > 0 && (
              <div style={{ marginTop: 24, display: 'flex', justifyContent: 'center' }}>
                <Pagination
                  current={pagination.current}
                  pageSize={pagination.pageSize}
                  total={pagination.total}
                  onChange={handlePageChange}
                  showSizeChanger={false}
                  showQuickJumper
                  showTotal={(total) => `共 ${total} 个榜单`}
                />
              </div>
            )}
          </>
        )}
      </Spin>

      {/* 申请榜单弹窗 */}
      <Modal
        title="申请新榜单"
        open={showApplyModal}
        onCancel={() => {
          setShowApplyModal(false);
          form.resetFields();
          setCoverImageUrl('');
        }}
        confirmLoading={uploadingCoverImage}
        onOk={() => form.submit()}
        width={600}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleApply}
        >
          <Form.Item
            name="name"
            label="榜单名称"
            rules={[{ required: true, message: '请输入榜单名称' }]}
          >
            <Input placeholder="例如：London中餐榜" />
          </Form.Item>
          
          <Form.Item
            name="location"
            label="地区"
            rules={[{ required: true, message: '请选择地区' }]}
          >
            <Select placeholder="选择地区">
              {LOCATIONS.map(loc => (
                <Option key={loc} value={loc}>{loc}</Option>
              ))}
            </Select>
          </Form.Item>
          
          <Form.Item
            name="description"
            label="榜单描述"
          >
            <Input.TextArea rows={4} placeholder="描述这个榜单的目的和范围" />
          </Form.Item>
          
          <Form.Item
            name="application_reason"
            label="申请理由"
            rules={[{ required: true, message: '请说明申请理由' }]}
          >
            <Input.TextArea rows={3} placeholder="为什么需要创建这个榜单？" />
          </Form.Item>
          
          <Form.Item
            name="cover_image"
            label="榜单封面图片（可选）"
            extra="上传一张图片作为榜单封面，将显示在榜单卡片顶部"
          >
            <Upload
              listType="picture-card"
              maxCount={1}
              beforeUpload={(file) => {
                // 阻止默认上传，手动处理
                console.log('beforeUpload 触发:', file.name);
                return false;
              }}
              onChange={handleCoverImageChange}
              onRemove={handleRemoveCoverImage}
              accept="image/*"
              fileList={coverImageUrl ? [{
                uid: '-1',
                name: 'cover-image.jpg',
                status: 'done',
                url: coverImageUrl
              }] : []}
              showUploadList={{
                showPreviewIcon: true,
                showRemoveIcon: true
              }}
            >
              {coverImageUrl ? null : (
                <div>
                  <UploadOutlined />
                  <div style={{ marginTop: 8 }}>上传图片</div>
                </div>
              )}
            </Upload>
            {coverImageUrl && (
              <div style={{ marginTop: 8 }}>
                <Image
                  src={coverImageUrl}
                  alt="封面预览"
                  style={{ maxWidth: '100%', maxHeight: 200, borderRadius: 4 }}
                  preview
                />
              </div>
            )}
          </Form.Item>
        </Form>
      </Modal>

      {/* 登录弹窗 */}
      <LoginModal 
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          window.location.reload();
        }}
        onReopen={() => {
          setShowLoginModal(true);
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => {
          setShowForgotPasswordModal(true);
        }}
        onHideForgotPassword={() => {
          setShowForgotPasswordModal(false);
        }}
      />

      {/* 移动端样式优化 */}
      <style>
        {`
          /* 移动端 Select 清除按钮优化 */
          @media (max-width: 768px) {
            /* 确保清除按钮在移动端可点击 */
            .ant-select-clear {
              pointer-events: auto !important;
              touch-action: manipulation !important;
              -webkit-tap-highlight-color: rgba(0, 0, 0, 0.1) !important;
              z-index: 10 !important;
            }

            /* 增加清除按钮的点击区域 */
            .ant-select-clear-icon {
              width: 20px !important;
              height: 20px !important;
              padding: 4px !important;
              margin: 0 !important;
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
              pointer-events: auto !important;
              touch-action: manipulation !important;
            }

            /* 确保清除按钮不被遮挡 */
            .ant-select-selector {
              position: relative !important;
            }

            .ant-select-selection-item {
              padding-right: 24px !important;
            }

            /* 防止点击清除按钮时触发下拉菜单 */
            .ant-select-clear-icon:active {
              background-color: rgba(0, 0, 0, 0.06) !important;
              border-radius: 50% !important;
            }
          }
        `}
      </style>
    </div>
  );
};

export default CustomLeaderboardsTab;

