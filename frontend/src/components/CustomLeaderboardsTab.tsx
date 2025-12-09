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
import { formatViewCount } from '../utils/formatUtils';
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
            // 处理不同类型的错误
      if (error.response?.status === 401) {
        message.error(t('forum.pleaseLogin'));
      } else if (error.response?.status === 403) {
        message.error(t('forum.noPermission'));
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.warning(`请求过于频繁，请在 ${retryAfter} 秒后重试`);
      } else if (error.response?.status >= 500) {
        message.error('服务器错误，请稍后重试');
      } else {
        message.error(error.response?.data?.detail || t('forum.loadingFailed'));
      }
    } finally {
      setLoading(false);
    }
  };

  const handleImageUpload = async (file: File): Promise<string> => {
    try {
      setUploadingCoverImage(true);
            // 压缩图片
      const compressedFile = await compressImage(file, {
        maxSizeMB: 1,
        maxWidthOrHeight: 1920,
      });
      
            const formData = new FormData();
      formData.append('image', compressedFile);
      
      // 使用 leaderboard_cover category
      const resourceId = user?.id ? `temp_${user.id}` : 'temp_anonymous';
      const uploadUrl = `/api/upload/public-image?category=leaderboard_cover&resource_id=${encodeURIComponent(resourceId)}`;
                  const response = await api.post(
        uploadUrl,
        formData,
        {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        }
      );
      
            if (response.data.success && response.data.url) {
                return response.data.url;
      } else {
                throw new Error('上传失败：响应格式错误');
      }
    } catch (error: any) {
            const errorMessage = error.response?.data?.detail || error.response?.data?.message || error.message || t('forum.imageUploadFailed');
      message.error(`${t('forum.imageUploadFailed')}: ${errorMessage}`);
      throw error;
    } finally {
      setUploadingCoverImage(false);
    }
  };

  const handleCoverImageChange = async (info: any) => {
    const { file, fileList } = info;
    
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
                return;
      }
      
      try {
                const url = await handleImageUpload(fileToUpload);
                setCoverImageUrl(url);
        form.setFieldsValue({ cover_image: url });
        message.success(t('forum.imageUploadSuccess'));
      } catch (error) {
                // 错误已在handleImageUpload中处理
      }
    } else {
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
      message.success(t('forum.applySubmitted'));
      setShowApplyModal(false);
      form.resetFields();
      setCoverImageUrl('');
      loadLeaderboards();
    } catch (error: any) {
            const errorMsg = error.response?.data?.detail || error.message || t('forum.applyFailed');
      
      // 处理不同类型的错误
      if (error.response?.status === 400) {
        if (errorMsg.includes('已存在')) {
          message.error(t('forum.leaderboardExists'));
        } else {
          message.error(errorMsg);
        }
      } else if (error.response?.status === 401) {
        message.error(t('forum.pleaseLogin'));
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(t('forum.operationTooFrequent', { retryAfter }));
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
      <div className="leaderboard-filters" style={{ marginBottom: 16, display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <Select
          placeholder={t('forum.selectLocation')}
          className="filter-select"
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
          placeholder={t('forum.sortBy')}
          className="filter-select"
          style={{ width: 150 }}
          value={sortBy}
          onChange={setSortBy}
        >
          <Option value="latest">
            <ClockCircleOutlined /> {t('forum.latest')}
          </Option>
          <Option value="hot">
            <FireOutlined /> {t('forum.hot')}
          </Option>
          <Option value="votes">{t('forum.votes')}</Option>
          <Option value="items">{t('forum.items')}</Option>
        </Select>
        
        <Input.Search
          placeholder={t('forum.searchLeaderboard')}
          className="filter-search"
          style={{ flex: 1, minWidth: 200, maxWidth: 400 }}
          value={searchKeyword}
          onChange={(e) => setSearchKeyword(e.target.value)}
          allowClear
        />
        
        <Button
          type="primary"
          icon={<PlusOutlined />}
          className="apply-button"
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
          {t('forum.applyNewLeaderboard')}
        </Button>
      </div>

      {/* 榜单列表 */}
      <Spin spinning={loading}>
        {leaderboards.length === 0 && !loading ? (
          <Empty description={t('forum.noLeaderboards')} />
        ) : (
          <>
            <div className="leaderboard-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))', gap: 20 }}>
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
                          {t('forum.itemCount')}
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
                          {t('forum.voteCount')}
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
                          {formatViewCount(leaderboard.view_count || 0)}
                        </div>
                        <div style={{
                          fontSize: 12,
                          color: '#999'
                        }}>
                          {t('forum.viewCount')}
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
                      {t('forum.applicant')}：{leaderboard.applicant?.name || leaderboard.applicant_id || t('forum.anonymous')}
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
                      {t('forum.viewDetails')}
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
                  showTotal={(total) => t('forum.totalLeaderboards', { total })}
                />
              </div>
            )}
          </>
        )}
      </Spin>

      {/* 申请榜单弹窗 */}
      <Modal
        title={t('forum.applyNewLeaderboard')}
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
            label={t('forum.leaderboardName')}
            rules={[{ required: true, message: t('forum.enterLeaderboardName') }]}
          >
            <Input placeholder={t('forum.leaderboardNamePlaceholder')} />
          </Form.Item>
          
          <Form.Item
            name="location"
            label={t('forum.location')}
            rules={[{ required: true, message: t('forum.selectLocationRequired') }]}
          >
            <Select placeholder={t('forum.selectLocationPlaceholder')}>
              {LOCATIONS.map(loc => (
                <Option key={loc} value={loc}>{loc}</Option>
              ))}
            </Select>
          </Form.Item>
          
          <Form.Item
            name="description"
            label={t('forum.leaderboardDescription')}
          >
            <Input.TextArea rows={4} placeholder={t('forum.leaderboardDescriptionPlaceholder')} />
          </Form.Item>
          
          <Form.Item
            name="application_reason"
            label={t('forum.applicationReason')}
            rules={[{ required: true, message: t('forum.applicationReasonRequired') }]}
          >
            <Input.TextArea rows={3} placeholder={t('forum.applicationReasonPlaceholder')} />
          </Form.Item>
          
          <Form.Item
            name="cover_image"
            label={t('forum.coverImage')}
            extra={t('forum.coverImageExtra')}
          >
            <Upload
              listType="picture-card"
              maxCount={1}
              beforeUpload={(file) => {
                // 阻止默认上传，手动处理
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
                  <div style={{ marginTop: 8 }}>{t('forum.uploadImage')}</div>
                </div>
              )}
            </Upload>
            {coverImageUrl && (
              <div style={{ marginTop: 8 }}>
                <Image
                  src={coverImageUrl}
                  alt={t('forum.coverPreview')}
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

            /* 移动端筛选器优化 */
            .leaderboard-filters {
              flex-direction: column !important;
              gap: 10px !important;
            }

            .filter-select,
            .filter-search {
              width: 100% !important;
              max-width: 100% !important;
              min-width: 100% !important;
            }

            .apply-button {
              width: 100% !important;
            }

            /* 移动端网格优化 */
            .leaderboard-grid {
              grid-template-columns: 1fr !important;
              gap: 16px !important;
            }

            .leaderboard-card {
              border-radius: 12px !important;
            }
          }

          /* 超小屏幕优化 */
          @media (max-width: 480px) {
            .leaderboard-filters {
              gap: 8px !important;
            }

            .leaderboard-grid {
              gap: 12px !important;
            }
          }
        `}
      </style>
    </div>
  );
};

export default CustomLeaderboardsTab;

