import React, { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Spin, Empty, Typography, Space, Tag, Button, Input, Avatar, Divider, message, Modal, Select } from 'antd';
import { 
  MessageOutlined, EyeOutlined, LikeOutlined, LikeFilled, 
  StarOutlined, StarFilled, UserOutlined, ClockCircleOutlined,
  EditOutlined, DeleteOutlined, FlagOutlined, ArrowLeftOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { 
  getForumPost, getForumReplies, createForumReply, toggleForumLike, 
  toggleForumFavorite, incrementPostViewCount, deleteForumPost, deleteForumReply,
  createForumReport, fetchCurrentUser, getPublicSystemSettings, logout,
  getForumUnreadNotificationCount
} from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import { formatRelativeTime } from '../utils/timeUtils';
import SafeContent from '../components/SafeContent';
import styles from './ForumPostDetail.module.css';

const { Title, Text } = Typography;
const { TextArea } = Input;
const { Option } = Select;

interface ForumReply {
  id: number;
  content: string;
  author: {
    id: string;
    name: string;
    avatar?: string;
    is_admin?: boolean;
  };
  like_count: number;
  is_liked: boolean;
  created_at: string;
  updated_at: string;
  replies?: ForumReply[];
  parent_reply_id?: number;
}

interface ForumPost {
  id: number;
  title: string;
  content: string;
  category: {
    id: number;
    name: string;
  };
  author: {
    id: string;
    name: string;
    avatar?: string;
    is_admin?: boolean;
  };
  view_count: number;
  reply_count: number;
  like_count: number;
  favorite_count: number;
  is_liked: boolean;
  is_favorited: boolean;
  is_pinned: boolean;
  is_featured: boolean;
  is_locked: boolean;
  created_at: string;
  updated_at: string;
}

const ForumPostDetail: React.FC = () => {
  const { lang: langParam, postId } = useParams<{ lang: string; postId: string }>();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  
  // 确保 lang 有值，防止路由错误
  const lang = langParam || language || 'zh';
  const { user: currentUser } = useCurrentUser();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  const [post, setPost] = useState<ForumPost | null>(null);
  const [replies, setReplies] = useState<ForumReply[]>([]);
  const [loading, setLoading] = useState(true);
  const [replyLoading, setReplyLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [replyContent, setReplyContent] = useState('');
  const [parentReplyId, setParentReplyId] = useState<number | undefined>(undefined);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount, setUnreadCount] = useState(0);
  const [showReportModal, setShowReportModal] = useState(false);
  const [reportTargetType, setReportTargetType] = useState<'post' | 'reply'>('post');
  const [reportTargetId, setReportTargetId] = useState<number>(0);
  const [reportReason, setReportReason] = useState<string>('');
  const [reportDescription, setReportDescription] = useState<string>('');

  useEffect(() => {
    if (postId) {
      loadPost();
      loadReplies();
      // 增加浏览数
      incrementPostViewCount(Number(postId)).catch(() => {});
    }
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error: any) {
        setUser(null);
      }
    };
    loadUserData();
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
    
    // 加载未读通知数量
    const loadUnreadCount = async () => {
      try {
        const response = await getForumUnreadNotificationCount();
        setUnreadCount(response.unread_count || 0);
      } catch (error: any) {
        setUnreadCount(0);
      }
    };
    if (currentUser) {
      loadUnreadCount();
    }
  }, [postId, currentPage, currentUser]);

  const loadPost = async () => {
    try {
      setLoading(true);
      const response = await getForumPost(Number(postId));
      setPost(response);
    } catch (error: any) {
      console.error('加载帖子失败:', error);
      message.error(error.response?.data?.detail || t('forum.error'));
    } finally {
      setLoading(false);
    }
  };

  const loadReplies = async () => {
    try {
      const response = await getForumReplies(Number(postId), {
        page: currentPage,
        page_size: 50
      });
      setReplies(response.replies || []);
      setTotal(response.total || 0);
    } catch (error: any) {
      console.error('加载回复失败:', error);
    }
  };

  const handleLike = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    try {
      const response = await toggleForumLike('post', Number(postId));
      // 直接更新本地状态，避免重新加载导致页面滚动
      if (post) {
        setPost({
          ...post,
          is_liked: response.liked,
          like_count: response.like_count
        });
      }
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleFavorite = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    try {
      const response = await toggleForumFavorite(Number(postId));
      // 直接更新本地状态，避免重新加载导致页面滚动
      if (post) {
        setPost({
          ...post,
          is_favorited: response.favorited,
          favorite_count: response.favorite_count
        });
      }
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleReplyLike = async (replyId: number, e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    try {
      const response = await toggleForumLike('reply', replyId);
      // 直接更新本地状态，避免重新加载导致页面滚动
      setReplies(prevReplies => {
        const updateReply = (reply: ForumReply): ForumReply => {
          if (reply.id === replyId) {
            return {
              ...reply,
              is_liked: response.liked,
              like_count: response.like_count
            };
          }
          if (reply.replies && reply.replies.length > 0) {
            return {
              ...reply,
              replies: reply.replies.map(updateReply)
            };
          }
          return reply;
        };
        return prevReplies.map(updateReply);
      });
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleSubmitReply = async () => {
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    if (!replyContent.trim()) {
      message.warning(t('forum.replyPlaceholder'));
      return;
    }
    if (post?.is_locked) {
      message.warning(t('forum.postLocked'));
      return;
    }
    try {
      setReplyLoading(true);
      await createForumReply(Number(postId), {
        content: replyContent,
        parent_reply_id: parentReplyId
      });
      message.success(t('forum.createSuccess'));
      setReplyContent('');
      setParentReplyId(undefined);
      loadReplies();
      loadPost(); // 更新回复数
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    } finally {
      setReplyLoading(false);
    }
  };

  const handleDeletePost = () => {
    Modal.confirm({
      title: t('forum.confirmDelete'),
      content: t('forum.confirmDeleteMessage'),
      onOk: async () => {
        try {
          await deleteForumPost(Number(postId));
          message.success(t('forum.deleteSuccess'));
          navigate(`/${lang}/forum/category/${post?.category.id}`);
        } catch (error: any) {
          message.error(error.response?.data?.detail || t('forum.error'));
        }
      }
    });
  };

  const handleDeleteReply = (replyId: number) => {
    Modal.confirm({
      title: t('forum.confirmDelete'),
      content: t('forum.confirmDeleteMessage'),
      onOk: async () => {
        try {
          await deleteForumReply(replyId);
          message.success(t('forum.deleteSuccess'));
          loadReplies();
          loadPost();
        } catch (error: any) {
          message.error(error.response?.data?.detail || t('forum.error'));
        }
      }
    });
  };

  const handleReport = (targetType: 'post' | 'reply', targetId: number) => {
    setReportTargetType(targetType);
    setReportTargetId(targetId);
    setReportReason('');
    setReportDescription('');
    setShowReportModal(true);
  };

  const handleSubmitReport = async () => {
    if (!reportReason) {
      message.warning(t('forum.reportReason'));
      return;
    }
    try {
      await createForumReport({
        target_type: reportTargetType,
        target_id: reportTargetId,
        reason: reportReason,
        description: reportDescription || undefined
      });
      message.success(t('forum.reportSuccess'));
      setShowReportModal(false);
      setReportReason('');
      setReportDescription('');
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const renderReply = (reply: ForumReply, level: number = 0) => {
    if (level > 2) return null; // 最多3层嵌套
    
    return (
      <div key={reply.id} className={styles.replyItem} style={{ marginLeft: level * 24 }}>
        <div className={styles.replyHeader}>
          <Space>
            <Avatar 
              src={reply.author.avatar} 
              icon={<UserOutlined />}
              size="small"
            />
            <Text strong>{reply.author.name}</Text>
            {reply.author.is_admin && (
              <Tag color="blue" style={{ marginLeft: 8, fontSize: 11 }}>{t('forum.official')}</Tag>
            )}
            <Text type="secondary" style={{ fontSize: 12 }}>
              <ClockCircleOutlined /> {formatRelativeTime(reply.created_at)}
            </Text>
          </Space>
          <Space>
            <Button
              htmlType="button"
              type="text"
              size="small"
              icon={reply.is_liked ? <LikeFilled /> : <LikeOutlined />}
              onClick={(e) => handleReplyLike(reply.id, e)}
              aria-label={reply.is_liked ? t('forum.unlike') || '取消点赞' : t('forum.like') || '点赞'}
              title={reply.is_liked ? t('forum.unlike') || '取消点赞' : t('forum.like') || '点赞'}
            >
              {reply.like_count}
            </Button>
            {currentUser && (
              <Button
                type="text"
                size="small"
                onClick={() => setParentReplyId(reply.id)}
              >
                {t('forum.reply')}
              </Button>
            )}
            {currentUser && currentUser.id === reply.author.id && (
              <Button
                type="text"
                size="small"
                danger
                onClick={() => handleDeleteReply(reply.id)}
              >
                {t('common.delete')}
              </Button>
            )}
            {currentUser && (
              <Button
                type="text"
                size="small"
                icon={<FlagOutlined />}
                onClick={() => handleReport('reply', reply.id)}
              />
            )}
          </Space>
        </div>
        <div className={styles.replyContent}>
          <SafeContent content={reply.content} />
        </div>
        {reply.replies && reply.replies.length > 0 && (
          <div className={styles.nestedReplies}>
            {reply.replies.map((nestedReply) => renderReply(nestedReply, level + 1))}
          </div>
        )}
      </div>
    );
  };

  if (loading) {
    return (
      <div className={styles.container}>
        <header className={styles.header}>
          <div className={styles.headerContainer}>
            <div className={styles.logo} onClick={() => navigate(`/${lang}/forum`)} style={{ cursor: 'pointer' }}>
              Link²Ur
            </div>
            <div className={styles.headerActions}>
              <LanguageSwitcher />
              <NotificationButton 
                user={user}
                unreadCount={unreadCount}
                onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
              />
              <HamburgerMenu 
                user={user}
                onLogout={async () => {
                  try {
                    await logout();
                  } catch (error) {
                  }
                  window.location.reload();
                }}
                onLoginClick={() => setShowLoginModal(true)}
                systemSettings={systemSettings}
                unreadCount={messageUnreadCount}
              />
            </div>
          </div>
        </header>
        <div className={styles.headerSpacer} />
        <div className={styles.loadingContainer}>
          <Spin size="large" />
        </div>
      </div>
    );
  }

  if (!post) {
    return (
      <div className={styles.container}>
        <header className={styles.header}>
          <div className={styles.headerContainer}>
            <div className={styles.logo} onClick={() => navigate(`/${lang}/forum`)} style={{ cursor: 'pointer' }}>
              Link²Ur
            </div>
            <div className={styles.headerActions}>
              <LanguageSwitcher />
              <NotificationButton 
                user={user}
                unreadCount={unreadCount}
                onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
              />
              <HamburgerMenu 
                user={user}
                onLogout={async () => {
                  try {
                    await logout();
                  } catch (error) {
                  }
                  window.location.reload();
                }}
                onLoginClick={() => setShowLoginModal(true)}
                systemSettings={systemSettings}
                unreadCount={messageUnreadCount}
              />
            </div>
          </div>
        </header>
        <div className={styles.headerSpacer} />
        <Empty description={t('forum.error')} />
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <SEOHead 
        title={post.title}
        description={post.content.substring(0, 200)}
      />
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          <div className={styles.logo} onClick={() => navigate(`/${lang}/forum`)} style={{ cursor: 'pointer' }}>
            Link²Ur
          </div>
          <div className={styles.headerActions}>
            <LanguageSwitcher />
            <NotificationButton 
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
            />
            <HamburgerMenu 
              user={user}
              onLogout={async () => {
                try {
                  await logout();
                } catch (error) {
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
              unreadCount={messageUnreadCount}
            />
          </div>
        </div>
      </header>
      <div className={styles.headerSpacer} />

      <div className={styles.content}>
        <Card className={styles.postCard}>
          <div className={styles.postHeader}>
            <div className={styles.postTitleRow}>
              {post.is_pinned && <Tag color="red">{t('forum.pinned')}</Tag>}
              {post.is_featured && <Tag color="gold">{t('forum.featured')}</Tag>}
              {post.is_locked && <Tag color="orange">{t('forum.locked')}</Tag>}
              <Title level={2}>{post.title}</Title>
            </div>
            {currentUser && currentUser.id === post.author.id && (
              <Space>
                <Button
                  type="link"
                  icon={<EditOutlined />}
                  onClick={() => navigate(`/${lang}/forum/post/${postId}/edit`)}
                >
                  {t('forum.editPost')}
                </Button>
                <Button
                  type="link"
                  danger
                  icon={<DeleteOutlined />}
                  onClick={handleDeletePost}
                >
                  {t('forum.deletePost')}
                </Button>
              </Space>
            )}
          </div>

          <div className={styles.postMeta}>
            <Space split="|">
              <Space>
                <Avatar src={post.author.avatar} icon={<UserOutlined />} />
                <Text strong>{post.author.name}</Text>
                {post.author.is_admin && (
                  <Tag color="blue" style={{ marginLeft: 8 }}>{t('forum.official')}</Tag>
                )}
              </Space>
              <Text type="secondary">
                <ClockCircleOutlined /> {formatRelativeTime(post.created_at)}
              </Text>
              <Text type="secondary">
                <EyeOutlined /> {post.view_count}
              </Text>
            </Space>
          </div>

          <Divider />

          <div className={styles.postContent}>
            <SafeContent content={post.content} />
          </div>

          <Divider />

          <div className={styles.postActions}>
            <Space size="large">
              <Button
                htmlType="button"
                type={post.is_liked ? 'primary' : 'default'}
                icon={post.is_liked ? <LikeFilled /> : <LikeOutlined />}
                onClick={handleLike}
                aria-label={post.is_liked ? t('forum.unlike') || '取消点赞' : t('forum.like') || '点赞'}
                title={post.is_liked ? t('forum.unlike') || '取消点赞' : t('forum.like') || '点赞'}
              >
                {post.like_count}
              </Button>
              <Button
                htmlType="button"
                type={post.is_favorited ? 'primary' : 'default'}
                icon={post.is_favorited ? <StarFilled /> : <StarOutlined />}
                onClick={handleFavorite}
                aria-label={post.is_favorited ? t('forum.unfavorite') || '取消收藏' : t('forum.favorite') || '收藏'}
                title={post.is_favorited ? t('forum.unfavorite') || '取消收藏' : t('forum.favorite') || '收藏'}
              >
                {post.favorite_count}
              </Button>
              <Text type="secondary">
                <MessageOutlined /> {post.reply_count} {t('forum.replies')}
              </Text>
              {currentUser && (
                <Button
                  type="text"
                  icon={<FlagOutlined />}
                  onClick={() => handleReport('post', post.id)}
                >
                  {t('forum.report')}
                </Button>
              )}
            </Space>
          </div>
        </Card>

        <Card title={t('forum.replies')} className={styles.repliesCard}>
          {replies.length === 0 ? (
            <Empty description={t('forum.noReplies')} />
          ) : (
            <div className={styles.repliesList}>
              {replies.map((reply) => renderReply(reply))}
            </div>
          )}
        </Card>

        {!post.is_locked && (
          <Card title={parentReplyId ? t('forum.replyTo') : t('forum.writeReply')} className={styles.replyCard}>
            {parentReplyId && (
              <div className={styles.replyToHint}>
                <Text type="secondary">
                  {t('forum.replyingTo')} #{parentReplyId}
                  <Button
                    type="link"
                    size="small"
                    onClick={() => setParentReplyId(undefined)}
                  >
                    {t('common.cancel')}
                  </Button>
                </Text>
              </div>
            )}
            <TextArea
              id="reply-content"
              rows={4}
              placeholder={t('forum.replyPlaceholder')}
              value={replyContent}
              onChange={(e) => setReplyContent(e.target.value)}
              maxLength={10000}
              showCount
              aria-label={t('forum.replyPlaceholder')}
            />
            <div className={styles.replyActions}>
              <Button
                type="primary"
                loading={replyLoading}
                onClick={handleSubmitReply}
              >
                {t('forum.submit')}
              </Button>
            </div>
          </Card>
        )}

        {post.is_locked && (
          <Card>
            <Text type="warning">{t('forum.postLockedMessage')}</Text>
          </Card>
        )}
      </div>

      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
      />

      <Modal
        title={t('forum.report')}
        open={showReportModal}
        onOk={handleSubmitReport}
        onCancel={() => {
          setShowReportModal(false);
          setReportReason('');
          setReportDescription('');
        }}
        okText={t('common.submit')}
        cancelText={t('common.cancel')}
      >
        <div style={{ marginBottom: '16px' }}>
          <label htmlFor="report-reason" style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>
            {t('forum.reportReason')} *
          </label>
          <Select
            id="report-reason"
            value={reportReason}
            onChange={(value) => setReportReason(value)}
            style={{ width: '100%' }}
            placeholder={t('forum.reportReason')}
            aria-label={t('forum.reportReason')}
          >
            <Option value="spam">{t('forum.reasonSpam')}</Option>
            <Option value="fraud">{t('forum.reasonFraud')}</Option>
            <Option value="inappropriate">{t('forum.reasonInappropriate')}</Option>
            <Option value="other">{t('forum.reasonOther')}</Option>
          </Select>
        </div>
        <div>
          <label htmlFor="report-description" style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>
            {t('forum.reportDescription')}
          </label>
          <TextArea
            id="report-description"
            value={reportDescription}
            onChange={(e) => setReportDescription(e.target.value)}
            rows={4}
            aria-label={t('forum.reportDescription')}
            placeholder={t('forum.reportDescriptionPlaceholder')}
            maxLength={500}
            showCount
          />
        </div>
      </Modal>
    </div>
  );
};

export default ForumPostDetail;

