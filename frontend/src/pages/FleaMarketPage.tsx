import React, { useState, useEffect, useCallback, useMemo, useRef, memo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { message, Modal, Input, InputNumber, Button, Upload, Space, Card, Empty, Spin, UploadFile, Select, Checkbox, Tabs } from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined, SearchOutlined, UploadOutlined, HeartFilled } from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { CITIES } from './Tasks';
import zhTranslations from '../locales/zh.json';
import enTranslations from '../locales/en.json';
import api, { fetchCurrentUser, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout } from '../api';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import { useThrottledCallback } from '../hooks/useThrottledCallback';
import FleaMarketItemDetailModal from '../components/FleaMarketItemDetailModal';
import { compressImage } from '../utils/imageCompression';
import styles from './FleaMarketPage.module.css';
import headerStyles from './Home.module.css';

// 商品分类列表
export const CATEGORIES = [
  'Electronics',           // 电子产品
  'Clothing',             // 服装鞋帽
  'Books',                // 书籍
  'Furniture',            // 家具
  'Sports',               // 运动用品
  'Accessories',          // 配饰
  'Home & Living',        // 生活用品
  'Beauty & Personal',    // 美妆个护
  'Toys & Games',         // 玩具游戏
  'Other'                 // 其他
];

const { TextArea } = Input;
const { Search } = Input;

interface FleaMarketItem {
  id: number;
  title: string;
  description: string;
  price: number;
  currency: 'GBP';
  images: string[];
  location?: string;
  category?: string;
  contact?: string;
  status: 'active' | 'sold' | 'deleted';
  seller_id: string;
  created_at: string;
  updated_at: string;
}

const FleaMarketPage: React.FC = () => {
  const { lang } = useParams<{ lang: string }>();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const { user: currentUser } = useCurrentUser();
  
  // 移动端检测
  const [isMobile, setIsMobile] = useState(false);
  
  // 用户和通知相关状态
  const [user, setUser] = useState<any>(null);
  const [notifications, setNotifications] = useState<any[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  const [items, setItems] = useState<FleaMarketItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [searchKeyword, setSearchKeyword] = useState('');
  const [debouncedSearchKeyword, setDebouncedSearchKeyword] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | undefined>(undefined);
  const [selectedLocation, setSelectedLocation] = useState<string | undefined>(undefined);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize] = useState(20);
  const [hasMore, setHasMore] = useState(true);
  const [showNoticeModal, setShowNoticeModal] = useState(false);
  const [noticeAgreed, setNoticeAgreed] = useState(false);
  const [showMyItemsModal, setShowMyItemsModal] = useState(false);
  const [myPostedItems, setMyPostedItems] = useState<FleaMarketItem[]>([]);
  const [myPurchasedItems, setMyPurchasedItems] = useState<FleaMarketItem[]>([]);
  const [myFavoriteItems, setMyFavoriteItems] = useState<FleaMarketItem[]>([]);
  const [loadingMyItems, setLoadingMyItems] = useState(false);
  const [showItemDetailModal, setShowItemDetailModal] = useState(false);
  const [selectedItemId, setSelectedItemId] = useState<string | null>(null);
  const [favoriteItemIds, setFavoriteItemIds] = useState<Set<string>>(new Set());
  
  // 防抖搜索关键词
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearchKeyword(searchKeyword);
    }, 300);
    return () => clearTimeout(timer);
  }, [searchKeyword]);
  
  // 上传表单相关
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    price: 0,
    images: [] as string[],
    location: 'Online',
    category: '',
    contact: ''
  });
  const [imageFiles, setImageFiles] = useState<File[]>([]);
  
  // 编辑相关
  const [editingItem, setEditingItem] = useState<FleaMarketItem | null>(null);

  // 加载用户数据 - 使用useCurrentUser hook，同时保持本地状态用于通知等功能
  useEffect(() => {
    if (currentUser) {
      setUser(currentUser);
    } else {
      setUser(null);
    }
  }, [currentUser]);

  // 移动端检测
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // 加载系统设置
  useEffect(() => {
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
  }, []);

  // 检查是否需要显示须知弹窗
  useEffect(() => {
    const hasSeenNotice = localStorage.getItem('fleaMarket_notice_seen');
    // 只有当 localStorage 中没有记录时才显示弹窗
    if (hasSeenNotice !== 'true') {
      setShowNoticeModal(true);
      setNoticeAgreed(false); // 重置同意状态
    } else {
      setShowNoticeModal(false);
    }
  }, []);

  // 获取通知数据
  useEffect(() => {
    if (user) {
      getNotificationsWithRecentRead(10).then(notifications => {
        setNotifications(notifications);
      }).catch(error => {
        console.error('Failed to get notifications:', error);
      });
      
      getUnreadNotificationCount().then(count => {
        setUnreadCount(count);
      }).catch(error => {
        console.error('Failed to get unread count:', error);
      });
    }
  }, [user]);

  // 定期更新未读通知数量
  useEffect(() => {
    if (user) {
      const interval = setInterval(() => {
        if (!document.hidden) {
          getUnreadNotificationCount().then(count => {
            setUnreadCount(count);
          }).catch(error => {
            console.error('定期更新未读数量失败:', error);
          });
        }
      }, 30000);
      return () => clearInterval(interval);
    }
  }, [user]);

  // 处理通知点击 - 使用useCallback优化
  const handleMarkAsRead = useCallback(async (id: number) => {
    try {
      await markNotificationRead(id);
      setNotifications(prev => 
        prev.map(n => n.id === id ? { ...n, is_read: 1 } : n)
      );
      setUnreadCount(prev => Math.max(0, prev - 1));
    } catch (error) {
      console.error('标记通知为已读失败:', error);
      message.error('标记通知为已读失败，请重试');
    }
  }, []);

  // 标记所有通知为已读 - 使用useCallback优化
  const handleMarkAllRead = useCallback(async () => {
    try {
      await markAllNotificationsRead();
      setUnreadCount(0);
      setNotifications(prev => prev.map(n => ({ ...n, is_read: 1 })));
    } catch (error) {
      console.error('标记所有通知为已读失败:', error);
      message.error('标记所有通知为已读失败，请重试');
    }
  }, []);

  // 加载商品列表 - 使用useCallback优化，支持加载更多模式
  const loadItems = useCallback(async (isLoadMore = false, targetPage?: number, keyword?: string, category?: string, location?: string) => {
    if (isLoadMore) {
      setLoadingMore(true);
    } else {
      setLoading(true);
      setCurrentPage(1);
      setHasMore(true);
    }
    
    try {
      // 如果是加载更多，使用传入的页码或当前页码+1
      const page = isLoadMore ? (targetPage ?? currentPage + 1) : 1;
      
      const params: any = {
        page,
        pageSize,
        status: 'active'
      };
      
      if (keyword) {
        params.keyword = keyword;
      }
      
      if (category) {
        params.category = category;
      }
      
      if (location) {
        params.location = location;
      }
      
      const response = await api.get('/api/flea-market/items', { params });
      const data = response.data;
      
      // 处理 images 字段（可能是 JSON 字符串）和 price 字段（确保是数字）
      const processedItems = (data.items || []).map((item: any) => ({
        ...item,
        images: typeof item.images === 'string' ? JSON.parse(item.images || '[]') : (item.images || []),
        price: typeof item.price === 'number' ? item.price : parseFloat(String(item.price || 0))
      }));
      
      if (isLoadMore) {
        // 追加商品
        setItems(prev => [...prev, ...processedItems]);
        setCurrentPage(page);
      } else {
        // 替换商品列表
        setItems(processedItems);
        setCurrentPage(1);
      }
      
      // 判断是否还有更多商品
      const totalPages = Math.ceil((data.total || 0) / pageSize);
      setHasMore(page < totalPages && processedItems.length > 0);
      
      // 如果用户已登录，加载收藏列表
      if (currentUser && !isLoadMore) {
        try {
          const favoritesResponse = await api.get('/api/flea-market/favorites', {
            params: { page: 1, pageSize: 100 }
          });
          const favorites = favoritesResponse.data.items || [];
          const favoriteIds = new Set<string>(favorites.map((fav: any) => String(fav.item_id)));
          setFavoriteItemIds(favoriteIds);
        } catch (e) {
          // 忽略错误，不影响主流程
          console.log('加载收藏列表失败:', e);
        }
      }
    } catch (error: any) {
      if (!isLoadMore) {
        setItems([]);
      }
      setHasMore(false);
      console.error('加载商品列表失败:', error);
      message.error(error.response?.data?.detail || t('fleaMarket.loadError'));
    } finally {
      if (isLoadMore) {
        setLoadingMore(false);
      } else {
        setLoading(false);
      }
    }
  }, [currentPage, pageSize, t, currentUser]);

  // 加载我的闲置商品
  const loadMyItems = useCallback(async () => {
    if (!user) return;
    
    setLoadingMyItems(true);
    try {
      // 获取我发布的商品
      const postedResponse = await api.get('/api/flea-market/items', {
        params: {
          seller_id: user.id,
          page: 1,
          pageSize: 100,
          status: 'active'
        }
      });
      const postedData = postedResponse.data;
      // 双重验证：确保只显示当前用户的商品
      const processedPostedItems = (postedData.items || [])
        .filter((item: any) => item.seller_id === user.id)  // 客户端再次过滤
        .map((item: any) => ({
          ...item,
          images: typeof item.images === 'string' ? JSON.parse(item.images || '[]') : (item.images || []),
          price: typeof item.price === 'number' ? item.price : parseFloat(String(item.price || 0))
        }));
      setMyPostedItems(processedPostedItems);

      // 获取我购买的商品（如果有相关API）
      // 暂时先设为空数组，等后端API实现后再添加
      try {
        const purchasedResponse = await api.get('/api/flea-market/my-purchases', {
          params: {
            page: 1,
            pageSize: 100
          }
        });
        const purchasedData = purchasedResponse.data;
        const processedPurchasedItems = (purchasedData.items || []).map((item: any) => ({
          ...item,
          images: typeof item.images === 'string' ? JSON.parse(item.images || '[]') : (item.images || []),
          price: typeof item.price === 'number' ? item.price : parseFloat(String(item.price || 0))
        }));
        setMyPurchasedItems(processedPurchasedItems);
      } catch (error: any) {
        // 如果API不存在，设置为空数组
        console.log('Purchased items API not available:', error);
        setMyPurchasedItems([]);
      }

      // 获取我的收藏列表
      try {
        const favoritesResponse = await api.get('/api/flea-market/favorites', {
          params: {
            page: 1,
            pageSize: 100
          }
        });
        const favoritesData = favoritesResponse.data;
        const favoriteItemIds = (favoritesData.items || []).map((fav: any) => fav.item_id);
        
        // 根据收藏的item_id获取完整的商品信息
        if (favoriteItemIds.length > 0) {
          const favoriteItemsPromises = favoriteItemIds.map(async (itemId: string) => {
            try {
              const itemResponse = await api.get(`/api/flea-market/items/${itemId}`);
              const itemData = itemResponse.data;
              return {
                ...itemData,
                images: typeof itemData.images === 'string' ? JSON.parse(itemData.images || '[]') : (itemData.images || []),
                price: typeof itemData.price === 'number' ? itemData.price : parseFloat(String(itemData.price || 0)),
                id: typeof itemData.id === 'string' ? parseInt(itemData.id, 10) : itemData.id
              };
            } catch (e) {
              console.error(`加载收藏商品 ${itemId} 失败:`, e);
              return null;
            }
          });
          
          const favoriteItems = await Promise.all(favoriteItemsPromises);
          // 只显示活跃状态的商品，已删除或已售出的商品会被过滤掉
          setMyFavoriteItems(favoriteItems.filter((item): item is FleaMarketItem => 
            item !== null && item.status === 'active'
          ));
        } else {
          setMyFavoriteItems([]);
        }
      } catch (error: any) {
        // 如果API不存在或失败，设置为空数组
        console.log('Favorites API not available:', error);
        setMyFavoriteItems([]);
      }
    } catch (error: any) {
      console.error('加载我的闲置商品失败:', error);
      message.error(error.response?.data?.detail || '加载失败，请重试');
    } finally {
      setLoadingMyItems(false);
    }
  }, [user]);

  // 使用ref存储loadItems函数，避免循环依赖
  const loadItemsRef = useRef(loadItems);
  useEffect(() => {
    loadItemsRef.current = loadItems;
  }, [loadItems]);

  // 使用防抖后的关键词触发搜索
  useEffect(() => {
    loadItemsRef.current(false, undefined, debouncedSearchKeyword || undefined, selectedCategory, selectedLocation);
  }, [debouncedSearchKeyword, selectedCategory, selectedLocation]);

  // 加载更多商品
  const loadMoreItems = useCallback(() => {
    if (!loadingMore && !loading && hasMore) {
      loadItemsRef.current(true, undefined, debouncedSearchKeyword || undefined, selectedCategory, selectedLocation);
    }
  }, [loadingMore, loading, hasMore, debouncedSearchKeyword, selectedCategory, selectedLocation]);

  // 滚动监听 - 动态预判加载（距离底部200px时开始加载）
  const handleScroll = useThrottledCallback(() => {
    if (loadingMore || loading || !hasMore) return;
    
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    const windowHeight = window.innerHeight;
    const documentHeight = document.documentElement.scrollHeight;
    
    // 当滚动到距离底部200px时，开始加载更多
    if (scrollTop + windowHeight >= documentHeight - 200) {
      loadMoreItems();
    }
  }, 100);

  // 添加滚动事件监听器
  useEffect(() => {
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [handleScroll]);

  // 上传图片 - 使用useCallback优化
  const uploadImages = useCallback(async (files: File[], itemId?: number): Promise<string[]> => {
    const uploadedUrls: string[] = [];
    
    for (const file of files) {
      try {
        // 压缩图片
        const compressedFile = await compressImage(file, {
          maxSizeMB: 1,
          maxWidthOrHeight: 1920,
        });
        
        const formData = new FormData();
        formData.append('image', compressedFile);
        
        // 使用跳蚤市场的专用上传接口
        // 新建商品时不传item_id，图片会存储在临时目录，创建商品后自动移动到正式目录
        // 编辑商品时传item_id，图片直接存储在商品目录
        const uploadUrl = itemId 
          ? `/api/flea-market/upload-image?item_id=${itemId}`
          : '/api/flea-market/upload-image';
        
        const response = await api.post(uploadUrl, formData, {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        });
        
        if (response.data.success && response.data.url) {
          uploadedUrls.push(response.data.url);
        } else {
          throw new Error('上传失败');
        }
      } catch (error) {
        console.error('图片上传失败:', error);
        throw error;
      }
    }
    
    return uploadedUrls;
  }, []);

  // 提交商品 - 使用useCallback优化
  const handleSubmit = useCallback(async () => {
    if (!formData.title.trim()) {
      message.error(t('fleaMarket.titleRequired'));
      return;
    }
    if (!formData.description.trim()) {
      message.error(t('fleaMarket.descriptionRequired'));
      return;
    }
    if (formData.price <= 0) {
      message.error(t('fleaMarket.priceRequired'));
      return;
    }
    
    setUploading(true);
    try {
      // 先上传图片
      let imageUrls: string[] = [];
      if (imageFiles.length > 0) {
        // 编辑商品时传递item_id，新建商品时不传
        const itemId = editingItem?.id;
        imageUrls = await uploadImages(imageFiles, itemId);
      }
      
      const submitData = {
        ...formData,
        images: imageUrls,
        currency: 'GBP' as const
      };
      
      if (editingItem) {
        // 编辑商品
        await api.put(`/api/flea-market/items/${editingItem.id}`, submitData);
        message.success(t('fleaMarket.updateSuccess'));
      } else {
        // 创建商品
        await api.post('/api/flea-market/items', submitData);
        message.success(t('fleaMarket.createSuccess'));
      }
      
      // 重置表单
      setFormData({
        title: '',
        description: '',
        price: 0,
        images: [],
        location: 'Online',
        category: '',
        contact: ''
      });
      setImageFiles([]);
      setShowUploadModal(false);
      setEditingItem(null);
      
      // 重新加载列表 - 添加小延迟确保数据已保存
      setTimeout(() => {
        loadItemsRef.current(false, undefined, debouncedSearchKeyword || undefined, selectedCategory, selectedLocation);
      }, 500);
    } catch (error: any) {
      console.error('提交商品失败:', error);
      message.error(error.response?.data?.detail || t('fleaMarket.submitError'));
    } finally {
      setUploading(false);
    }
  }, [formData, imageFiles, editingItem, debouncedSearchKeyword, selectedCategory, selectedLocation, uploadImages, t, loadItemsRef]);

  // 删除商品 - 使用useCallback优化
  const handleDelete = useCallback(async (item: FleaMarketItem) => {
    Modal.confirm({
      title: t('fleaMarket.confirmDelete'),
      content: t('fleaMarket.confirmDeleteMessage'),
      onOk: async () => {
        try {
          await api.put(`/api/flea-market/items/${item.id}`, { status: 'deleted' });
          message.success(t('fleaMarket.deleteSuccess'));
          // 添加小延迟确保数据已更新
          setTimeout(() => {
            loadItemsRef.current(false, undefined, debouncedSearchKeyword || undefined, selectedCategory, selectedLocation);
          }, 300);
        } catch (error: any) {
          console.error('删除商品失败:', error);
          message.error(error.response?.data?.detail || t('fleaMarket.deleteError'));
        }
      }
    });
  }, [currentPage, debouncedSearchKeyword, selectedCategory, t, loadItemsRef]);

  // 编辑商品 - 使用useCallback优化
  const handleEdit = useCallback((item: FleaMarketItem) => {
    setEditingItem(item);
    setFormData({
      title: item.title,
      description: item.description,
      price: typeof item.price === 'number' ? item.price : parseFloat(String(item.price || 0)),
      images: item.images,
      location: item.location || 'Online',
      category: item.category || '',
      contact: item.contact || ''
    });
    setImageFiles([]);
    setShowUploadModal(true);
  }, []);

  // 图片上传处理 - 使用useCallback优化
  const handleImageChange = useCallback((info: any) => {
    const fileList = info.fileList.slice(-5); // 最多5张
    const files = fileList.map((file: any) => file.originFileObj).filter(Boolean);
    setImageFiles(files);
  }, []);

  // 判断是否是商品所有者 - 使用useCallback优化
  const isOwner = useCallback((item: FleaMarketItem) => {
    return user && user.id === item.seller_id;
  }, [user]);

  // 使用useMemo优化筛选后的商品列表
  const filteredItems = useMemo(() => {
    let filtered = [...items];
    
    // 按分类筛选（如果服务端没有处理，这里做客户端筛选）
    if (selectedCategory) {
      filtered = filtered.filter(item => item.category === selectedCategory);
    }
    
    // 按城市筛选（如果服务端没有处理，这里做客户端筛选）
    if (selectedLocation) {
      filtered = filtered.filter(item => item.location === selectedLocation);
    }
    
    return filtered;
  }, [items, selectedCategory, selectedLocation]);

  // 处理卡片点击 - 打开详情弹窗
  const handleCardClick = useCallback((itemId: number) => {
    setSelectedItemId(String(itemId));
    setShowItemDetailModal(true);
  }, []);

  // 商品卡片组件 - 使用React.memo优化，避免不必要的重新渲染
  const FleaMarketItemCard = memo<{
    item: FleaMarketItem;
    isOwner: boolean;
    isFavorited?: boolean;
    onEdit: (item: FleaMarketItem) => void;
    onDelete: (item: FleaMarketItem) => void;
    onCardClick: (itemId: number) => void;
  }>(({ item, isOwner, isFavorited = false, onEdit, onDelete, onCardClick }) => {
    const handleEditClick = useCallback((e: React.MouseEvent) => {
      e.stopPropagation();
      onEdit(item);
    }, [item, onEdit]);

    const handleDeleteClick = useCallback((e: React.MouseEvent) => {
      e.stopPropagation();
      onDelete(item);
    }, [item, onDelete]);

    const handleCardClickInternal = useCallback(() => {
      onCardClick(item.id);
    }, [item.id, onCardClick]);

    return (
      <div
        key={item.id}
        className={styles.itemCard}
        onClick={handleCardClickInternal}
      >
        {/* 商品图片 - 占满整个卡片 */}
        <div className={styles.itemImageWrapper}>
          {item.images && item.images.length > 0 ? (
            <img
              alt={item.title}
              src={item.images[0]}
              className={styles.itemImage}
            />
          ) : (
            <div className={styles.itemImagePlaceholder}>
              <span className={styles.placeholderIcon}>🛍️</span>
            </div>
          )}
          
          {/* 渐变遮罩层 - 用于文字可读性 */}
          <div className={styles.imageOverlay}></div>
          
          {/* 收藏标识 - 左上角 */}
          {isFavorited && (
            <div className={styles.favoriteBadge}>
              <HeartFilled style={{ color: '#ff4d4f', fontSize: '24px' }} />
            </div>
          )}
          
          {/* 价格标签 - 右上角 */}
          <div className={styles.priceBadge}>
            £{typeof item.price === 'number' ? item.price.toFixed(2) : parseFloat(String(item.price || 0)).toFixed(2)}
          </div>
          
          {/* 操作按钮（仅所有者可见） - 左上角（如果已收藏，则显示在收藏标识下方） */}
          {isOwner && (
            <div className={styles.itemActions}>
              <Button
                type="text"
                icon={<EditOutlined />}
                onClick={handleEditClick}
                className={styles.actionButton}
              />
              <Button
                type="text"
                icon={<DeleteOutlined />}
                onClick={handleDeleteClick}
                className={styles.actionButton}
                danger
              />
            </div>
          )}
          
          {/* 商品信息 - 底部叠加显示 */}
          <div className={styles.itemInfoOverlay}>
            <h3 className={styles.itemTitle}>{item.title}</h3>
            {item.location && (
              <div className={styles.itemLocation}>
                <span className={styles.locationIcon}>📍</span>
                <span>{item.location}</span>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }, (prevProps, nextProps) => {
    // 自定义比较函数，只在关键属性变化时重新渲染
    if (prevProps.item.id !== nextProps.item.id) return false;
    if (prevProps.item.title !== nextProps.item.title) return false;
    if (prevProps.item.price !== nextProps.item.price) return false;
    if (prevProps.item.location !== nextProps.item.location) return false;
    if (prevProps.item.images?.[0] !== nextProps.item.images?.[0]) return false;
    if (prevProps.isOwner !== nextProps.isOwner) return false;
    
    // 如果所有关键属性都相同，跳过重新渲染
    return true;
  });

  return (
    <div className={styles.pageContainer}>
      <SEOHead
        title={t('fleaMarket.pageTitle')}
        description={t('fleaMarket.pageDescription')}
        canonicalUrl={`https://www.link2ur.com/${language}/flea-market`}
        ogTitle={t('fleaMarket.pageTitle')}
        ogDescription={t('fleaMarket.pageDescription')}
      />
      
      {/* 顶部导航栏 - 与首页一致 */}
      <header className={headerStyles.header}>
        <div className={headerStyles.headerContainer}>
          {/* Logo - 可点击跳转到首页 */}
          <div 
            className={headerStyles.logo}
            onClick={() => navigate(`/${language}`)}
            style={{ cursor: 'pointer' }}
          >
            Link²Ur
          </div>
          
          {/* 语言切换器、通知按钮和汉堡菜单 */}
          <div className={headerStyles.headerActions}>
            <LanguageSwitcher />
            <NotificationButton
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => setShowNotifications(prev => !prev)}
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
      
      {/* 占位，防止内容被导航栏遮挡 */}
      <div className={headerStyles.headerSpacer} />
      
      {/* 通知弹窗 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />
      
      {/* 登录模态框 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={async () => {
          try {
            const userData = await fetchCurrentUser();
            setUser(userData);
            setShowLoginModal(false);
          } catch (error) {
            console.error('获取用户信息失败:', error);
          }
        }}
      />
      
      {/* 顶部横幅区域 */}
      <div className={styles.heroSection}>
        <div className={styles.heroContent}>
          <h1 className={styles.heroTitle}>
            <span className={styles.heroIcon}>🛍️</span>
            {t('fleaMarket.pageTitle')}
          </h1>
          <p className={styles.heroSubtitle}>{t('fleaMarket.pageDescription')}</p>
          {user && (
            <div style={{ display: 'flex', gap: '16px', justifyContent: 'center', flexWrap: 'wrap' }}>
              <Button
                type="primary"
                size="large"
                icon={<PlusOutlined />}
                onClick={() => {
                  setEditingItem(null);
                  setFormData({
                    title: '',
                    description: '',
                    price: 0,
                    images: [],
                    location: 'Online',
                    category: '',
                    contact: ''
                  });
                  setImageFiles([]);
                  setShowUploadModal(true);
                }}
                className={styles.uploadButton}
              >
                {t('fleaMarket.uploadItem')}
              </Button>
              <Button
                type="default"
                size="large"
                onClick={() => {
                  setShowMyItemsModal(true);
                  loadMyItems();
                }}
                className={styles.myItemsButton}
              >
                {t('fleaMarket.myItems')}
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* 搜索和筛选 */}
      <div className={styles.filtersSection}>
        <div className={styles.filtersWrapper}>
          <div className={styles.searchWrapper}>
            <Search
              placeholder={t('fleaMarket.searchPlaceholder')}
              value={searchKeyword}
              onChange={(e) => setSearchKeyword(e.target.value)}
              onSearch={(value) => setSearchKeyword(value)}
              size="large"
              allowClear
              className={styles.searchInput}
            />
          </div>
          <div className={styles.filtersRow}>
            <div className={styles.locationFilter}>
              <Select
                placeholder={t('fleaMarket.locationFilterPlaceholder')}
                value={selectedLocation}
                onChange={(value) => setSelectedLocation(value || undefined)}
                onClear={() => {
                  setSelectedLocation(undefined);
                }}
                allowClear
                size="large"
                style={{ width: '100%' }}
                showSearch={!isMobile}
                filterOption={isMobile ? undefined : (input, option) =>
                  (option?.children as unknown as string)?.toLowerCase().includes(input.toLowerCase())
                }
                getPopupContainer={(triggerNode) => triggerNode.parentElement || document.body}
                dropdownStyle={{
                  maxHeight: isMobile ? '300px' : '400px',
                  overflow: 'auto',
                  WebkitOverflowScrolling: 'touch'
                }}
                onDropdownVisibleChange={(open) => {
                  if (open && isMobile) {
                    // 移动端打开下拉框时，记录当前滚动位置并禁用页面滚动
                    const scrollY = window.scrollY;
                    document.body.style.position = 'fixed';
                    document.body.style.top = `-${scrollY}px`;
                    document.body.style.width = '100%';
                    document.body.style.overflow = 'hidden';
                    // 保存滚动位置到data属性
                    document.body.setAttribute('data-scroll-y', scrollY.toString());
                  } else if (!open && isMobile) {
                    // 关闭时恢复页面滚动
                    const scrollY = document.body.getAttribute('data-scroll-y');
                    document.body.style.position = '';
                    document.body.style.top = '';
                    document.body.style.width = '';
                    document.body.style.overflow = '';
                    if (scrollY) {
                      window.scrollTo(0, parseInt(scrollY, 10));
                    }
                    document.body.removeAttribute('data-scroll-y');
                  }
                }}
              >
                {CITIES.map((city: string) => (
                  <Select.Option key={city} value={city}>
                    {t(`publishTask.cities.${city}`) || city}
                  </Select.Option>
                ))}
              </Select>
            </div>
            <div className={styles.categoryFilter}>
              <Select
                placeholder={t('fleaMarket.categoryFilterPlaceholder')}
                value={selectedCategory}
                onChange={(value) => setSelectedCategory(value || undefined)}
                allowClear
                size="large"
                style={{ width: '100%' }}
                showSearch={!isMobile}
                filterOption={isMobile ? undefined : (input, option) =>
                  (option?.children as unknown as string)?.toLowerCase().includes(input.toLowerCase())
                }
                getPopupContainer={(triggerNode) => triggerNode.parentElement || document.body}
                dropdownStyle={{
                  maxHeight: isMobile ? '300px' : '400px',
                  overflow: 'auto',
                  WebkitOverflowScrolling: 'touch'
                }}
                onDropdownVisibleChange={(open) => {
                  if (open && isMobile) {
                    // 移动端打开下拉框时，记录当前滚动位置并禁用页面滚动
                    const scrollY = window.scrollY;
                    document.body.style.position = 'fixed';
                    document.body.style.top = `-${scrollY}px`;
                    document.body.style.width = '100%';
                    document.body.style.overflow = 'hidden';
                    // 保存滚动位置到data属性
                    document.body.setAttribute('data-scroll-y', scrollY.toString());
                  } else if (!open && isMobile) {
                    // 关闭时恢复页面滚动
                    const scrollY = document.body.getAttribute('data-scroll-y');
                    document.body.style.position = '';
                    document.body.style.top = '';
                    document.body.style.width = '';
                    document.body.style.overflow = '';
                    if (scrollY) {
                      window.scrollTo(0, parseInt(scrollY, 10));
                    }
                    document.body.removeAttribute('data-scroll-y');
                  }
                }}
              >
                {CATEGORIES.map((category: string) => (
                  <Select.Option key={category} value={category}>
                    {t(`fleaMarket.categories.${category}`) || category}
                  </Select.Option>
                ))}
              </Select>
            </div>
          </div>
        </div>
      </div>

      {/* 商品列表 */}
      <div className={styles.itemsSection}>
        {loading && filteredItems.length === 0 ? (
          <div className={styles.loadingContainer}>
            <Spin size="large" />
            <p className={styles.loadingText}>{t('common.loading')}</p>
          </div>
        ) : filteredItems.length === 0 ? (
          <div className={styles.emptyContainer}>
            <div className={styles.emptyIcon}>🛍️</div>
            <h3 className={styles.emptyTitle}>{t('fleaMarket.noItems')}</h3>
          </div>
        ) : (
          <div className={styles.itemsGrid}>
            {filteredItems.map(item => (
              <FleaMarketItemCard
                key={item.id}
                item={item}
                isOwner={isOwner(item)}
                isFavorited={favoriteItemIds.has(String(item.id))}
                onEdit={handleEdit}
                onDelete={handleDelete}
                onCardClick={handleCardClick}
              />
            ))}
          </div>
        )}
        
        {/* 加载更多指示器 */}
        {loadingMore && (
          <div style={{ 
            display: 'flex', 
            justifyContent: 'center', 
            alignItems: 'center', 
            padding: '20px',
            width: '100%'
          }}>
            <Spin size="large" />
            <span style={{ marginLeft: '12px' }}>{t('common.loading')}</span>
          </div>
        )}
      </div>

      {/* 上传/编辑模态框 */}
      <Modal
        title={editingItem ? t('fleaMarket.editItem') : t('fleaMarket.uploadItem')}
        open={showUploadModal}
        onOk={handleSubmit}
        onCancel={() => {
          setShowUploadModal(false);
          setEditingItem(null);
        }}
        confirmLoading={uploading}
        width={600}
      >
        <div className={styles.form}>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.title')} *</label>
            <Input
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              placeholder={t('fleaMarket.titlePlaceholder')}
            />
          </div>
          
          <div className={styles.formItem}>
            <label>{t('fleaMarket.description')} *</label>
            <TextArea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder={t('fleaMarket.descriptionPlaceholder')}
              rows={4}
            />
          </div>
          
          <div className={styles.formItem}>
            <label>{t('fleaMarket.price')} (GBP) *</label>
            <InputNumber
              value={formData.price}
              onChange={(value) => setFormData({ ...formData, price: value || 0 })}
              min={0}
              step={0.01}
              style={{ width: '100%' }}
              placeholder={t('fleaMarket.pricePlaceholder')}
            />
          </div>
          
          <div className={styles.formItem}>
            <label>{t('fleaMarket.images')} ({t('fleaMarket.maxImages')})</label>
            <Upload
              listType="picture-card"
              fileList={imageFiles.map((file, index): UploadFile => ({
                uid: `-${index}`,
                name: file.name,
                status: 'done' as const,
                originFileObj: file as any
              }))}
              onChange={handleImageChange}
              beforeUpload={() => false}
              maxCount={5}
            >
              {imageFiles.length < 5 && (
                <div>
                  <PlusOutlined />
                  <div style={{ marginTop: 8 }}>{t('fleaMarket.upload')}</div>
                </div>
              )}
            </Upload>
          </div>
          
          <div className={styles.formItem}>
            <label>{t('fleaMarket.location')}</label>
            <Select
              value={formData.location}
              onChange={(value) => setFormData({ ...formData, location: value })}
              placeholder={t('fleaMarket.locationPlaceholder')}
              style={{ width: '100%' }}
              showSearch
              filterOption={(input, option) => {
                const label = typeof option?.label === 'string' ? option.label : String(option?.label ?? '');
                return label.toLowerCase().includes(input.toLowerCase());
              }}
            >
              {CITIES.map((city: string) => (
                <Select.Option key={city} value={city} label={t(`publishTask.cities.${city}`)}>
                  {t(`publishTask.cities.${city}`)}
                </Select.Option>
              ))}
            </Select>
          </div>
          
          <div className={styles.formItem}>
            <label>{t('fleaMarket.category')}</label>
            <Select
              value={formData.category || undefined}
              onChange={(value) => setFormData({ ...formData, category: value || '' })}
              placeholder={t('fleaMarket.categoryPlaceholder')}
              allowClear
              showSearch
              filterOption={(input, option) =>
                (option?.children as unknown as string)?.toLowerCase().includes(input.toLowerCase())
              }
            >
              {CATEGORIES.map((category: string) => (
                <Select.Option key={category} value={category}>
                  {t(`fleaMarket.categories.${category}`) || category}
                </Select.Option>
              ))}
            </Select>
          </div>
          
          <div className={styles.formItem}>
            <label>{t('fleaMarket.contact')}</label>
            <Input
              value={formData.contact}
              onChange={(e) => setFormData({ ...formData, contact: e.target.value })}
              placeholder={t('fleaMarket.contactPlaceholder')}
            />
          </div>
        </div>
      </Modal>

      {/* 跳蚤市场须知弹窗 */}
      <Modal
        title={<span style={{ fontSize: '20px', fontWeight: 'bold' }}>{t('fleaMarket.noticeTitle')}</span>}
        open={showNoticeModal}
        onCancel={() => {
          // 用户点击 X 按钮关闭时，也需要设置 localStorage
          // 但只有勾选了同意才能关闭，所以这里不应该允许直接关闭
          // 如果用户强制关闭（比如按 ESC），我们也记录已查看
          localStorage.setItem('fleaMarket_notice_seen', 'true');
          setShowNoticeModal(false);
        }}
        footer={[
          <Button
            key="confirm"
            type="primary"
            size="large"
            onClick={() => {
              setShowNoticeModal(false);
              localStorage.setItem('fleaMarket_notice_seen', 'true');
              setNoticeAgreed(false); // 重置状态
            }}
            disabled={!noticeAgreed}
            style={{ minWidth: '120px' }}
          >
            {t('fleaMarket.noticeConfirm')}
          </Button>
        ]}
        width={600}
        closable={false}
        maskClosable={false}
        keyboard={false}
      >
        <div style={{ padding: '20px 0' }}>
          <p style={{ fontSize: '16px', marginBottom: '20px', color: '#666' }}>
            {t('fleaMarket.noticeContent')}
          </p>
          <ul style={{ 
            listStyle: 'none', 
            padding: 0, 
            margin: 0,
            maxHeight: '400px',
            overflowY: 'auto'
          }}>
            {(() => {
              // 直接从翻译对象获取数组
              const translations = language === 'zh' ? zhTranslations : enTranslations;
              const rulesArray = (translations.fleaMarket?.noticeRules || []) as string[];
              
              return rulesArray.map((rule: string, index: number) => (
                <li 
                  key={index}
                  style={{
                    padding: '12px 0',
                    borderBottom: index < rulesArray.length - 1 ? '1px solid #f0f0f0' : 'none',
                    fontSize: '14px',
                    lineHeight: '1.6',
                    color: '#333',
                    display: 'flex',
                    alignItems: 'flex-start'
                  }}
                >
                  <span style={{ 
                    color: '#ff4d4f', 
                    marginRight: '8px', 
                    fontWeight: 'bold',
                    flexShrink: 0
                  }}>•</span>
                  <span>{rule}</span>
                </li>
              ));
            })()}
          </ul>
          <div style={{ 
            marginTop: '24px', 
            padding: '16px', 
            background: '#f6f8fa', 
            borderRadius: '8px',
            fontSize: '14px',
            color: '#666',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px'
          }}>
            <Checkbox
              checked={noticeAgreed}
              onChange={(e) => setNoticeAgreed(e.target.checked)}
              style={{ fontSize: '14px' }}
            >
              {t('fleaMarket.noticeAgree')}
            </Checkbox>
          </div>
        </div>
      </Modal>

      {/* 我的闲置弹窗 */}
      <Modal
        title={<span style={{ fontSize: '20px', fontWeight: 'bold' }}>{t('fleaMarket.myItemsModalTitle')}</span>}
        open={showMyItemsModal}
        onCancel={() => setShowMyItemsModal(false)}
        footer={[
          <Button key="close" onClick={() => setShowMyItemsModal(false)}>
            {t('common.close') || '关闭'}
          </Button>
        ]}
        width={900}
        closable={true}
        maskClosable={true}
      >
        <Tabs
          defaultActiveKey="posted"
          items={[
            {
              key: 'posted',
              label: t('fleaMarket.myPostedItems'),
              children: (
                <div style={{ minHeight: '400px', maxHeight: '600px', overflowY: 'auto' }}>
                  {loadingMyItems ? (
                    <div style={{ textAlign: 'center', padding: '40px' }}>
                      <Spin size="large" />
                      <p style={{ marginTop: '16px', color: '#666' }}>{t('common.loading')}</p>
                    </div>
                  ) : myPostedItems.length === 0 ? (
                    <Empty
                      description={t('fleaMarket.noPostedItems')}
                      image={Empty.PRESENTED_IMAGE_SIMPLE}
                    />
                  ) : (
                    <div className={styles.itemsGrid} style={{ padding: '10px 0' }}>
                      {myPostedItems
                        .filter(item => item.seller_id === user?.id)  // 再次确保只显示当前用户的商品
                        .map(item => (
                          <FleaMarketItemCard
                            key={item.id}
                            item={item}
                            isOwner={true}  // 我的闲置中，所有商品都是我的
                            isFavorited={favoriteItemIds.has(String(item.id))}
                            onEdit={handleEdit}
                            onDelete={handleDelete}
                            onCardClick={handleCardClick}
                          />
                        ))}
                    </div>
                  )}
                </div>
              )
            },
            {
              key: 'purchased',
              label: t('fleaMarket.myPurchasedItems'),
              children: (
                <div style={{ minHeight: '400px', maxHeight: '600px', overflowY: 'auto' }}>
                  {loadingMyItems ? (
                    <div style={{ textAlign: 'center', padding: '40px' }}>
                      <Spin size="large" />
                      <p style={{ marginTop: '16px', color: '#666' }}>{t('common.loading')}</p>
                    </div>
                  ) : myPurchasedItems.length === 0 ? (
                    <Empty
                      description={t('fleaMarket.noPurchasedItems')}
                      image={Empty.PRESENTED_IMAGE_SIMPLE}
                    />
                  ) : (
                    <div className={styles.itemsGrid} style={{ padding: '10px 0' }}>
                      {myPurchasedItems.map(item => (
                        <FleaMarketItemCard
                          key={item.id}
                          item={item}
                          isOwner={false}
                          isFavorited={favoriteItemIds.has(String(item.id))}
                          onEdit={() => {}}
                          onDelete={() => {}}
                          onCardClick={handleCardClick}
                        />
                      ))}
                    </div>
                  )}
                </div>
              )
            },
            {
              key: 'favorites',
              label: t('fleaMarket.myFavorites') || '我的收藏',
              children: (
                <div style={{ minHeight: '400px', maxHeight: '600px', overflowY: 'auto' }}>
                  {loadingMyItems ? (
                    <div style={{ textAlign: 'center', padding: '40px' }}>
                      <Spin size="large" />
                      <p style={{ marginTop: '16px', color: '#666' }}>{t('common.loading')}</p>
                    </div>
                  ) : myFavoriteItems.length === 0 ? (
                    <Empty
                      description={t('fleaMarket.noFavoriteItems') || '您还没有收藏任何商品'}
                      image={Empty.PRESENTED_IMAGE_SIMPLE}
                    />
                  ) : (
                    <div className={styles.itemsGrid} style={{ padding: '10px 0' }}>
                      {myFavoriteItems
                        .filter(item => item.status === 'active') // 只显示活跃状态的商品
                        .map(item => (
                          <FleaMarketItemCard
                            key={item.id}
                            item={item}
                            isOwner={user?.id === item.seller_id}
                            isFavorited={true} // 收藏列表中的商品都是已收藏的
                            onEdit={user?.id === item.seller_id ? handleEdit : () => {}}
                            onDelete={user?.id === item.seller_id ? handleDelete : () => {}}
                            onCardClick={handleCardClick}
                          />
                        ))}
                    </div>
                  )}
                </div>
              )
            }
          ]}
        />
      </Modal>

      {/* 商品详情弹窗 */}
      <FleaMarketItemDetailModal
        isOpen={showItemDetailModal}
        onClose={() => {
          setShowItemDetailModal(false);
          setSelectedItemId(null);
        }}
        itemId={selectedItemId}
        onItemUpdated={() => {
          // 商品更新后重新加载列表和收藏状态
          loadItemsRef.current(false, undefined, debouncedSearchKeyword || undefined, selectedCategory, selectedLocation);
          // 重新加载收藏列表（如果打开了我的闲置弹窗）
          if (showMyItemsModal) {
            loadMyItems();
          }
        }}
        onFavoriteChanged={(itemId, isFavorited) => {
          // 更新收藏状态
          const newFavoriteIds = new Set(favoriteItemIds);
          if (isFavorited) {
            newFavoriteIds.add(String(itemId));
          } else {
            newFavoriteIds.delete(String(itemId));
          }
          setFavoriteItemIds(newFavoriteIds);
          // 如果打开了我的闲置弹窗，重新加载收藏列表
          if (showMyItemsModal) {
            loadMyItems();
          }
        }}
        onEdit={(item) => {
          // 关闭详情弹窗，打开编辑模态框
          setShowItemDetailModal(false);
          setSelectedItemId(null);
          // 转换类型以匹配 FleaMarketPage 的接口
          const convertedItem: FleaMarketItem = {
            ...item,
            id: typeof item.id === 'string' ? parseInt(item.id, 10) : item.id,
            currency: (item.currency || 'GBP') as 'GBP',
            status: item.status as 'active' | 'sold' | 'deleted',
            contact: (item as any).contact || undefined
          };
          handleEdit(convertedItem);
        }}
      />
    </div>
  );
};

export default FleaMarketPage;

