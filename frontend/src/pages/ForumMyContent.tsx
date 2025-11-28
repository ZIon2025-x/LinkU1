import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Tabs, Spin, Empty, Typography, Space, Tag, Button, Pagination } from 'antd';
import { 
  MessageOutlined, EyeOutlined, LikeOutlined, StarOutlined,
  EditOutlined, DeleteOutlined, UserOutlined, ClockCircleOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { 
  getMyForumPosts, getMyForumReplies, getMyForumLikes, getMyForumFavorites,
  deleteForumPost, deleteForumReply, fetchCurrentUser, getPublicSystemSettings, logout,
  getForumUnreadNotificationCount
} from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import { message, Modal } from 'antd';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import { formatRelativeTime } from '../utils/timeUtils';
import styles from './ForumMyContent.module.css';

const { Title, Text } = Typography;
const { TabPane } = Tabs;

interface ForumPost {
  id: number;
  title: string;
  category: {
    id: number;
    name: string;
  };
  view_count: number;
  reply_count: number;
  like_count: number;
  created_at: string;
  last_reply_at?: string;
}

interface ForumReply {
  id: number;
  content: string;
  post: {
    id: number;
    title: string;
  };
  like_count: number;
  created_at: string;
}

interface ForumLike {
  target_type: 'post' | 'reply';
  post?: {
    id: number;
    title: string;
  };
  reply?: {
    id: number;
    content: string;
    post: {
      id: number;
      title: string;
    };
  };
  created_at: string;
}

interface ForumFavorite {
  id: number;
  post: {
    id: number;
    title: string;
    category: {
      id: number;
      name: string;
    };
    view_count: number;
    reply_count: number;
    like_count: number;
    created_at: string;
    last_reply_at?: string;
  };
  created_at: string;
}

const ForumMyContent: React.FC = () => {
  const { lang: langParam } = useParams<{ lang: string }>();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  
  // 确保 lang 有值，防止路由错误
  const lang = langParam || language || 'zh';
  const { user: currentUser } = useCurrentUser();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  const [activeTab, setActiveTab] = useState('posts');
  const [posts, setPosts] = useState<ForumPost[]>([]);
  const [replies, setReplies] = useState<ForumReply[]>([]);
  const [likes, setLikes] = useState<ForumLike[]>([]);
  const [favorites, setFavorites] = useState<ForumFavorite[]>([]);
  const [loading, setLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [pageSize] = useState(20);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    if (!currentUser) {
      setShowLoginModal(true);
    } else {
      loadContent();
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
  }, [activeTab, currentPage, currentUser]);

  const loadContent = async () => {
    if (!currentUser) return;
    
    try {
      setLoading(true);
      const params = { page: currentPage, page_size: pageSize };
      
      switch (activeTab) {
        case 'posts':
          const postsRes = await getMyForumPosts(params);
          setPosts(postsRes.posts || []);
          setTotal(postsRes.total || 0);
          break;
        case 'replies':
          const repliesRes = await getMyForumReplies(params);
          setReplies(repliesRes.replies || []);
          setTotal(repliesRes.total || 0);
          break;
        case 'likes':
          const likesRes = await getMyForumLikes(params);
          setLikes(likesRes.likes || []);
          setTotal(likesRes.total || 0);
          break;
        case 'favorites':
          const favoritesRes = await getMyForumFavorites(params);
          setFavorites(favoritesRes.favorites || []);
          setTotal(favoritesRes.total || 0);
          break;
      }
    } catch (error: any) {
      console.error('加载内容失败:', error);
      message.error(error.response?.data?.detail || t('forum.error'));
    } finally {
      setLoading(false);
    }
  };

  const handleDeletePost = async (postId: number) => {
    Modal.confirm({
      title: t('forum.confirmDelete'),
      content: t('forum.confirmDeleteMessage'),
      onOk: async () => {
        try {
          await deleteForumPost(postId);
          message.success(t('forum.deleteSuccess'));
          loadContent();
        } catch (error: any) {
          message.error(error.response?.data?.detail || t('forum.error'));
        }
      }
    });
  };

  const handleDeleteReply = async (replyId: number) => {
    Modal.confirm({
      title: t('forum.confirmDelete'),
      content: t('forum.confirmDeleteMessage'),
      onOk: async () => {
        try {
          await deleteForumReply(replyId);
          message.success(t('forum.deleteSuccess'));
          loadContent();
        } catch (error: any) {
          message.error(error.response?.data?.detail || t('forum.error'));
        }
      }
    });
  };

  if (!currentUser) {
    return (
      <div className={styles.container}>
        <div className={styles.header}>
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
          <LanguageSwitcher />
          <NotificationButton 
            user={user}
            unreadCount={unreadCount}
            onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
          />
        </div>
        <LoginModal
          isOpen={showLoginModal}
          onClose={() => {
            setShowLoginModal(false);
            navigate(`/${lang}/forum`);
          }}
        />
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <SEOHead 
        title={t('forum.myContent')}
        description={t('forum.description')}
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
        <Card>
          <Tabs activeKey={activeTab} onChange={setActiveTab}>
            <TabPane tab={t('forum.myPosts')} key="posts">
              {loading ? (
                <div className={styles.loadingContainer}>
                  <Spin size="large" />
                </div>
              ) : posts.length === 0 ? (
                <Empty description={t('forum.noPosts')} />
              ) : (
                <>
                  <div className={styles.list}>
                    {posts.map((post) => (
                      <Card
                        key={post.id}
                        className={styles.itemCard}
                        hoverable
                        onClick={() => navigate(`/${lang}/forum/post/${post.id}`)}
                      >
                        <div className={styles.itemHeader}>
                          <Title
                            level={5}
                            className={styles.itemTitle}
                            ellipsis={{ rows: 2 }}
                          >
                            {post.title}
                          </Title>
                          <Space>
                            <Button
                              type="text"
                              size="small"
                              icon={<EditOutlined />}
                              onClick={(e) => {
                                e.stopPropagation();
                                navigate(`/${lang}/forum/post/${post.id}/edit`);
                              }}
                            />
                            <Button
                              type="text"
                              size="small"
                              danger
                              icon={<DeleteOutlined />}
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeletePost(post.id);
                              }}
                            />
                          </Space>
                        </div>
                        <div className={styles.itemMeta}>
                          <Space split="|">
                            <Tag>{post.category.name}</Tag>
                            <span>
                              <EyeOutlined /> {post.view_count}
                            </span>
                            <span>
                              <MessageOutlined /> {post.reply_count}
                            </span>
                            <span>
                              <LikeOutlined /> {post.like_count}
                            </span>
                            <span>
                              <ClockCircleOutlined /> {formatRelativeTime(post.last_reply_at || post.created_at)}
                            </span>
                          </Space>
                        </div>
                      </Card>
                    ))}
                  </div>
                  {total > pageSize && (
                    <div className={styles.pagination}>
                      <Pagination
                        current={currentPage}
                        total={total}
                        pageSize={pageSize}
                        onChange={(page) => setCurrentPage(page)}
                      />
                    </div>
                  )}
                </>
              )}
            </TabPane>

            <TabPane tab={t('forum.myReplies')} key="replies">
              {loading ? (
                <div className={styles.loadingContainer}>
                  <Spin size="large" />
                </div>
              ) : replies.length === 0 ? (
                <Empty description={t('forum.noReplies')} />
              ) : (
                <>
                  <div className={styles.list}>
                    {replies.map((reply) => (
                      <Card
                        key={reply.id}
                        className={styles.itemCard}
                        hoverable
                        onClick={() => navigate(`/${lang}/forum/post/${reply.post.id}`)}
                      >
                        <div className={styles.itemHeader}>
                          <Title level={5} className={styles.itemTitle}>
                            {reply.post.title}
                          </Title>
                          <Button
                            type="text"
                            size="small"
                            danger
                            icon={<DeleteOutlined />}
                            onClick={(e) => {
                              e.stopPropagation();
                              handleDeleteReply(reply.id);
                            }}
                          />
                        </div>
                        <div className={styles.itemContent}>
                          <Text ellipsis>
                            {reply.content}
                          </Text>
                        </div>
                        <div className={styles.itemMeta}>
                          <Space split="|">
                            <span>
                              <LikeOutlined /> {reply.like_count}
                            </span>
                            <span>
                              <ClockCircleOutlined /> {formatRelativeTime(reply.created_at)}
                            </span>
                          </Space>
                        </div>
                      </Card>
                    ))}
                  </div>
                  {total > pageSize && (
                    <div className={styles.pagination}>
                      <Pagination
                        current={currentPage}
                        total={total}
                        pageSize={pageSize}
                        onChange={(page) => setCurrentPage(page)}
                      />
                    </div>
                  )}
                </>
              )}
            </TabPane>

            <TabPane tab={t('forum.myLikes')} key="likes">
              {loading ? (
                <div className={styles.loadingContainer}>
                  <Spin size="large" />
                </div>
              ) : likes.length === 0 ? (
                <Empty description={t('forum.noLikes')} />
              ) : (
                <>
                  <div className={styles.list}>
                  {likes.map((like, index) => (
                    <Card
                      key={`${like.target_type}-${like.post?.id || like.reply?.id || index}`}
                      className={styles.itemCard}
                      hoverable
                      onClick={() => {
                        if (like.target_type === 'post' && like.post) {
                          navigate(`/${lang}/forum/post/${like.post.id}`);
                        } else if (like.target_type === 'reply' && like.reply) {
                          navigate(`/${lang}/forum/post/${like.reply.post.id}`);
                        }
                      }}
                    >
                      <div className={styles.itemHeader}>
                        <Title level={5} className={styles.itemTitle}>
                          {like.target_type === 'post' && like.post
                            ? like.post.title
                            : like.target_type === 'reply' && like.reply
                            ? like.reply.post.title
                            : `#${like.post?.id || like.reply?.id || ''}`}
                        </Title>
                        <Tag>{like.target_type === 'post' ? t('forum.posts') : t('forum.replies')}</Tag>
                      </div>
                      {like.target_type === 'reply' && like.reply && (
                        <div className={styles.itemContent}>
                          <Text ellipsis>
                            {like.reply.content}
                          </Text>
                        </div>
                      )}
                      <div className={styles.itemMeta}>
                        <span>
                          <ClockCircleOutlined /> {formatRelativeTime(like.created_at)}
                        </span>
                      </div>
                    </Card>
                  ))}
                  </div>
                  {total > pageSize && (
                    <div className={styles.pagination}>
                      <Pagination
                        current={currentPage}
                        total={total}
                        pageSize={pageSize}
                        onChange={(page) => setCurrentPage(page)}
                      />
                    </div>
                  )}
                </>
              )}
            </TabPane>

            <TabPane tab={t('forum.myFavorites')} key="favorites">
              {loading ? (
                <div className={styles.loadingContainer}>
                  <Spin size="large" />
                </div>
              ) : favorites.length === 0 ? (
                <Empty description={t('forum.noFavorites')} />
              ) : (
                <>
                  <div className={styles.list}>
                    {favorites.map((favorite) => (
                      <Card
                        key={favorite.id}
                        className={styles.itemCard}
                        hoverable
                        onClick={() => navigate(`/${lang}/forum/post/${favorite.post.id}`)}
                      >
                        <div className={styles.itemHeader}>
                          <Title
                            level={5}
                            className={styles.itemTitle}
                            ellipsis={{ rows: 2 }}
                          >
                            {favorite.post.title}
                          </Title>
                        </div>
                        <div className={styles.itemMeta}>
                          <Space split="|">
                            <Tag>{favorite.post.category.name}</Tag>
                            <span>
                              <EyeOutlined /> {favorite.post.view_count}
                            </span>
                            <span>
                              <MessageOutlined /> {favorite.post.reply_count}
                            </span>
                            <span>
                              <LikeOutlined /> {favorite.post.like_count}
                            </span>
                            <span>
                              <ClockCircleOutlined /> {formatRelativeTime(favorite.post.last_reply_at || favorite.post.created_at)}
                            </span>
                          </Space>
                        </div>
                      </Card>
                    ))}
                  </div>
                  {total > pageSize && (
                    <div className={styles.pagination}>
                      <Pagination
                        current={currentPage}
                        total={total}
                        pageSize={pageSize}
                        onChange={(page) => setCurrentPage(page)}
                      />
                    </div>
                  )}
                </>
              )}
            </TabPane>
          </Tabs>
        </Card>
      </div>
    </div>
  );
};

export default ForumMyContent;

