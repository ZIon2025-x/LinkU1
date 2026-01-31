import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { Card, Empty, Typography, Space, Tag, Button, Input, Select, Pagination } from 'antd';
import { 
  MessageOutlined, EyeOutlined, LikeOutlined, StarOutlined, 
  PlusOutlined, SearchOutlined, FireOutlined, ClockCircleOutlined,
  UserOutlined, EditOutlined, DeleteOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { getErrorMessage } from '../utils/errorHandler';
import { useCurrentUser } from '../contexts/AuthContext';
import { getForumPosts, getForumCategory, deleteForumPost, fetchCurrentUser, getPublicSystemSettings, logout } from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import { message, Modal } from 'antd';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import { formatRelativeTime } from '../utils/timeUtils';
import { formatViewCount } from '../utils/formatUtils';
import SkeletonLoader from '../components/SkeletonLoader';
import styles from './ForumPostList.module.css';

const { Title } = Typography;
const { Search } = Input;
const { Option } = Select;

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
  view_count: number;  // 浏览量（前端负责格式化显示）
  reply_count: number;
  like_count: number;
  favorite_count: number;
  is_liked: boolean;
  is_favorited: boolean;
  is_pinned: boolean;
  is_featured: boolean;
  created_at: string;
  last_reply_at?: string;
}

const ForumPostList: React.FC = () => {
  const { lang: langParam, categoryId } = useParams<{ lang: string; categoryId: string }>();
  useSearchParams(); // searchParams/setSearchParams 未使用
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const { user: currentUser } = useCurrentUser();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  // 确保 lang 有值，防止路由错误
  const lang = langParam || language || 'zh';
  
  const [posts, setPosts] = useState<ForumPost[]>([]);
  const [category, setCategory] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [sort, setSort] = useState<'latest' | 'last_reply' | 'hot' | 'replies' | 'likes'>('last_reply');
  const [searchKeyword, setSearchKeyword] = useState('');
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount] = useState(0);

  useEffect(() => {
    if (categoryId) {
      loadCategory();
      loadPosts();
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
  }, [categoryId, currentPage, sort, searchKeyword]);

  const loadCategory = async () => {
    try {
      const response = await getForumCategory(Number(categoryId));
      setCategory(response);
    } catch (error: any) {
      // 如果是404错误，可能是权限问题（学校板块对普通用户不可见）
      if (error.response?.status === 404) {
        // 显示友好提示并跳转回论坛首页
        message.error('板块不存在或无访问权限');
        navigate(`/${lang}/forum`);
      }
      // 静默处理其他错误
    }
  };

  const loadPosts = async () => {
    try {
      setLoading(true);
      const params: any = {
        category_id: Number(categoryId),
        page: currentPage,
        page_size: pageSize,
        sort
      };
      if (searchKeyword) {
        params.q = searchKeyword;
      }
      const response = await getForumPosts(params);
      setPosts(response.posts || []);
      setTotal(response.total || 0);
    } catch (error: any) {
      // 如果是404错误，可能是权限问题（学校板块对普通用户不可见）
      if (error.response?.status === 404) {
        message.error('板块不存在或无访问权限，请确认您已通过学生认证');
        // 延迟跳转，让用户看到错误提示
        setTimeout(() => {
          navigate(`/${lang}/forum`);
        }, 2000);
      } else {
        message.error(t('forum.error'));
      }
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = (value: string) => {
    setSearchKeyword(value);
    setCurrentPage(1);
  };

  const handleSortChange = (value: string) => {
    setSort(value as any);
    setCurrentPage(1);
  };

  const handleCreatePost = () => {
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    navigate(`/${lang}/forum/create?category_id=${categoryId}`);
  };

  const handlePostClick = (postId: number) => {
    navigate(`/${lang}/forum/post/${postId}`);
  };

  const handleDeletePost = async (postId: number, e: React.MouseEvent) => {
    e.stopPropagation();
    Modal.confirm({
      title: t('forum.confirmDelete'),
      content: t('forum.confirmDeleteMessage'),
      onOk: async () => {
        try {
          await deleteForumPost(postId);
          message.success(t('forum.deleteSuccess'));
          loadPosts();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  if (loading && !category) {
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
          <SkeletonLoader type="post" count={3} />
        </div>
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <SEOHead 
        title={category ? `${category.name} - ${t('forum.title')}` : t('forum.title')}
        description={category?.description || t('forum.description')}
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
        <div className={styles.toolbar}>
          <div className={styles.searchAndSort}>
            <Search
              placeholder={t('forum.search')}
              allowClear
              onSearch={handleSearch}
              style={{ width: 200 }}
              prefix={<SearchOutlined />}
            />
            <Select
              value={sort}
              onChange={handleSortChange}
              style={{ width: 150 }}
            >
              <Option value="last_reply">{t('forum.sortLastReply')}</Option>
              <Option value="latest">{t('forum.sortLatest')}</Option>
              <Option value="hot">{t('forum.sortHot')}</Option>
              <Option value="replies">{t('forum.sortReplies')}</Option>
              <Option value="likes">{t('forum.sortLikes')}</Option>
            </Select>
          </div>
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={handleCreatePost}
          >
            {t('forum.createPost')}
          </Button>
        </div>

        {loading ? (
          <div className={styles.loadingContainer}>
            <SkeletonLoader type="post" count={3} />
          </div>
        ) : posts.length === 0 ? (
          <Empty description={t('forum.noPosts')} />
        ) : (
          <>
            <div className={styles.postsList}>
              {posts.map((post) => (
                <Card
                  key={post.id}
                  className={`${styles.postCard} ${post.is_featured ? styles.featuredPostCard : ''}`}
                  hoverable
                  onClick={() => handlePostClick(post.id)}
                >
                  <div className={styles.postHeader}>
                    <div className={styles.postTitleRow}>
                      {post.is_pinned && (
                        <Tag color="red" icon={<FireOutlined />}>
                          {t('forum.pinned')}
                        </Tag>
                      )}
                      {post.is_featured && (
                        <div className={styles.featuredBadge}>
                          <span className={styles.featuredIcon}>✨</span>
                          <span className={styles.featuredText}>{t('forum.featured')}</span>
                        </div>
                      )}
                      <Title 
                        level={5} 
                        className={styles.postTitle}
                        ellipsis={{ rows: 2 }}
                      >
                        {post.title}
                      </Title>
                    </div>
                    {currentUser && currentUser.id === post.author.id && (
                      <div className={styles.postActions}>
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
                          onClick={(e) => handleDeletePost(post.id, e)}
                        />
                      </div>
                    )}
                  </div>

                  <div className={styles.postMeta}>
                    <Space size="small" split="|">
                      <span>
                        <UserOutlined /> {post.author.name}
                        {post.author.is_admin && (
                          <Tag color="blue" style={{ marginLeft: 8, fontSize: 11 }}>{t('forum.official')}</Tag>
                        )}
                      </span>
                      <span>
                        <ClockCircleOutlined /> {formatRelativeTime(post.last_reply_at || post.created_at)}
                      </span>
                    </Space>
                  </div>

                  <div className={styles.postStats}>
                    <Space size="large">
                      <span>
                        <EyeOutlined /> {formatViewCount(post.view_count)}
                      </span>
                      <span>
                        <MessageOutlined /> {post.reply_count}
                      </span>
                      <span>
                        <LikeOutlined /> {post.like_count}
                      </span>
                      <span>
                        <StarOutlined /> {post.favorite_count}
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
                  showSizeChanger={false}
                />
              </div>
            )}
          </>
        )}
      </div>

      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
      />
    </div>
  );
};

export default ForumPostList;

