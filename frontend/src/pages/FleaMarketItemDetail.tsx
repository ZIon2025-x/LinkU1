import React, { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { message, Button, Space, Modal, Input, InputNumber, Rate, Card, Spin, Empty, Image } from 'antd';
import { 
  HeartOutlined, 
  HeartFilled, 
  ArrowLeftOutlined, 
  EditOutlined, 
  DeleteOutlined,
  FlagOutlined,
  ShoppingCartOutlined,
  MessageOutlined,
  ReloadOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import api from '../api';
import SEOHead from '../components/SEOHead';
import FleaMarketStructuredData from '../components/FleaMarketStructuredData';
import HreflangManager from '../components/HreflangManager';
import BreadcrumbStructuredData from '../components/BreadcrumbStructuredData';
import styles from './FleaMarketItemDetail.module.css';

const { TextArea } = Input;

interface FleaMarketItem {
  id: string;
  title: string;
  description: string;
  price: number;
  currency: string;
  images: string[];
  location?: string;
  category?: string;
  status: string;
  seller_id: string;
  view_count: number;
  refreshed_at: string;
  created_at: string;
  updated_at: string;
}

const FleaMarketItemDetail: React.FC = () => {
  const { itemId } = useParams<{ itemId: string }>();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const { user: currentUser } = useCurrentUser();
  
  const [item, setItem] = useState<FleaMarketItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [isFavorited, setIsFavorited] = useState(false);
  const [favoriteLoading, setFavoriteLoading] = useState(false);
  const [purchaseLoading, setPurchaseLoading] = useState(false);
  const [showPurchaseModal, setShowPurchaseModal] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);
  const [proposedPrice, setProposedPrice] = useState<number | undefined>();
  const [purchaseMessage, setPurchaseMessage] = useState('');
  const [reportReason, setReportReason] = useState<string>('');
  const [reportDescription, setReportDescription] = useState('');
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [sellerInfo, setSellerInfo] = useState<any>(null);
  const [refreshLoading, setRefreshLoading] = useState(false);
  
  const isOwner = currentUser && item && currentUser.id === item.seller_id;
  const isActive = item?.status === 'active';
  
  // 加载商品详情
  const loadItem = useCallback(async () => {
    if (!itemId) return;
    
    setLoading(true);
    try {
      const response = await api.get(`/api/flea-market/items/${itemId}`);
      const data = response.data;
      
      // 处理价格类型
      const processedItem = {
        ...data,
        price: typeof data.price === 'number' ? data.price : parseFloat(String(data.price || 0)),
        images: typeof data.images === 'string' ? JSON.parse(data.images || '[]') : (data.images || [])
      };
      
      setItem(processedItem);
      
      // 加载卖家信息
      if (processedItem.seller_id) {
        try {
          const sellerResponse = await api.get(`/api/users/profile/${processedItem.seller_id}`);
          setSellerInfo(sellerResponse.data.user);
        } catch (e) {
          console.error('加载卖家信息失败:', e);
        }
      }
      
      // 检查是否已收藏（如果已登录）
      if (currentUser) {
        try {
          const favoritesResponse = await api.get('/api/flea-market/favorites', {
            params: { page: 1, pageSize: 100 }
          });
          const favorites = favoritesResponse.data.items || [];
          const isFav = favorites.some((fav: any) => fav.item_id === itemId);
          setIsFavorited(isFav);
        } catch (e) {
          // 忽略错误
        }
      }
    } catch (error: any) {
      console.error('加载商品详情失败:', error);
      message.error(error.response?.data?.detail || '加载商品详情失败');
      if (error.response?.status === 404) {
        navigate(`/${language}/flea-market`);
      }
    } finally {
      setLoading(false);
    }
  }, [itemId, currentUser, language, navigate]);
  
  useEffect(() => {
    loadItem();
  }, [loadItem]);
  
  // 收藏/取消收藏
  const handleToggleFavorite = useCallback(async () => {
    if (!currentUser) {
      message.warning('请先登录');
      return;
    }
    
    if (!itemId) return;
    
    setFavoriteLoading(true);
    try {
      await api.post(`/api/flea-market/items/${itemId}/favorite`);
      setIsFavorited(!isFavorited);
      message.success(isFavorited ? '已取消收藏' : '收藏成功');
    } catch (error: any) {
      console.error('收藏操作失败:', error);
      message.error(error.response?.data?.detail || '操作失败');
    } finally {
      setFavoriteLoading(false);
    }
  }, [itemId, isFavorited, currentUser]);
  
  // 直接购买
  const handleDirectPurchase = useCallback(async () => {
    if (!currentUser) {
      message.warning('请先登录');
      return;
    }
    
    if (!itemId) return;
    
    Modal.confirm({
      title: '确认购买',
      content: `确定要以 £${item?.price.toFixed(2)} 的价格购买「${item?.title}」吗？`,
      onOk: async () => {
        setPurchaseLoading(true);
        try {
          const response = await api.post(`/api/flea-market/items/${itemId}/direct-purchase`);
          message.success('购买成功！任务已创建');
          navigate(`/${language}/message`);
        } catch (error: any) {
          console.error('购买失败:', error);
          message.error(error.response?.data?.detail || '购买失败');
        } finally {
          setPurchaseLoading(false);
        }
      }
    });
  }, [itemId, item, currentUser, language, navigate]);
  
  // 提交购买申请
  const handleSubmitPurchaseRequest = useCallback(async () => {
    if (!currentUser || !itemId) return;
    
    setPurchaseLoading(true);
    try {
      await api.post(`/api/flea-market/items/${itemId}/purchase-request`, {
        proposed_price: proposedPrice,
        message: purchaseMessage
      });
      message.success('购买申请已提交，等待卖家处理');
      setShowPurchaseModal(false);
      setProposedPrice(undefined);
      setPurchaseMessage('');
    } catch (error: any) {
      console.error('提交购买申请失败:', error);
      message.error(error.response?.data?.detail || '提交失败');
    } finally {
      setPurchaseLoading(false);
    }
  }, [itemId, proposedPrice, purchaseMessage, currentUser]);
  
  // 举报商品
  const handleReport = useCallback(async () => {
    if (!currentUser || !itemId || !reportReason) return;
    
    try {
      await api.post(`/api/flea-market/items/${itemId}/report`, {
        reason: reportReason,
        description: reportDescription
      });
      message.success('举报已提交，我们会尽快处理');
      setShowReportModal(false);
      setReportReason('');
      setReportDescription('');
    } catch (error: any) {
      console.error('举报失败:', error);
      message.error(error.response?.data?.detail || '举报失败');
    }
  }, [itemId, reportReason, reportDescription, currentUser]);

  // 刷新商品
  const handleRefresh = useCallback(async () => {
    if (!itemId || !item) return;
    
    setRefreshLoading(true);
    try {
      const response = await api.post(`/api/flea-market/items/${itemId}/refresh`);
      message.success(t('fleaMarket.refreshSuccess') || '商品刷新成功，已更新刷新时间');
      
      // 重新加载商品信息以更新刷新时间
      await loadItem();
    } catch (error: any) {
      console.error('刷新商品失败:', error);
      message.error(error.response?.data?.detail || t('fleaMarket.refreshError') || '刷新失败');
    } finally {
      setRefreshLoading(false);
    }
  }, [itemId, item, loadItem, t]);
  
  if (loading) {
    return (
      <div className={styles.container}>
        <div className={styles.loadingContainer}>
          <Spin size="large" />
        </div>
      </div>
    );
  }
  
  if (!item) {
    return (
      <div className={styles.container}>
        <Empty description="商品不存在" />
      </div>
    );
  }
  
  // 计算 SEO 相关数据
  const seoTitle = `${item.title} - ${t('fleaMarket.pageTitle') || 'Link²Ur 跳蚤市场'}`;
  const seoDescription = item.description.replace(/<[^>]*>/g, '').substring(0, 160) || item.title;
  const canonicalUrl = `https://www.link2ur.com/${language}/flea-market/${item.id}`;
  const breadcrumbItems = [
    { 
      name: language === 'zh' ? '首页' : 'Home', 
      url: `https://www.link2ur.com/${language}` 
    },
    { 
      name: language === 'zh' ? '跳蚤市场' : 'Flea Market', 
      url: `https://www.link2ur.com/${language}/flea-market` 
    },
    { 
      name: item.title, 
      url: canonicalUrl 
    }
  ];

  return (
    <div className={styles.container}>
      {/* SEO 组件 */}
      <SEOHead
        title={seoTitle}
        description={seoDescription}
        keywords={`${item.category || ''},跳蚤市场,二手商品,${item.location || ''}`}
        canonicalUrl={canonicalUrl}
        ogTitle={item.title}
        ogDescription={seoDescription}
        ogImage={item.images?.[0] || `https://www.link2ur.com/static/og-default.jpg`}
        ogUrl={canonicalUrl}
        twitterTitle={item.title}
        twitterDescription={seoDescription}
        twitterImage={item.images?.[0] || `https://www.link2ur.com/static/og-default.jpg`}
      />
      <FleaMarketStructuredData 
        item={{
          id: parseInt(item.id),
          title: item.title,
          description: item.description,
          price: item.price,
          images: item.images || [],
          location: item.location || '',
          category: item.category || '',
          created_at: item.created_at
        }}
        language={language}
      />
      <HreflangManager type="flea-market" id={parseInt(item.id)} />
      <BreadcrumbStructuredData items={breadcrumbItems} />
      
      {/* 返回按钮 */}
      <Button
        icon={<ArrowLeftOutlined />}
        onClick={() => navigate(`/${language}/flea-market`)}
        className={styles.backButton}
      >
        {t('common.back') || '返回'}
      </Button>
      
      <div className={styles.content}>
        {/* 左侧：图片 */}
        <div className={styles.imageSection}>
          {item.images && item.images.length > 0 ? (
            <>
              <div className={styles.mainImage}>
                <Image
                  src={item.images[currentImageIndex]}
                  alt={item.title}
                  preview={false}
                  className={styles.mainImageImg}
                />
              </div>
              {item.images.length > 1 && (
                <div className={styles.thumbnailList}>
                  {item.images.map((img, index) => (
                    <div
                      key={index}
                      className={`${styles.thumbnail} ${currentImageIndex === index ? styles.active : ''}`}
                      onClick={() => setCurrentImageIndex(index)}
                    >
                      <img src={img} alt={`${item.title} ${index + 1}`} />
                    </div>
                  ))}
                </div>
              )}
            </>
          ) : (
            <div className={styles.noImage}>
              <span className={styles.placeholderIcon}>🛍️</span>
            </div>
          )}
        </div>
        
        {/* 右侧：商品信息 */}
        <div className={styles.infoSection}>
          <h1 className={styles.title}>{item.title}</h1>
          
          <div className={styles.priceSection}>
            <span className={styles.price}>£{item.price.toFixed(2)}</span>
            <span className={styles.currency}>{item.currency || 'GBP'}</span>
          </div>
          
          <div className={styles.metaInfo}>
            {item.category && (
              <span className={styles.category}>{t(`fleaMarket.categories.${item.category}`) || item.category}</span>
            )}
            {item.location && (
              <span className={styles.location}>📍 {item.location}</span>
            )}
            <span className={styles.views}>👁️ {item.view_count || 0} {t('fleaMarket.views') || '次浏览'}</span>
          </div>
          
          <div className={styles.description}>
            <h3>{t('fleaMarket.description') || '商品描述'}</h3>
            <p>{item.description}</p>
          </div>
          
          {sellerInfo && (
            <div className={styles.sellerInfo}>
              <h3>{t('fleaMarket.seller') || '卖家信息'}</h3>
              <div className={styles.sellerCard}>
                <span className={styles.sellerName}>{sellerInfo.name || `用户${sellerInfo.id}`}</span>
                {sellerInfo.avg_rating > 0 && (
                  <Rate disabled defaultValue={sellerInfo.avg_rating} allowHalf style={{ fontSize: 14 }} />
                )}
                <Button
                  type="link"
                  onClick={() => navigate(`/${language}/user/${sellerInfo.id}`)}
                >
                  {t('fleaMarket.viewProfile') || '查看资料'}
                </Button>
              </div>
            </div>
          )}
          
          {/* 操作按钮 */}
          <div className={styles.actions}>
            {isOwner ? (
              <Space>
                {isActive && (
                  <Button
                    icon={<ReloadOutlined />}
                    loading={refreshLoading}
                    onClick={handleRefresh}
                  >
                    {t('fleaMarket.refreshItem') || '刷新商品'}
                  </Button>
                )}
                <Button
                  icon={<EditOutlined />}
                  onClick={() => navigate(`/${language}/flea-market?edit=${item.id}`)}
                >
                  {t('fleaMarket.editItem') || '编辑'}
                </Button>
                <Button
                  danger
                  icon={<DeleteOutlined />}
                  onClick={() => {
                    Modal.confirm({
                      title: t('fleaMarket.confirmDelete') || '确认删除',
                      content: t('fleaMarket.confirmDeleteMessage') || '确定要删除这个商品吗？',
                      onOk: async () => {
                        try {
                          await api.put(`/api/flea-market/items/${item.id}`, { status: 'deleted' });
                          message.success(t('fleaMarket.deleteSuccess') || '删除成功');
                          navigate(`/${language}/flea-market`);
                        } catch (error: any) {
                          message.error(error.response?.data?.detail || '删除失败');
                        }
                      }
                    });
                  }}
                >
                  {t('fleaMarket.delete') || '删除'}
                </Button>
              </Space>
            ) : (
              <>
                {isActive && (
                  <Space>
                    <Button
                      type={isFavorited ? 'default' : 'primary'}
                      icon={isFavorited ? <HeartFilled /> : <HeartOutlined />}
                      loading={favoriteLoading}
                      onClick={handleToggleFavorite}
                    >
                      {isFavorited ? (t('fleaMarket.unfavorite') || '取消收藏') : (t('fleaMarket.favorite') || '收藏')}
                    </Button>
                    <Button
                      type="primary"
                      size="large"
                      icon={<ShoppingCartOutlined />}
                      loading={purchaseLoading}
                      onClick={handleDirectPurchase}
                    >
                      {t('fleaMarket.buyNow') || '立即购买'}
                    </Button>
                    <Button
                      icon={<MessageOutlined />}
                      onClick={() => setShowPurchaseModal(true)}
                    >
                      {t('fleaMarket.makeOffer') || '议价购买'}
                    </Button>
                    <Button
                      icon={<FlagOutlined />}
                      danger
                      onClick={() => setShowReportModal(true)}
                    >
                      {t('fleaMarket.report') || '举报'}
                    </Button>
                  </Space>
                )}
                {!isActive && (
                  <div className={styles.statusBadge}>
                    {item.status === 'sold' ? (t('fleaMarket.sold') || '已售出') : (t('fleaMarket.deleted') || '已下架')}
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </div>
      
      {/* 购买申请弹窗 */}
      <Modal
        title={t('fleaMarket.makeOffer') || '议价购买'}
        open={showPurchaseModal}
        onOk={handleSubmitPurchaseRequest}
        onCancel={() => {
          setShowPurchaseModal(false);
          setProposedPrice(undefined);
          setPurchaseMessage('');
        }}
        confirmLoading={purchaseLoading}
      >
        <div className={styles.purchaseForm}>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.originalPrice') || '原价'}: £{item.price.toFixed(2)}</label>
          </div>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.proposedPrice') || '议价金额'} (可选)</label>
            <InputNumber
              value={proposedPrice}
              onChange={(value) => setProposedPrice(value || undefined)}
              min={0}
              step={0.01}
              style={{ width: '100%' }}
              prefix="£"
            />
          </div>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.message') || '留言'}</label>
            <TextArea
              value={purchaseMessage}
              onChange={(e) => setPurchaseMessage(e.target.value)}
              rows={4}
              placeholder={t('fleaMarket.messagePlaceholder') || '请输入购买留言...'}
            />
          </div>
        </div>
      </Modal>
      
      {/* 举报弹窗 */}
      <Modal
        title={t('fleaMarket.report') || '举报商品'}
        open={showReportModal}
        onOk={handleReport}
        onCancel={() => {
          setShowReportModal(false);
          setReportReason('');
          setReportDescription('');
        }}
      >
        <div className={styles.reportForm}>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.reportReason') || '举报原因'} *</label>
            <select
              value={reportReason}
              onChange={(e) => setReportReason(e.target.value)}
              style={{ width: '100%', padding: '8px', borderRadius: '4px' }}
            >
              <option value="">{t('fleaMarket.selectReason') || '请选择原因'}</option>
              <option value="spam">{t('fleaMarket.reasonSpam') || '垃圾信息'}</option>
              <option value="fraud">{t('fleaMarket.reasonFraud') || '欺诈'}</option>
              <option value="inappropriate">{t('fleaMarket.reasonInappropriate') || '不当内容'}</option>
              <option value="other">{t('fleaMarket.reasonOther') || '其他'}</option>
            </select>
          </div>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.reportDescription') || '详细描述'}</label>
            <TextArea
              value={reportDescription}
              onChange={(e) => setReportDescription(e.target.value)}
              rows={4}
              placeholder={t('fleaMarket.reportDescriptionPlaceholder') || '请详细描述举报原因...'}
            />
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default FleaMarketItemDetail;

