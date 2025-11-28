import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { Card, Form, Input, Button, Select, message, Spin } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { getForumCategories, createForumPost, updateForumPost, getForumPost, fetchCurrentUser, getPublicSystemSettings, logout, getForumUnreadNotificationCount } from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import { Typography } from 'antd';
import styles from './ForumCreatePost.module.css';

const { Title } = Typography;
const { TextArea } = Input;
const { Option } = Select;

interface ForumCategory {
  id: number;
  name: string;
  description?: string;
}

const ForumCreatePost: React.FC = () => {
  const { lang, postId } = useParams<{ lang: string; postId?: string }>();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const { user: currentUser } = useCurrentUser();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  const [form] = Form.useForm();
  const [categories, setCategories] = useState<ForumCategory[]>([]);
  const [loading, setLoading] = useState(false);
  const [postLoading, setPostLoading] = useState(false);
  const [isEdit, setIsEdit] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    if (!currentUser) {
      setShowLoginModal(true);
    }
    loadCategories();
    if (postId) {
      setIsEdit(true);
      loadPost();
    } else {
      const categoryId = searchParams.get('category_id');
      if (categoryId) {
        form.setFieldsValue({ category_id: Number(categoryId) });
      }
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
  }, [postId, currentUser]);

  const loadCategories = async () => {
    try {
      const response = await getForumCategories();
      setCategories(response.categories || []);
    } catch (error: any) {
      console.error('加载板块失败:', error);
    }
  };

  const loadPost = async () => {
    try {
      setPostLoading(true);
      const response = await getForumPost(Number(postId));
      form.setFieldsValue({
        title: response.title,
        content: response.content,
        category_id: response.category.id
      });
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    } finally {
      setPostLoading(false);
    }
  };

  const handleSubmit = async (values: any) => {
    try {
      setLoading(true);
      if (isEdit && postId) {
        await updateForumPost(Number(postId), values);
        message.success(t('forum.updateSuccess'));
      } else {
        await createForumPost(values);
        message.success(t('forum.createSuccess'));
      }
      navigate(`/${lang}/forum/category/${values.category_id}`);
    } catch (error: any) {
      const errorMsg = error.response?.data?.detail || t('forum.error');
      message.error(errorMsg);
      
      // 处理频率限制错误
      if (error.response?.status === 429) {
        message.warning(t('forum.rateLimitExceeded'));
      }
      
      // 处理重复内容错误
      if (error.response?.headers?.['x-error-code'] === 'DUPLICATE_POST') {
        message.warning(t('forum.duplicatePost'));
      }
    } finally {
      setLoading(false);
    }
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
        title={isEdit ? t('forum.editPost') : t('forum.createPost')}
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
          onLoginClick={() => setShowLoginModal(true)}
          systemSettings={systemSettings}
          unreadCount={messageUnreadCount}
        />
        <Button
          type="link"
          icon={<ArrowLeftOutlined />}
          onClick={() => {
            const categoryId = form.getFieldValue('category_id');
            if (categoryId) {
              navigate(`/${lang}/forum/category/${categoryId}`);
            } else {
              navigate(`/${lang}/forum`);
            }
          }}
          className={styles.backButton}
        >
          {t('common.back')}
        </Button>
        <Title level={3} className={styles.pageTitle}>
          {isEdit ? t('forum.editPost') : t('forum.createPost')}
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
        {postLoading ? (
          <div className={styles.loadingContainer}>
            <Spin size="large" />
          </div>
        ) : (
          <Card className={styles.formCard}>
            <Form
              form={form}
              layout="vertical"
              onFinish={handleSubmit}
              initialValues={{
                category_id: searchParams.get('category_id') ? Number(searchParams.get('category_id')) : undefined
              }}
            >
              <Form.Item
                name="category_id"
                label={t('forum.selectCategory')}
                rules={[{ required: true, message: t('forum.selectCategory') }]}
              >
                <Select
                  placeholder={t('forum.selectCategory')}
                  disabled={isEdit}
                >
                  {categories.map((category) => (
                    <Option key={category.id} value={category.id}>
                      {category.name}
                    </Option>
                  ))}
                </Select>
              </Form.Item>

              <Form.Item
                name="title"
                label={t('forum.postTitle')}
                rules={[
                  { required: true, message: t('forum.postTitle') },
                  { min: 1, max: 200, message: t('forum.titleLength') }
                ]}
              >
                <Input
                  placeholder={t('forum.postTitle')}
                  maxLength={200}
                  showCount
                />
              </Form.Item>

              <Form.Item
                name="content"
                label={t('forum.postContent')}
                rules={[
                  { required: true, message: t('forum.postContent') },
                  { min: 10, max: 50000, message: t('forum.contentLength') }
                ]}
              >
                <TextArea
                  rows={12}
                  placeholder={t('forum.postContent')}
                  maxLength={50000}
                  showCount
                />
              </Form.Item>

              <Form.Item>
                <div className={styles.formActions}>
                  <Button
                    onClick={() => {
                      const categoryId = form.getFieldValue('category_id');
                      if (categoryId) {
                        navigate(`/${lang}/forum/category/${categoryId}`);
                      } else {
                        navigate(`/${lang}/forum`);
                      }
                    }}
                  >
                    {t('common.cancel')}
                  </Button>
                  <Button type="primary" htmlType="submit" loading={loading}>
                    {t('forum.submit')}
                  </Button>
                </div>
              </Form.Item>
            </Form>
          </Card>
        )}
      </div>
    </div>
  );
};

export default ForumCreatePost;

