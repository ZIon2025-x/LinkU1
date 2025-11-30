import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Button, Input, Space, Tag, Spin, Empty, Modal, Form, message, Checkbox, Select, Pagination, Image, Upload } from 'antd';
import { LikeOutlined, DislikeOutlined, PlusOutlined, TrophyOutlined, PhoneOutlined, GlobalOutlined, EnvironmentOutlined, UploadOutlined, DeleteOutlined, ExclamationCircleOutlined } from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { TimeHandlerV2 } from '../utils/timeUtils';
import {
  getCustomLeaderboardDetail,
  getLeaderboardItems,
  submitLeaderboardItem,
  voteLeaderboardItem,
  reportLeaderboard
} from '../api';
import { fetchCurrentUser } from '../api';
import { LOCATIONS } from '../constants/leaderboard';
import { compressImage } from '../utils/imageCompression';
import api from '../api';

const { Option } = Select;

const CustomLeaderboardDetail: React.FC = () => {
  const { leaderboardId } = useParams<{ leaderboardId: string }>();
  const { t, language } = useLanguage();
  const navigate = useNavigate();
  const [leaderboard, setLeaderboard] = useState<any>(null);
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [showSubmitModal, setShowSubmitModal] = useState(false);
  const [showVoteModal, setShowVoteModal] = useState(false);
  const [currentVoteItemId, setCurrentVoteItemId] = useState<number | null>(null);
  const [currentVoteType, setCurrentVoteType] = useState<'upvote' | 'downvote' | null>(null);
  const [user, setUser] = useState<any>(null);
  const [form] = Form.useForm();
  const [voteForm] = Form.useForm();
  const [reportForm] = Form.useForm();
  const [showReportModal, setShowReportModal] = useState(false);
  const [sortBy, setSortBy] = useState<'vote_score' | 'net_votes' | 'upvotes' | 'created_at'>('vote_score');
  const [pagination, setPagination] = useState({
    current: 1,
    pageSize: 20,
    total: 0,
    hasMore: false
  });
  const [uploadingImages, setUploadingImages] = useState<string[]>([]);
  const [uploading, setUploading] = useState(false);
  const [uploadingFileList, setUploadingFileList] = useState<any[]>([]);
  const previewUrlsRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    if (leaderboardId) {
      loadData();
      fetchCurrentUser().then(setUser).catch(() => setUser(null));
    }
    
    // 组件卸载时清理所有临时预览 URL
    return () => {
      previewUrlsRef.current.forEach(url => {
        if (url.startsWith('blob:')) {
          URL.revokeObjectURL(url);
        }
      });
      previewUrlsRef.current.clear();
    };
  }, [leaderboardId, sortBy]);

  const loadData = async (page: number = 1) => {
    try {
      setLoading(true);
      const offset = (page - 1) * pagination.pageSize;
      const [leaderboardData, itemsData] = await Promise.all([
        getCustomLeaderboardDetail(Number(leaderboardId)),
        getLeaderboardItems(Number(leaderboardId), { 
          sort: sortBy, 
          limit: pagination.pageSize,
          offset
        })
      ]);
      setLeaderboard(leaderboardData);
      
      if (itemsData && itemsData.items) {
        setItems(itemsData.items || []);
        setPagination(prev => ({
          ...prev,
          current: page,
          total: itemsData.total || 0,
          hasMore: itemsData.has_more || false
        }));
      } else {
        // 兼容旧格式
        setItems(itemsData || []);
      }
    } catch (error: any) {
      console.error('加载失败:', error);
      
      // 处理不同类型的错误
      if (error.response?.status === 404) {
        message.error('榜单不存在或已被删除');
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限访问此榜单');
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

  const handleVote = async (itemId: number, voteType: 'upvote' | 'downvote') => {
    if (!user) {
      message.warning('请先登录');
      return;
    }

    const item = items.find(i => i.id === itemId);
    if (item && item.user_vote === voteType) {
      try {
        await voteLeaderboardItem(itemId, 'remove');
        message.success('投票已取消');
        loadData();
      } catch (error: any) {
        message.error(error.response?.data?.detail || '取消投票失败');
      }
    } else {
      setCurrentVoteItemId(itemId);
      setCurrentVoteType(voteType);
      setShowVoteModal(true);
      voteForm.resetFields();
    }
  };

  const handleVoteSubmit = async (values: { comment?: string; is_anonymous?: boolean }) => {
    if (!currentVoteItemId || !currentVoteType) return;

    try {
      const res = await voteLeaderboardItem(
        currentVoteItemId,
        currentVoteType,
        values.comment,
        values.is_anonymous || false
      );
      message.success('投票成功');
      setShowVoteModal(false);
      voteForm.resetFields();
      
      setItems(prev => prev.map(i =>
        i.id === currentVoteItemId ? {
          ...i,
          upvotes: res.upvotes,
          downvotes: res.downvotes,
          net_votes: res.net_votes,
          vote_score: res.vote_score,
          user_vote: currentVoteType,
          user_vote_comment: values.comment || null,
          user_vote_is_anonymous: values.is_anonymous || false,
        } : i
      ));
      
      // 重新排序（如果按vote_score排序）
      if (sortBy === 'vote_score') {
        setItems(prev => [...prev].sort((a, b) => b.vote_score - a.vote_score));
      }
    } catch (error: any) {
      console.error('投票失败:', error);
      const errorMsg = error.response?.data?.detail || error.message || '投票失败';
      
      // 处理速率限制错误
      if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(`操作过于频繁，请在 ${retryAfter} 秒后重试`);
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限执行此操作');
      } else {
        message.error(errorMsg);
      }
    }
  };

  const handleImageUpload = async (file: File): Promise<string> => {
    try {
      setUploading(true);
      // 压缩图片
      const compressedFile = await compressImage(file, {
        maxSizeMB: 1,
        maxWidthOrHeight: 1920,
      });
      
      const formData = new FormData();
      formData.append('image', compressedFile);
      
      // 使用 leaderboard_item category，便于分类管理
      // 传递 resource_id 为临时标识（因为上传时 item 还未创建）
      const resourceId = user?.id ? `temp_${user.id}` : 'temp_anonymous';
      const response = await api.post(
        `/api/upload/public-image?category=leaderboard_item&resource_id=${encodeURIComponent(resourceId)}`,
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
        throw new Error('上传失败');
      }
    } catch (error: any) {
      console.error('图片上传失败:', error);
      message.error(`图片上传失败: ${error.response?.data?.detail || error.message}`);
      throw error;
    } finally {
      setUploading(false);
    }
  };

  const handleImageChange = (info: any) => {
    const { file, fileList } = info;
    
    console.log('handleImageChange 触发:', {
      fileStatus: file.status,
      hasOriginFileObj: !!file.originFileObj,
      fileUid: file.uid,
      fileListLength: fileList.length
    });
    
    // 处理文件删除
    if (file.status === 'removed') {
      // 清理预览 URL
      if (file.url && file.url.startsWith('blob:') && previewUrlsRef.current.has(file.url)) {
        URL.revokeObjectURL(file.url);
        previewUrlsRef.current.delete(file.url);
      }
      if (file.thumbUrl && file.thumbUrl.startsWith('blob:') && previewUrlsRef.current.has(file.thumbUrl)) {
        URL.revokeObjectURL(file.thumbUrl);
        previewUrlsRef.current.delete(file.thumbUrl);
      }
      
      // 从上传列表中移除
      setUploadingFileList(prev => prev.filter(f => f.uid !== file.uid));
      return;
    }
    
    // 当用户选择新文件时
    // beforeUpload 返回 false 时，file 可能没有 status 或 status 为 undefined
    // 关键：检查是否有 originFileObj，这表示是新选择的文件
    if (file.originFileObj) {
      const fileToUpload = file.originFileObj;
      
      // 检查是否已经在列表中（避免重复添加）
      const existingFile = uploadingFileList.find(f => 
        f.originFileObj === fileToUpload || 
        (f.name === fileToUpload.name && f.size === fileToUpload.size)
      );
      
      if (existingFile) {
        console.log('文件已存在，跳过:', fileToUpload.name);
        return;
      }
      
      const tempId = `temp-${Date.now()}-${Math.random()}`;
      
      // 创建临时预览 URL
      const previewUrl = URL.createObjectURL(fileToUpload);
      previewUrlsRef.current.add(previewUrl);
      
      console.log('创建新文件预览:', {
        tempId,
        fileName: fileToUpload.name,
        previewUrl: previewUrl.substring(0, 50) + '...'
      });
      
      // 立即添加到上传列表，显示上传中状态和预览
      const newFile = {
        uid: tempId,
        name: fileToUpload.name,
        status: 'uploading' as const,
        url: previewUrl, // 临时预览 URL
        originFileObj: fileToUpload,
        thumbUrl: previewUrl // 缩略图预览
      };
      
      setUploadingFileList(prev => {
        const newList = [...prev, newFile];
        console.log('更新上传列表，当前文件数:', newList.length);
        return newList;
      });
      
      // 延迟执行压缩和上传，避免阻塞 UI
      setTimeout(async () => {
        try {
          console.log('开始上传图片:', fileToUpload.name);
          const url = await handleImageUpload(fileToUpload);
          console.log('图片上传成功:', url);
          
          // 清理临时预览 URL
          if (newFile.url && previewUrlsRef.current.has(newFile.url)) {
            URL.revokeObjectURL(newFile.url);
            previewUrlsRef.current.delete(newFile.url);
          }
          
          // 更新文件状态为完成
          setUploadingFileList(prev => prev.map(f => 
            f.uid === tempId 
              ? { ...f, status: 'done' as const, url, thumbUrl: url }
              : f
          ));
          
          // 添加到已上传图片列表
          setUploadingImages(prev => [...prev, url]);
          message.success('图片上传成功');
        } catch (error) {
          console.error('图片上传失败:', error);
          // 清理临时预览 URL
          if (newFile.url && previewUrlsRef.current.has(newFile.url)) {
            URL.revokeObjectURL(newFile.url);
            previewUrlsRef.current.delete(newFile.url);
          }
          
          // 上传失败，移除该文件
          setUploadingFileList(prev => prev.filter(f => f.uid !== tempId));
          // 错误已在handleImageUpload中处理
        }
      }, 0);
    } else {
      console.log('文件没有 originFileObj，跳过处理:', file);
    }
  };

  const handleRemoveImage = (url: string) => {
    setUploadingImages(prev => prev.filter(img => img !== url));
  };

  const handleSubmitItem = async (values: any) => {
    try {
      await submitLeaderboardItem({
        leaderboard_id: Number(leaderboardId),
        ...values,
        images: uploadingImages.length > 0 ? uploadingImages : undefined
      });
      message.success('竞品新增成功');
      setShowSubmitModal(false);
      form.resetFields();
      
      // 清理所有临时预览 URL
      uploadingFileList.forEach(file => {
        if (file.url && file.url.startsWith('blob:') && previewUrlsRef.current.has(file.url)) {
          URL.revokeObjectURL(file.url);
          previewUrlsRef.current.delete(file.url);
        }
        if (file.thumbUrl && file.thumbUrl.startsWith('blob:') && previewUrlsRef.current.has(file.thumbUrl)) {
          URL.revokeObjectURL(file.thumbUrl);
          previewUrlsRef.current.delete(file.thumbUrl);
        }
      });
      
      setUploadingImages([]);
      setUploadingFileList([]);
      // 重置到第一页并重新加载
      setPagination(prev => ({ ...prev, current: 1 }));
      loadData(1);
    } catch (error: any) {
      console.error('新增竞品失败:', error);
      const errorMsg = error.response?.data?.detail || error.message || '新增失败';
      
      // 处理不同类型的错误
      if (error.response?.status === 400) {
        if (errorMsg.includes('已存在')) {
          message.error('该榜单中已存在相同名称的竞品');
        } else {
          message.error(errorMsg);
        }
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限执行此操作');
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(`操作过于频繁，请在 ${retryAfter} 秒后重试`);
      } else {
        message.error(errorMsg);
      }
    }
  };

  if (loading) {
    return <Spin size="large" />;
  }

  if (!leaderboard) {
    return <Empty description="榜单不存在" />;
  }

  return (
    <div style={{ maxWidth: 1200, margin: '0 auto', padding: '20px' }}>
      {/* 榜单头部 */}
      <Card style={{ marginBottom: 24 }}>
        <div style={{ display: 'flex', alignItems: 'start', gap: 16 }}>
          {leaderboard.cover_image && (
            <Image
              src={leaderboard.cover_image}
              alt={leaderboard.name}
              width={200}
              height={150}
              style={{ objectFit: 'cover', borderRadius: 8 }}
              preview
            />
          )}
          <div style={{ flex: 1 }}>
            <h1 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: 8 }}>
              <TrophyOutlined style={{ color: '#ffc107' }} />
              {leaderboard.name}
            </h1>
            <Space style={{ marginTop: 8 }}>
              <Tag color="blue">{leaderboard.location}</Tag>
              <Tag>📦 {leaderboard.item_count} 个竞品</Tag>
              <Tag>👍 {leaderboard.vote_count} 票</Tag>
              <Tag>👁️ {leaderboard.view_count} 浏览</Tag>
            </Space>
            {leaderboard.description && (
              <p style={{ marginTop: 16, color: '#666' }}>{leaderboard.description}</p>
            )}
            <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
              <Button
                type="primary"
                icon={<PlusOutlined />}
                onClick={() => {
                  if (!user) {
                    message.warning('请先登录');
                    return;
                  }
                  setShowSubmitModal(true);
                }}
              >
                新增竞品
              </Button>
              <Button
                danger
                icon={<ExclamationCircleOutlined />}
                onClick={() => {
                  if (!user) {
                    message.warning('请先登录');
                    return;
                  }
                  setShowReportModal(true);
                }}
              >
                举报榜单
              </Button>
            </div>
          </div>
        </div>
      </Card>

      {/* 排序选择 */}
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Select
          value={sortBy}
          onChange={(value) => {
            setSortBy(value);
            setPagination(prev => ({ ...prev, current: 1 }));
          }}
          style={{ width: 200 }}
        >
          <Option value="vote_score">综合得分</Option>
          <Option value="net_votes">净赞数</Option>
          <Option value="upvotes">点赞数</Option>
          <Option value="created_at">最新添加</Option>
        </Select>
        <span style={{ color: '#999', fontSize: 14 }}>
          共 {pagination.total} 个竞品
        </span>
      </div>

      {/* 竞品列表 */}
      <Spin spinning={loading}>
        {items.length === 0 && !loading ? (
          <Empty description="暂无竞品" />
        ) : (
          <>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {items.map((item, index) => {
                const globalIndex = (pagination.current - 1) * pagination.pageSize + index + 1;
                return (
                  <Card key={item.id} style={{ borderRadius: 8 }}>
                    <div style={{ display: 'flex', gap: 16 }}>
                      {/* 排名和图片 */}
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                        <div style={{
                          width: 50,
                          height: 50,
                          borderRadius: '50%',
                          background: globalIndex <= 3 ? '#ffc107' : '#f0f0f0',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: 20,
                          fontWeight: 'bold',
                          color: globalIndex <= 3 ? '#fff' : '#666'
                        }}>
                          {globalIndex <= 3 ? '🏆' : `#${globalIndex}`}
                        </div>
                        {item.images && item.images.length > 0 && (
                          <Image
                            src={item.images[0]}
                            alt={item.name}
                            width={80}
                            height={80}
                            style={{ objectFit: 'cover', borderRadius: 8 }}
                            preview={{
                              src: item.images[0],
                              mask: '查看大图'
                            }}
                          />
                        )}
                      </div>
                      
                      {/* 内容 */}
                      <div style={{ flex: 1 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: 8 }}>
                          <div>
                            <h2 
                              style={{ margin: 0, fontSize: 20, fontWeight: 600, cursor: 'pointer' }}
                              onClick={() => {
                                const lang = language || 'zh';
                                navigate(`/${lang}/leaderboard/item/${item.id}?leaderboardId=${leaderboardId}`);
                              }}
                              onMouseEnter={(e) => {
                                e.currentTarget.style.color = '#1890ff';
                              }}
                              onMouseLeave={(e) => {
                                e.currentTarget.style.color = 'inherit';
                              }}
                            >
                              {item.name}
                            </h2>
                            {item.description && (
                              <p style={{ color: '#666', marginTop: 8, marginBottom: 8 }}>{item.description}</p>
                            )}
                            <Space direction="vertical" size="small" style={{ fontSize: 12, color: '#999' }}>
                              {item.address && (
                                <div>
                                  <EnvironmentOutlined /> {item.address}
                                </div>
                              )}
                              {item.phone && (
                                <div>
                                  <PhoneOutlined /> {item.phone}
                                </div>
                              )}
                              {item.website && (
                                <div>
                                  <GlobalOutlined /> <a href={item.website} target="_blank" rel="noopener noreferrer">{item.website}</a>
                                </div>
                              )}
                            </Space>
                          </div>
              
                          {/* 投票按钮 */}
                          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, minWidth: 100 }}>
                            <Button
                              type={item.user_vote === 'upvote' ? 'primary' : 'default'}
                              icon={<LikeOutlined />}
                              onClick={() => handleVote(item.id, 'upvote')}
                              size="large"
                            >
                              {item.upvotes}
                            </Button>
                            <Button
                              danger={item.user_vote === 'downvote'}
                              type={item.user_vote === 'downvote' ? 'primary' : 'default'}
                              icon={<DislikeOutlined />}
                              onClick={() => handleVote(item.id, 'downvote')}
                              size="large"
                            >
                              {item.downvotes}
                            </Button>
                            <div style={{ fontSize: 12, color: '#999', textAlign: 'center' }}>
                              净赞: <span style={{ fontWeight: 600, color: item.net_votes >= 0 ? '#52c41a' : '#ff4d4f' }}>
                                {item.net_votes > 0 ? '+' : ''}{item.net_votes}
                              </span>
                            </div>
                            <div style={{ fontSize: 11, color: '#999' }}>
                              得分: {item.vote_score.toFixed(2)}
                            </div>
                          </div>
                        </div>
                        
                        {/* 显示用户自己的投票留言 */}
                        {item.user_vote_comment && (
                          <div style={{
                            marginTop: 12,
                            padding: 12,
                            background: item.user_vote === 'upvote' ? '#f6ffed' : '#fff1f0',
                            border: `1px solid ${item.user_vote === 'upvote' ? '#b7eb8f' : '#ffccc7'}`,
                            borderRadius: 8,
                            fontSize: 14,
                            color: '#666'
                          }}>
                            <div style={{ fontWeight: 600, marginBottom: 4, display: 'flex', alignItems: 'center', gap: 8 }}>
                              {item.user_vote === 'upvote' ? '👍 你的留言' : '👎 你的留言'}
                              {item.user_vote_is_anonymous && (
                                <Tag color="default" style={{ fontSize: 12 }}>匿名</Tag>
                              )}
                            </div>
                            <div>{item.user_vote_comment}</div>
                          </div>
                        )}
                      </div>
                    </div>
                  </Card>
                );
              })}
            </div>
            
            {/* 分页 */}
            {pagination.total > pagination.pageSize && (
              <div style={{ marginTop: 24, display: 'flex', justifyContent: 'center' }}>
                <Pagination
                  current={pagination.current}
                  pageSize={pagination.pageSize}
                  total={pagination.total}
                  onChange={(page) => {
                    loadData(page);
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                  }}
                  showSizeChanger={false}
                  showQuickJumper
                  showTotal={(total) => `共 ${total} 个竞品`}
                />
              </div>
            )}
          </>
        )}
      </Spin>

      {/* 新增竞品弹窗 */}
      <Modal
        title="新增竞品"
        open={showSubmitModal}
        onCancel={() => {
          setShowSubmitModal(false);
          form.resetFields();
          setUploadingImages([]);
        }}
        onOk={() => form.submit()}
        width={600}
        confirmLoading={uploading}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmitItem}
        >
          <Form.Item
            name="name"
            label="竞品名称"
            rules={[{ required: true, message: '请输入竞品名称' }, { max: 200, message: '名称最多200字' }]}
          >
            <Input placeholder="例如：海底捞" maxLength={200} showCount />
          </Form.Item>
          
          <Form.Item
            name="description"
            label="描述"
            rules={[{ max: 1000, message: '描述最多1000字' }]}
          >
            <Input.TextArea rows={4} placeholder="描述这个竞品的特点" maxLength={1000} showCount />
          </Form.Item>
          
          <Form.Item
            name="address"
            label="地址"
            rules={[{ max: 500, message: '地址最多500字' }]}
          >
            <Input placeholder="详细地址" maxLength={500} showCount />
          </Form.Item>
          
          <Form.Item
            name="phone"
            label="电话（可选）"
            rules={[{ max: 50, message: '电话最多50字' }]}
          >
            <Input placeholder="联系电话（可选）" maxLength={50} />
          </Form.Item>
          
          <Form.Item
            name="website"
            label="网站（可选）"
            rules={[
              { max: 500, message: '网站地址最多500字' },
              {
                type: 'url',
                message: '请输入有效的网址',
                validator: (_, value) => {
                  if (!value || value.trim() === '') {
                    return Promise.resolve(); // 允许为空
                  }
                  // 如果有值，验证URL格式
                  try {
                    new URL(value.startsWith('http') ? value : `https://${value}`);
                    return Promise.resolve();
                  } catch {
                    return Promise.reject(new Error('请输入有效的网址'));
                  }
                }
              }
            ]}
          >
            <Input placeholder="官方网站（可选，如：https://example.com）" maxLength={500} />
          </Form.Item>
          
          <Form.Item
            label="图片"
            extra="最多上传5张图片，每张不超过5MB"
          >
            <Upload
              listType="picture-card"
              fileList={[
                // 已上传完成的图片
                ...uploadingImages.map((url, index) => ({
                  uid: `done-${index}`,
                  name: `image-${index}`,
                  status: 'done' as const,
                  url,
                  thumbUrl: url // 确保有缩略图
                })),
                // 正在上传的图片
                ...uploadingFileList
              ]}
              onChange={handleImageChange}
              onRemove={(file) => {
                // 如果是已完成的图片
                if (file.uid?.startsWith('done-')) {
                  const index = parseInt(file.uid.replace('done-', ''));
                  const url = uploadingImages[index];
                  if (url) {
                    handleRemoveImage(url);
                  }
                } else {
                  // 如果是上传中的图片，从上传列表移除
                  setUploadingFileList(prev => prev.filter(f => f.uid !== file.uid));
                }
                return false;
              }}
              beforeUpload={() => false}
              accept="image/*"
              maxCount={5}
            >
              {(uploadingImages.length + uploadingFileList.length) < 5 && (
                <div>
                  <UploadOutlined />
                  <div style={{ marginTop: 8 }}>上传图片</div>
                </div>
              )}
            </Upload>
          </Form.Item>
        </Form>
      </Modal>

      {/* 举报弹窗 */}
      <Modal
        title="举报榜单"
        open={showReportModal}
        onCancel={() => {
          setShowReportModal(false);
          reportForm.resetFields();
        }}
        onOk={() => reportForm.submit()}
        width={500}
      >
        <Form
          form={reportForm}
          layout="vertical"
          onFinish={async (values) => {
            try {
              await reportLeaderboard(Number(leaderboardId), {
                reason: values.reason,
                description: values.description
              });
              message.success('举报已提交，我们会尽快处理');
              setShowReportModal(false);
              reportForm.resetFields();
            } catch (error: any) {
              console.error('举报失败:', error);
              const errorMsg = error.response?.data?.detail || error.message || '举报失败';
              
              if (error.response?.status === 409) {
                message.warning(errorMsg);
              } else if (error.response?.status === 401) {
                message.error('请先登录');
              } else {
                message.error(errorMsg);
              }
            }
          }}
        >
          <Form.Item
            name="reason"
            label="举报原因"
            rules={[
              { required: true, message: '请输入举报原因' },
              { max: 500, message: '举报原因不能超过500字' }
            ]}
          >
            <Input.TextArea
              rows={3}
              placeholder="请详细说明举报原因，例如：内容不当、虚假信息、恶意刷票等"
              showCount
              maxLength={500}
            />
          </Form.Item>
          <Form.Item
            name="description"
            label="详细描述（可选）"
            rules={[{ max: 2000, message: '详细描述不能超过2000字' }]}
          >
            <Input.TextArea
              rows={4}
              placeholder="可以补充更多详细信息，帮助我们更好地处理您的举报"
              showCount
              maxLength={2000}
            />
          </Form.Item>
        </Form>
      </Modal>

      {/* 投票留言弹窗 */}
      <Modal
        title={currentVoteType === 'upvote' ? '点赞并留言' : '点踩并留言'}
        open={showVoteModal}
        onCancel={() => {
          setShowVoteModal(false);
          voteForm.resetFields();
        }}
        onOk={() => voteForm.submit()}
        width={500}
      >
        <Form
          form={voteForm}
          layout="vertical"
          onFinish={handleVoteSubmit}
        >
          <Form.Item
            name="comment"
            label="留言（可选）"
            rules={[{ max: 500, message: '留言最多500字' }]}
          >
            <Input.TextArea
              rows={4}
              placeholder={currentVoteType === 'upvote'
                ? '分享你的使用体验，例如：物美价廉，服务人员很暖心'
                : '请说明原因，帮助其他用户了解'}
              showCount
              maxLength={500}
            />
          </Form.Item>
          <Form.Item
            name="is_anonymous"
            valuePropName="checked"
          >
            <Checkbox>匿名投票/留言</Checkbox>
          </Form.Item>
        </Form>
      </Modal>

      {/* 移动端响应式样式 */}
      <style>
        {`
          /* 移动端适配 */
          @media (max-width: 768px) {
            /* 外层容器移动端优化 */
            div[style*="maxWidth: 1200"] {
              padding: 12px !important;
            }

            /* 榜单头部卡片移动端优化 */
            .ant-card {
              margin-bottom: 16px !important;
            }

            /* 榜单头部布局移动端优化 */
            div[style*="display: flex"][style*="alignItems: start"][style*="gap: 16"] {
              flex-direction: column !important;
              gap: 12px !important;
            }

            /* 封面图片移动端优化 */
            img[alt="${leaderboard?.name}"] {
              width: 100% !important;
              height: auto !important;
              max-width: 100% !important;
            }

            /* 标题移动端优化 */
            h1[style*="margin: 0"] {
              font-size: 20px !important;
              flex-wrap: wrap !important;
            }

            /* 标签组移动端优化 */
            .ant-space {
              flex-wrap: wrap !important;
              gap: 8px !important;
            }

            /* 按钮组移动端优化 */
            div[style*="display: flex"][style*="gap: 8"] {
              flex-direction: column !important;
              width: 100% !important;
            }

            div[style*="display: flex"][style*="gap: 8"] button {
              width: 100% !important;
              margin-bottom: 8px !important;
            }

            /* 排序选择移动端优化 */
            div[style*="display: flex"][style*="justifyContent: space-between"] {
              flex-direction: column !important;
              gap: 12px !important;
            }

            /* 竞品列表移动端优化 */
            div[style*="display: flex"][style*="flexDirection: column"][style*="gap: 16"] {
              gap: 12px !important;
            }

            /* 竞品卡片移动端优化 */
            .ant-card-body {
              padding: 12px !important;
            }

            /* 竞品信息布局移动端优化 */
            div[style*="display: flex"][style*="gap: 12"] {
              flex-direction: column !important;
              gap: 8px !important;
            }

            /* 投票按钮移动端优化 */
            .ant-space-item button {
              width: 100% !important;
              margin-bottom: 8px !important;
            }

            /* 分页移动端优化 */
            .ant-pagination {
              margin-top: 16px !important;
            }
          }

          /* 超小屏幕优化 */
          @media (max-width: 480px) {
            div[style*="maxWidth: 1200"] {
              padding: 8px !important;
            }

            h1[style*="margin: 0"] {
              font-size: 18px !important;
            }

            .ant-tag {
              font-size: 12px !important;
              padding: 2px 8px !important;
            }

            .ant-card-body {
              padding: 10px !important;
            }
          }

          /* 极小屏幕优化 */
          @media (max-width: 360px) {
            div[style*="maxWidth: 1200"] {
              padding: 6px !important;
            }

            h1[style*="margin: 0"] {
              font-size: 16px !important;
            }
          }
        `}
      </style>
    </div>
  );
};

export default CustomLeaderboardDetail;

