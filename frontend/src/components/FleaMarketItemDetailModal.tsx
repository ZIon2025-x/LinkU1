import React, { useState, useEffect, useCallback } from 'react';
import { Modal, Spin, Empty, Button, Space, message, Input, InputNumber, Rate } from 'antd';
import { 
  HeartOutlined, 
  HeartFilled, 
  EditOutlined, 
  DeleteOutlined,
  FlagOutlined,
  ShoppingCartOutlined,
  MessageOutlined,
  CloseOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import api from '../api';
import styles from './FleaMarketItemDetailModal.module.css';

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

interface FleaMarketItemDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  itemId: string | null;
  onItemUpdated?: () => void;  // 商品更新后的回调
  onEdit?: (item: FleaMarketItem) => void;  // 编辑商品回调
  onFavoriteChanged?: (itemId: string, isFavorited: boolean) => void;  // 收藏状态改变回调
}

const FleaMarketItemDetailModal: React.FC<FleaMarketItemDetailModalProps> = ({ 
  isOpen, 
  onClose, 
  itemId,
  onItemUpdated,
  onEdit,
  onFavoriteChanged
}) => {
  const { t, language } = useLanguage();
  const { user: currentUser } = useCurrentUser();
  const navigate = useNavigate();
  
  const [item, setItem] = useState<FleaMarketItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [isFavorited, setIsFavorited] = useState(false);
  const [favoriteLoading, setFavoriteLoading] = useState(false);
  const [purchaseLoading, setPurchaseLoading] = useState(false);
  const [showPurchaseModal, setShowPurchaseModal] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);
  const [reportLoading, setReportLoading] = useState(false);
  const [proposedPrice, setProposedPrice] = useState<number | undefined>();
  const [purchaseMessage, setPurchaseMessage] = useState('');
  const [reportReason, setReportReason] = useState<string>('');
  const [reportDescription, setReportDescription] = useState('');
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [sellerInfo, setSellerInfo] = useState<any>(null);
  
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
      message.error(error.response?.data?.detail || t('fleaMarket.loadItemError') || '加载商品详情失败');
      if (error.response?.status === 404) {
        onClose();
      }
    } finally {
      setLoading(false);
    }
  }, [itemId, currentUser, onClose, t]);
  
  useEffect(() => {
    if (isOpen && itemId) {
      loadItem();
      setCurrentImageIndex(0);
      setShowPurchaseModal(false);
      setShowReportModal(false);
    } else {
      setItem(null);
      setIsFavorited(false);
      setSellerInfo(null);
    }
  }, [isOpen, itemId, loadItem]);
  
  // 收藏/取消收藏
  const handleToggleFavorite = useCallback(async () => {
    if (!currentUser) {
      message.warning(t('common.pleaseLogin') || '请先登录');
      return;
    }
    
    if (!itemId) return;
    
    setFavoriteLoading(true);
    try {
      await api.post(`/api/flea-market/items/${itemId}/favorite`);
      const newFavoritedState = !isFavorited;
      setIsFavorited(newFavoritedState);
      message.success(newFavoritedState ? t('fleaMarket.favoriteSuccess') || '收藏成功' : t('fleaMarket.unfavoriteSuccess') || '已取消收藏');
      // 通知父组件收藏状态已改变
      if (onFavoriteChanged && itemId) {
        onFavoriteChanged(itemId, newFavoritedState);
      }
    } catch (error: any) {
      console.error('收藏操作失败:', error);
      message.error(error.response?.data?.detail || '操作失败');
    } finally {
      setFavoriteLoading(false);
    }
  }, [itemId, isFavorited, currentUser, t]);
  
  // 直接购买
  const handleDirectPurchase = useCallback(async () => {
    if (!currentUser) {
      message.warning(t('common.pleaseLogin') || '请先登录');
      return;
    }
    
    if (!itemId) return;
    
    Modal.confirm({
      title: t('fleaMarket.confirmPurchase') || '确认购买',
      content: `${t('fleaMarket.confirmPurchaseMessage') || '确定要以'} £${item?.price?.toFixed(2) || '0.00'} ${t('fleaMarket.confirmPurchaseMessage2') || '的价格购买「'}${item?.title || ''}${t('fleaMarket.confirmPurchaseMessage3') || '」吗？'}`,
      onOk: async () => {
        setPurchaseLoading(true);
        try {
          const response = await api.post(`/api/flea-market/items/${itemId}/direct-purchase`);
          message.success(t('fleaMarket.purchaseSuccess') || '购买成功！任务已创建');
          onClose();
          navigate(`/${language}/message`);
        } catch (error: any) {
          console.error('购买失败:', error);
          message.error(error.response?.data?.detail || '购买失败');
        } finally {
          setPurchaseLoading(false);
        }
      }
    });
  }, [itemId, item, currentUser, language, navigate, onClose, t]);
  
  // 提交购买申请
  const handleSubmitPurchaseRequest = useCallback(async () => {
    if (!currentUser || !itemId) return;
    
    setPurchaseLoading(true);
    try {
      await api.post(`/api/flea-market/items/${itemId}/purchase-request`, {
        proposed_price: proposedPrice,
        message: purchaseMessage
      });
      message.success(t('fleaMarket.purchaseRequestSubmitted') || '购买申请已提交，等待卖家处理');
      setShowPurchaseModal(false);
      setProposedPrice(undefined);
      setPurchaseMessage('');
      if (onItemUpdated) {
        onItemUpdated();
      }
    } catch (error: any) {
      console.error('提交购买申请失败:', error);
      message.error(error.response?.data?.detail || '提交失败');
    } finally {
      setPurchaseLoading(false);
    }
  }, [itemId, proposedPrice, purchaseMessage, currentUser, onItemUpdated, t]);
  
  // 举报商品
  const handleReport = useCallback(async () => {
    if (!currentUser || !itemId || !reportReason) {
      message.warning(t('fleaMarket.selectReason') || '请选择举报原因');
      return;
    }
    
    setReportLoading(true);
    try {
      await api.post(`/api/flea-market/items/${itemId}/report`, {
        reason: reportReason,
        description: reportDescription
      });
      message.success(t('fleaMarket.reportSubmitted') || '举报已提交，我们会尽快处理');
      setShowReportModal(false);
      setReportReason('');
      setReportDescription('');
    } catch (error: any) {
      console.error('举报失败:', error);
      message.error(error.response?.data?.detail || t('fleaMarket.reportError') || '举报失败');
    } finally {
      setReportLoading(false);
    }
  }, [itemId, reportReason, reportDescription, currentUser, t]);
  
  if (!isOpen) return null;
  
  return (
    <>
      <Modal
        open={isOpen}
        onCancel={onClose}
        footer={null}
        width={900}
        className={styles.modal}
        closeIcon={<CloseOutlined />}
      >
        {loading ? (
          <div className={styles.loadingContainer}>
            <Spin size="large" />
          </div>
        ) : !item ? (
          <Empty description={t('fleaMarket.itemNotFound') || '商品不存在'} />
        ) : (
          <>
            {/* 顶部操作按钮 - 收藏和举报（仅非所有者且商品活跃时显示） */}
            {!isOwner && isActive && (
              <div className={styles.topActions}>
                <Button
                  type={isFavorited ? 'default' : 'primary'}
                  icon={isFavorited ? <HeartFilled /> : <HeartOutlined />}
                  loading={favoriteLoading}
                  onClick={handleToggleFavorite}
                  className={styles.topActionButton}
                  title={isFavorited ? t('fleaMarket.unfavorite') : t('fleaMarket.favorite')}
                />
                <Button
                  danger
                  icon={<FlagOutlined />}
                  onClick={() => setShowReportModal(true)}
                  className={styles.topActionButton}
                  title={t('fleaMarket.report')}
                />
              </div>
            )}
            <div className={styles.content}>
            {/* 左侧：图片 */}
            <div className={styles.imageSection}>
              {item.images && item.images.length > 0 ? (
                <>
                  <div className={styles.mainImage}>
                    <img
                      src={item.images[currentImageIndex]}
                      alt={item.title}
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
                  <span className={styles.category}>
                    {t(`fleaMarket.categories.${item.category}`) || item.category}
                  </span>
                )}
                {item.location && (
                  <span className={styles.location}>📍 {item.location}</span>
                )}
                <span className={styles.views}>
                  👁️ {item.view_count || 0} {t('fleaMarket.views')}
                </span>
              </div>
              
              <div className={styles.description}>
                <h3>{t('fleaMarket.description')}</h3>
                <p>{item.description}</p>
              </div>
              
              {sellerInfo && (
                <div className={styles.sellerInfo}>
                  <h3>{t('fleaMarket.seller')}</h3>
                  <div className={styles.sellerCard}>
                    <span className={styles.sellerName}>
                      {sellerInfo.name || `用户${sellerInfo.id}`}
                    </span>
                    {sellerInfo.avg_rating > 0 && (
                      <Rate disabled defaultValue={sellerInfo.avg_rating} allowHalf style={{ fontSize: 14 }} />
                    )}
                    <Button
                      type="link"
                      onClick={() => {
                        onClose();
                        navigate(`/${language}/user/${sellerInfo.id}`);
                      }}
                    >
                      {t('fleaMarket.viewProfile')}
                    </Button>
                  </div>
                </div>
              )}
              
              {/* 操作按钮 */}
              <div className={styles.actions}>
                {isOwner ? (
                  <Space>
                    <Button
                      icon={<EditOutlined />}
                      onClick={() => {
                        onClose();
                        // 触发编辑回调
                        if (onEdit && item) {
                          onEdit(item);
                        }
                      }}
                    >
                      {t('fleaMarket.editItem')}
                    </Button>
                    <Button
                      danger
                      icon={<DeleteOutlined />}
                      onClick={() => {
                        Modal.confirm({
                          title: t('fleaMarket.confirmDelete'),
                          content: t('fleaMarket.confirmDeleteMessage'),
                          onOk: async () => {
                            try {
                              await api.put(`/api/flea-market/items/${item.id}`, { status: 'deleted' });
                              message.success(t('fleaMarket.deleteSuccess'));
                              onClose();
                              if (onItemUpdated) {
                                onItemUpdated();
                              }
                            } catch (error: any) {
                              message.error(error.response?.data?.detail || '删除失败');
                            }
                          }
                        });
                      }}
                    >
                      {t('fleaMarket.delete')}
                    </Button>
                  </Space>
                ) : (
                  <>
                    {isActive && (
                      <Space wrap>
                        <Button
                          type="primary"
                          size="large"
                          icon={<ShoppingCartOutlined />}
                          loading={purchaseLoading}
                          onClick={handleDirectPurchase}
                        >
                          {t('fleaMarket.buyNow')}
                        </Button>
                        <Button
                          icon={<MessageOutlined />}
                          onClick={() => setShowPurchaseModal(true)}
                        >
                          {t('fleaMarket.makeOffer')}
                        </Button>
                      </Space>
                    )}
                    {!isActive && (
                      <div className={styles.statusBadge}>
                        {item.status === 'sold' ? t('fleaMarket.sold') : t('fleaMarket.deleted')}
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>
          </div>
          </>
        )}
      </Modal>
      
      {/* 购买申请弹窗 */}
      <Modal
        title={t('fleaMarket.makeOffer')}
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
            <label>{t('fleaMarket.originalPrice')}: £{item?.price?.toFixed(2) || '0.00'}</label>
          </div>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.proposedPrice')} ({t('common.optional') || '可选'})</label>
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
            <label>{t('fleaMarket.message')}</label>
            <TextArea
              value={purchaseMessage}
              onChange={(e) => setPurchaseMessage(e.target.value)}
              rows={4}
              placeholder={t('fleaMarket.messagePlaceholder')}
            />
          </div>
        </div>
      </Modal>
      
      {/* 举报弹窗 */}
      <Modal
        title={t('fleaMarket.report')}
        open={showReportModal}
        onOk={handleReport}
        onCancel={() => {
          setShowReportModal(false);
          setReportReason('');
          setReportDescription('');
        }}
        confirmLoading={reportLoading}
        okText={t('common.submit') || '提交'}
        cancelText={t('common.cancel') || '取消'}
      >
        <div className={styles.reportForm}>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.reportReason')} *</label>
            <select
              value={reportReason}
              onChange={(e) => setReportReason(e.target.value)}
              style={{ width: '100%', padding: '8px', borderRadius: '4px' }}
            >
              <option value="">{t('fleaMarket.selectReason')}</option>
              <option value="spam">{t('fleaMarket.reasonSpam')}</option>
              <option value="fraud">{t('fleaMarket.reasonFraud')}</option>
              <option value="inappropriate">{t('fleaMarket.reasonInappropriate')}</option>
              <option value="other">{t('fleaMarket.reasonOther')}</option>
            </select>
          </div>
          <div className={styles.formItem}>
            <label>{t('fleaMarket.reportDescription')}</label>
            <TextArea
              value={reportDescription}
              onChange={(e) => setReportDescription(e.target.value)}
              rows={4}
              placeholder={t('fleaMarket.reportDescriptionPlaceholder')}
            />
          </div>
        </div>
      </Modal>
    </>
  );
};

export default FleaMarketItemDetailModal;

