import React, { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { Card, Spin, Empty, Typography, Space, Tag, Button, Input, Pagination } from 'antd';
import { 
  MessageOutlined, EyeOutlined, LikeOutlined, StarOutlined,
  SearchOutlined, UserOutlined, ClockCircleOutlined, FireOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { searchForumPosts, fetchCurrentUser, getPublicSystemSettings, logout } from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import { message } from 'antd';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import { formatRelativeTime } from '../utils/timeUtils';
import { useDebouncedValue } from '../hooks/useDebouncedValue';
import styles from './ForumSearch.module.css';

const { Title, Text } = Typography;
const { Search } = Input;

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
  };
  view_count: number;
  reply_count: number;
  like_count: number;
  is_pinned: boolean;
  is_featured: boolean;
  created_at: string;
  last_reply_at?: string;
}

const ForumSearch: React.FC = () => {
  const { lang } = useParams<{ lang: string }>();
  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  const [posts, setPosts] = useState<ForumPost[]>([]);
  const [loading, setLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [searchKeyword, setSearchKeyword] = useState(searchParams.get('q') || '');
  const [categoryId, setCategoryId] = useState<number | undefined>(
    searchParams.get('category_id') ? Number(searchParams.get('category_id')) : undefined
  );
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount, setUnreadCount] = useState(0);

  const debouncedSearchKeyword = useDebouncedValue(searchKeyword, 500);

  useEffect(() => {
    if (debouncedSearchKeyword.trim()) {
      performSearch();
    } else {
      setPosts([]);
      setTotal(0);
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
  }, [debouncedSearchKeyword, categoryId, currentPage]);

  const performSearch = async () => {
    if (!debouncedSearchKeyword.trim()) {
      return;
    }

    try {
      setLoading(true);
      const params: any = {
        q: debouncedSearchKeyword,
        page: currentPage,
        page_size: pageSize
      };
      if (categoryId) {
        params.category_id = categoryId;
      }
      const response = await searchForumPosts(params);
      setPosts(response.posts || []);
      setTotal(response.total || 0);
      
      // 更新URL参数
      const newParams = new URLSearchParams();
      newParams.set('q', debouncedSearchKeyword);
      if (categoryId) {
        newParams.set('category_id', categoryId.toString());
      }
      setSearchParams(newParams);
    } catch (error: any) {
      console.error('搜索失败:', error);
      message.error(error.response?.data?.detail || t('forum.error'));
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = (value: string) => {
    setSearchKeyword(value);
    setCurrentPage(1);
  };

  const handlePostClick = (postId: number) => {
    navigate(`/${lang}/forum/post/${postId}`);
  };

  return (
    <div className={styles.container}>
      <SEOHead 
        title={t('forum.search')}
        description={t('forum.description')}
      />
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
          onLoginClick={() => {}}
          systemSettings={systemSettings}
          unreadCount={messageUnreadCount}
        />
        <Title level={3} className={styles.pageTitle}>
          {t('forum.search')}
        </Title>
        <div className={styles.headerRight}>
          <LanguageSwitcher />
          <NotificationButton 
            user={user}
            unreadCount={unreadCount}
            onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
          />
        </div>
      </div>

      <div className={styles.content}>
        <Card className={styles.searchCard}>
          <Search
            placeholder={t('forum.search')}
            allowClear
            size="large"
            value={searchKeyword}
            onChange={(e) => setSearchKeyword(e.target.value)}
            onSearch={handleSearch}
            prefix={<SearchOutlined />}
            enterButton
          />
          {searchKeyword && (
            <div className={styles.searchInfo}>
              <Text type="secondary">
                {t('forum.searchResults', { 
                  total, 
                  keyword: searchKeyword 
                })}
              </Text>
            </div>
          )}
        </Card>

        {loading ? (
          <div className={styles.loadingContainer}>
            <Spin size="large" />
          </div>
        ) : searchKeyword.trim() && posts.length === 0 ? (
          <Empty description={t('forum.noSearchResults')} />
        ) : searchKeyword.trim() ? (
          <>
            <div className={styles.postsList}>
              {posts.map((post) => (
                <Card
                  key={post.id}
                  className={styles.postCard}
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
                        <Tag color="gold" icon={<StarOutlined />}>
                          {t('forum.featured')}
                        </Tag>
                      )}
                      <Title 
                        level={5} 
                        className={styles.postTitle}
                        ellipsis={{ rows: 2 }}
                      >
                        {post.title}
                      </Title>
                    </div>
                  </div>

                  <div className={styles.postContent}>
                    <Text ellipsis type="secondary">
                      {post.content}
                    </Text>
                  </div>

                  <div className={styles.postMeta}>
                    <Space split="|">
                      <span>
                        <Tag>{post.category.name}</Tag>
                      </span>
                      <span>
                        <UserOutlined /> {post.author.name}
                      </span>
                      <span>
                        <ClockCircleOutlined /> {formatRelativeTime(post.last_reply_at || post.created_at)}
                      </span>
                    </Space>
                  </div>

                  <div className={styles.postStats}>
                    <Space size="large">
                      <span>
                        <EyeOutlined /> {post.view_count}
                      </span>
                      <span>
                        <MessageOutlined /> {post.reply_count}
                      </span>
                      <span>
                        <LikeOutlined /> {post.like_count}
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
        ) : (
          <Card>
            <Empty 
              description={t('forum.searchPlaceholder')}
              image={Empty.PRESENTED_IMAGE_SIMPLE}
            />
          </Card>
        )}
      </div>
    </div>
  );
};

export default ForumSearch;

