import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { 
  Card, Button, Input, Space, Tag, Spin, Empty, Modal, Form, message, 
  Checkbox, Image, Avatar, Divider, Pagination, Typography 
} from 'antd';
import { 
  LikeOutlined, DislikeOutlined, ArrowLeftOutlined, TrophyOutlined,
  PhoneOutlined, GlobalOutlined, EnvironmentOutlined, UserOutlined,
  MessageOutlined, ClockCircleOutlined, ExclamationCircleOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { formatRelativeTime } from '../utils/timeUtils';
import {
  getLeaderboardItemDetail,
  getLeaderboardItemVotes,
  voteLeaderboardItem,
  likeVoteComment,
  reportLeaderboardItem
} from '../api';
import { fetchCurrentUser } from '../api';
import { compressImage } from '../utils/imageCompression';
import api from '../api';
import LoginModal from '../components/LoginModal';

const { Title, Text, Paragraph } = Typography;

const LeaderboardItemDetail: React.FC = () => {
  const { itemId } = useParams<{ itemId: string }>();
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const navigateRouter = useNavigate();
  
  // 从URL参数或item数据中获取leaderboardId
  const [leaderboardId, setLeaderboardId] = useState<string | null>(null);
  const [item, setItem] = useState<any>(null);
  const [votes, setVotes] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [votesLoading, setVotesLoading] = useState(false);
  const [showVoteModal, setShowVoteModal] = useState(false);
  const [currentVoteType, setCurrentVoteType] = useState<'upvote' | 'downvote' | null>(null);
  const [user, setUser] = useState<any>(null);
  const [voteForm] = Form.useForm();
  const [reportForm] = Form.useForm();
  const [showReportModal, setShowReportModal] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [pagination, setPagination] = useState({
    current: 1,
    pageSize: 20,
    total: 0,
    hasMore: false
  });

  useEffect(() => {
    if (itemId) {
      loadData();
      fetchCurrentUser().then(setUser).catch(() => setUser(null));
    }
  }, [itemId]);

  const loadData = async () => {
    try {
      setLoading(true);
      const [itemData, votesData] = await Promise.all([
        getLeaderboardItemDetail(Number(itemId)),
        getLeaderboardItemVotes(Number(itemId), { limit: pagination.pageSize, offset: 0 })
      ]);
      setItem(itemData);
      if (itemData?.leaderboard_id) {
        setLeaderboardId(String(itemData.leaderboard_id));
      }
      
      if (votesData && votesData.items) {
        setVotes(votesData.items || []);
        setPagination(prev => ({
          ...prev,
          current: 1,
          total: votesData.total || 0,
          hasMore: votesData.has_more || false
        }));
      } else {
        // 兼容旧格式
        setVotes(votesData || []);
        setPagination(prev => ({ ...prev, current: 1, total: votesData?.length || 0 }));
      }
    } catch (error: any) {
      console.error('加载失败:', error);
      message.error(error.response?.data?.detail || '加载失败，请稍后重试');
    } finally {
      setLoading(false);
    }
  };

  const loadVotes = async (page: number = 1) => {
    try {
      setVotesLoading(true);
      const offset = (page - 1) * pagination.pageSize;
      const votesData = await getLeaderboardItemVotes(Number(itemId), {
        limit: pagination.pageSize,
        offset
      });
      
      if (votesData && votesData.items) {
        setVotes(votesData.items || []);
        setPagination(prev => ({
          ...prev,
          current: page,
          total: votesData.total || 0,
          hasMore: votesData.has_more || false
        }));
      } else {
        // 兼容旧格式
        setVotes(votesData || []);
      }
    } catch (error: any) {
      console.error('加载留言失败:', error);
      message.error('加载留言失败，请稍后重试');
    } finally {
      setVotesLoading(false);
    }
  };

  const handleVote = async (voteType: 'upvote' | 'downvote') => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }

    if (item && item.user_vote === voteType) {
      try {
        await voteLeaderboardItem(Number(itemId), 'remove');
        message.success('投票已取消');
        loadData();
      } catch (error: any) {
        message.error(error.response?.data?.detail || '取消投票失败');
      }
    } else {
      setCurrentVoteType(voteType);
      setShowVoteModal(true);
      voteForm.resetFields();
    }
  };

  const handleVoteSubmit = async (values: { comment?: string; is_anonymous?: boolean }) => {
    if (!currentVoteType) return;

    try {
      const res = await voteLeaderboardItem(
        Number(itemId),
        currentVoteType,
        values.comment,
        values.is_anonymous || false
      );
      message.success('投票成功');
      setShowVoteModal(false);
      voteForm.resetFields();
      
      // 更新竞品信息
      setItem((prev: any) => prev ? {
        ...prev,
        upvotes: res.upvotes,
        downvotes: res.downvotes,
        net_votes: res.net_votes,
        vote_score: res.vote_score,
        user_vote: currentVoteType,
        user_vote_comment: values.comment || null,
        user_vote_is_anonymous: values.is_anonymous || false,
      } : null);
      
      // 重新加载留言列表
      loadVotes(1);
    } catch (error: any) {
      console.error('投票失败:', error);
      const errorMsg = error.response?.data?.detail || error.message || '投票失败';
      
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

  const formatTime = (time: string) => {
    return formatRelativeTime(time);
  };

  const handleLikeComment = async (voteId: number) => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }

    try {
      const res = await likeVoteComment(voteId);
      message.success(res.message);
      
      // 更新留言列表中的点赞状态
      setVotes(prev => prev.map(vote => 
        vote.id === voteId 
          ? { ...vote, like_count: res.like_count, user_liked: res.liked }
          : vote
      ));
    } catch (error: any) {
      console.error('点赞失败:', error);
      const errorMsg = error.response?.data?.detail || error.message || '点赞失败';
      
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

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '400px' }}>
        <Spin size="large" />
      </div>
    );
  }

  if (!item) {
    return <Empty description="竞品不存在" />;
  }

  const lang = language || 'zh';

  return (
    <div className="item-detail-container" style={{ maxWidth: 1200, margin: '0 auto', padding: '20px' }}>
      {/* 返回按钮 */}
      <Button
        className="back-button"
        icon={<ArrowLeftOutlined />}
        onClick={() => {
          const urlParams = new URLSearchParams(window.location.search);
          const boardId = urlParams.get('leaderboardId') || leaderboardId;
          if (boardId) {
            navigate(`/${lang}/leaderboard/custom/${boardId}`);
          } else {
            navigateRouter(-1);
          }
        }}
        style={{ marginBottom: 16 }}
      >
        返回榜单
      </Button>

      {/* 竞品详情卡片 */}
      <Card className="item-detail-card" style={{ marginBottom: 24 }}>
        <div className="item-detail-content" style={{ display: 'flex', gap: 24 }}>
          {/* 左侧：图片 */}
          {item.images && item.images.length > 0 && (
            <div className="item-images-section" style={{ flexShrink: 0 }}>
              <Image.PreviewGroup>
                <Image
                  className="item-main-image"
                  src={item.images[0]}
                  alt={item.name}
                  width={300}
                  height={300}
                  style={{ objectFit: 'cover', borderRadius: 8 }}
                  preview
                />
                {item.images.length > 1 && (
                  <div className="item-thumbnails" style={{ marginTop: 8, display: 'flex', gap: 8 }}>
                    {item.images.slice(1).map((img: string, idx: number) => (
                      <Image
                        key={idx}
                        src={img}
                        alt={`${item.name} - 图片 ${idx + 2}`}
                        width={80}
                        height={80}
                        style={{ objectFit: 'cover', borderRadius: 4 }}
                        preview
                      />
                    ))}
                  </div>
                )}
              </Image.PreviewGroup>
            </div>
          )}

          {/* 右侧：信息 */}
          <div className="item-info-section" style={{ flex: 1 }}>
            <Title className="item-title" level={2} style={{ marginTop: 0 }}>
              <TrophyOutlined style={{ marginRight: 8, color: '#ffc107' }} />
              {item.name}
            </Title>

            {item.description && (
              <Paragraph style={{ fontSize: 16, color: '#666', marginBottom: 16 }}>
                {item.description}
              </Paragraph>
            )}

            <Space direction="vertical" size="middle" style={{ width: '100%' }}>
              {item.address && (
                <div>
                  <EnvironmentOutlined style={{ marginRight: 8, color: '#1890ff' }} />
                  <Text>{item.address}</Text>
                </div>
              )}
              {item.phone && (
                <div>
                  <PhoneOutlined style={{ marginRight: 8, color: '#1890ff' }} />
                  <Text>{item.phone}</Text>
                </div>
              )}
              {item.website && (
                <div>
                  <GlobalOutlined style={{ marginRight: 8, color: '#1890ff' }} />
                  <a href={item.website} target="_blank" rel="noopener noreferrer" style={{ color: '#1890ff' }}>
                    {item.website}
                  </a>
                </div>
              )}
            </Space>

            <Divider />

            {/* 投票统计和按钮 */}
            <div className="vote-stats-section" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Space className="vote-stats" size="large">
                <div className="vote-stat-item" style={{ textAlign: 'center' }}>
                  <div className="vote-stat-value" style={{ fontSize: 24, fontWeight: 'bold', color: '#52c41a' }}>
                    {item.upvotes}
                  </div>
                  <div className="vote-stat-label" style={{ fontSize: 12, color: '#999' }}>点赞</div>
                </div>
                <div className="vote-stat-item" style={{ textAlign: 'center' }}>
                  <div className="vote-stat-value" style={{ fontSize: 24, fontWeight: 'bold', color: '#ff4d4f' }}>
                    {item.downvotes}
                  </div>
                  <div className="vote-stat-label" style={{ fontSize: 12, color: '#999' }}>点踩</div>
                </div>
                <div className="vote-stat-item" style={{ textAlign: 'center' }}>
                  <div className="vote-stat-value" style={{ fontSize: 24, fontWeight: 'bold', color: item.net_votes >= 0 ? '#52c41a' : '#ff4d4f' }}>
                    {item.net_votes > 0 ? '+' : ''}{item.net_votes}
                  </div>
                  <div className="vote-stat-label" style={{ fontSize: 12, color: '#999' }}>净赞</div>
                </div>
                <div className="vote-stat-item" style={{ textAlign: 'center' }}>
                  <div className="vote-stat-value" style={{ fontSize: 24, fontWeight: 'bold', color: '#666' }}>
                    {item.vote_score.toFixed(2)}
                  </div>
                  <div className="vote-stat-label" style={{ fontSize: 12, color: '#999' }}>综合得分</div>
                </div>
              </Space>

              <Space className="vote-buttons">
                <Button
                  className="vote-button vote-up"
                  type={item.user_vote === 'upvote' ? 'primary' : 'default'}
                  icon={<LikeOutlined />}
                  size="large"
                  onClick={() => handleVote('upvote')}
                >
                  点赞 {item.upvotes}
                </Button>
                <Button
                  className="vote-button vote-down"
                  danger={item.user_vote === 'downvote'}
                  type={item.user_vote === 'downvote' ? 'primary' : 'default'}
                  icon={<DislikeOutlined />}
                  size="large"
                  onClick={() => handleVote('downvote')}
                >
                  点踩 {item.downvotes}
                </Button>
                <Button
                  className="report-button"
                  danger
                  icon={<ExclamationCircleOutlined />}
                  size="large"
                  onClick={() => {
                    if (!user) {
                      setShowLoginModal(true);
                      return;
                    }
                    setShowReportModal(true);
                  }}
                >
                  举报
                </Button>
              </Space>
            </div>

            {/* 用户自己的投票留言 */}
            {item.user_vote_comment && (
              <div className="user-comment-box" style={{
                marginTop: 16,
                padding: 12,
                background: item.user_vote === 'upvote' ? '#f6ffed' : '#fff1f0',
                border: `1px solid ${item.user_vote === 'upvote' ? '#b7eb8f' : '#ffccc7'}`,
                borderRadius: 8
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

      {/* 留言列表 */}
      <Card
        className="comments-card"
        title={
          <Space>
            <MessageOutlined />
            <span>投票留言 {pagination.total > 0 ? `(${pagination.total})` : ''}</span>
          </Space>
        }
      >
        <Spin spinning={votesLoading}>
          {votes.length === 0 && !votesLoading ? (
            <Empty description="暂无留言，快来发表第一条留言吧！" />
          ) : votes.length > 0 ? (
            <>
              <div className="comments-list" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {votes.map((vote, index) => {
                  // 为匿名留言分配序号（按时间顺序）
                  let anonymousCount = 0;
                  for (let i = 0; i <= index; i++) {
                    if (votes[i].is_anonymous) {
                      anonymousCount++;
                    }
                  }
                  const displayName = vote.is_anonymous 
                    ? `匿名用户 #${anonymousCount}` 
                    : (vote.user_id ? `用户 ${vote.user_id}` : '未知用户');
                  
                  return (
                  <Card key={vote.id} className="comment-card" size="small" style={{ borderRadius: 8 }}>
                    <div className="comment-content" style={{ display: 'flex', gap: 12 }}>
                      {/* 用户头像 */}
                      <Avatar
                        className="comment-avatar"
                        icon={<UserOutlined />}
                        style={{
                          backgroundColor: vote.is_anonymous ? '#d9d9d9' : '#1890ff'
                        }}
                      />

                      {/* 留言内容 */}
                      <div className="comment-text" style={{ flex: 1 }}>
                        <div className="comment-header" style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                          <Space>
                            {vote.vote_type === 'upvote' ? (
                              <LikeOutlined style={{ color: '#52c41a' }} />
                            ) : (
                              <DislikeOutlined style={{ color: '#ff4d4f' }} />
                            )}
                            <Text strong>
                              {displayName}
                            </Text>
                            {vote.is_anonymous && (
                              <Tag color="default" style={{ fontSize: 12 }}>匿名</Tag>
                            )}
                          </Space>
                          <Text type="secondary" className="comment-time" style={{ fontSize: 12 }}>
                            <ClockCircleOutlined style={{ marginRight: 4 }} />
                            {formatTime(vote.created_at)}
                          </Text>
                        </div>
                        {vote.comment ? (
                          <Paragraph className="comment-body" style={{ margin: 0, color: '#666', whiteSpace: 'pre-wrap' }}>
                            {vote.comment}
                          </Paragraph>
                        ) : (
                          <Text type="secondary" style={{ fontSize: 12, fontStyle: 'italic' }}>
                            （仅投票，无留言）
                          </Text>
                        )}
                        {/* 点赞按钮 */}
                        <div className="comment-actions" style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
                          <Button
                            className="comment-like-button"
                            type={vote.user_liked ? 'primary' : 'default'}
                            size="small"
                            icon={<LikeOutlined />}
                            onClick={() => handleLikeComment(vote.id)}
                            style={{ 
                              fontSize: 12,
                              height: 28,
                              padding: '0 12px'
                            }}
                          >
                            {vote.like_count || 0}
                          </Button>
                        </div>
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
                      loadVotes(page);
                      window.scrollTo({ top: 0, behavior: 'smooth' });
                    }}
                    showSizeChanger={false}
                    showQuickJumper
                    showTotal={(total) => `共 ${total} 条留言`}
                  />
                </div>
              )}
            </>
          ) : null}
        </Spin>
      </Card>

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

      {/* 举报弹窗 */}
      <Modal
        title="举报竞品"
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
              await reportLeaderboardItem(Number(itemId), {
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
              placeholder="请详细说明举报原因，例如：虚假信息、恶意刷票、内容不当等"
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

      {/* 移动端响应式样式 */}
      <style>
        {`
          /* 移动端适配 */
          @media (max-width: 768px) {
            /* 外层容器移动端优化 */
            .item-detail-container {
              padding: 12px !important;
            }

            /* 返回按钮移动端优化 */
            .back-button {
              margin-bottom: 12px !important;
              width: 100% !important;
            }

            /* 竞品详情卡片移动端优化 */
            .item-detail-card .ant-card-body {
              padding: 16px !important;
            }

            /* 竞品信息布局移动端优化 */
            .item-detail-content {
              flex-direction: column !important;
              gap: 16px !important;
            }

            /* 图片区域移动端优化 */
            .item-images-section {
              width: 100% !important;
            }

            .item-main-image {
              width: 100% !important;
              max-width: 100% !important;
              height: auto !important;
            }

            .item-thumbnails {
              flex-wrap: wrap !important;
              gap: 8px !important;
            }

            .item-thumbnails .ant-image {
              width: 80px !important;
              height: 80px !important;
            }

            /* 信息区域移动端优化 */
            .item-info-section {
              width: 100% !important;
            }

            /* 标题移动端优化 */
            .item-title {
              font-size: 20px !important;
              line-height: 1.4 !important;
            }

            /* 描述移动端优化 */
            .ant-typography {
              font-size: 14px !important;
              line-height: 1.6 !important;
            }

            /* 投票统计和按钮区域移动端优化 */
            .vote-stats-section {
              flex-direction: column !important;
              gap: 16px !important;
              align-items: stretch !important;
            }

            /* 投票统计移动端优化 */
            .vote-stats {
              width: 100% !important;
              justify-content: space-around !important;
              flex-wrap: wrap !important;
            }

            .vote-stat-item {
              flex: 1 1 calc(50% - 8px) !important;
              min-width: calc(50% - 8px) !important;
              margin-bottom: 12px !important;
            }

            .vote-stat-value {
              font-size: 20px !important;
            }

            .vote-stat-label {
              font-size: 11px !important;
            }

            /* 投票按钮移动端优化 */
            .vote-buttons {
              width: 100% !important;
              flex-wrap: wrap !important;
              gap: 8px !important;
            }

            .vote-button,
            .report-button {
              flex: 1 1 calc(50% - 4px) !important;
              min-width: calc(50% - 4px) !important;
              font-size: 13px !important;
            }

            /* 用户留言框移动端优化 */
            .user-comment-box {
              font-size: 13px !important;
              padding: 10px !important;
            }

            /* 留言列表移动端优化 */
            .comments-list {
              gap: 12px !important;
            }

            /* 留言卡片移动端优化 */
            .comment-card .ant-card-body {
              padding: 12px !important;
            }

            .comment-content {
              gap: 8px !important;
            }

            .comment-avatar {
              flex-shrink: 0 !important;
            }

            .comment-header {
              flex-direction: column !important;
              align-items: flex-start !important;
              gap: 4px !important;
            }

            .comment-time {
              font-size: 11px !important;
            }

            .comment-body {
              font-size: 13px !important;
              line-height: 1.5 !important;
            }

            .comment-actions {
              margin-top: 8px !important;
            }

            .comment-like-button {
              font-size: 12px !important;
            }

            /* 分页移动端优化 */
            .ant-pagination {
              margin-top: 16px !important;
            }
          }

          /* 超小屏幕优化 */
          @media (max-width: 480px) {
            .item-detail-container {
              padding: 8px !important;
            }

            .item-detail-card .ant-card-body {
              padding: 12px !important;
            }

            .item-title {
              font-size: 18px !important;
            }

            .vote-stat-value {
              font-size: 18px !important;
            }

            .vote-stat-label {
              font-size: 10px !important;
            }

            .vote-button,
            .report-button {
              font-size: 12px !important;
              padding: 8px 12px !important;
            }

            .item-thumbnails .ant-image {
              width: 70px !important;
              height: 70px !important;
            }

            .user-comment-box {
              font-size: 12px !important;
              padding: 8px !important;
            }

            .comment-card .ant-card-body {
              padding: 10px !important;
            }

            .comment-body {
              font-size: 12px !important;
            }
          }

          /* 极小屏幕优化 */
          @media (max-width: 360px) {
            .item-detail-container {
              padding: 6px !important;
            }

            .item-title {
              font-size: 16px !important;
            }

            .vote-stat-value {
              font-size: 16px !important;
            }

            .vote-button,
            .report-button {
              font-size: 11px !important;
              padding: 6px 10px !important;
            }

            .item-thumbnails .ant-image {
              width: 60px !important;
              height: 60px !important;
            }
          }
        `}
      </style>
    </div>
  );
};

export default LeaderboardItemDetail;

