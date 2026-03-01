import React, { useEffect, useLayoutEffect, useState, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import { message } from 'antd';
import { getActivityDetail, applyToActivity, getServiceTimeSlotsPublic } from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LoginModal from '../components/LoginModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import SEOHead from '../components/SEOHead';
import LazyImage from '../components/LazyImage';
import { TimeHandlerV2 } from '../utils/timeUtils';
import styles from './ActivityDetail.module.css';

const ActivityDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { language } = useLanguage();
  const { navigate: navigateLocalized } = useLocalizedNavigation();
  const { user } = useCurrentUser();
  
  const [activity, setActivity] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activityTimeSlots, setActivityTimeSlots] = useState<any[]>([]);
  const [loadingActivityTimeSlots, setLoadingActivityTimeSlots] = useState(false);
  const [selectedTimeSlotId, setSelectedTimeSlotId] = useState<number | null>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [applying, setApplying] = useState(false);

  // 加载活动详情
  const loadActivity = useCallback(async () => {
    if (!id) return;
    
    try {
      setLoading(true);
      const activityData = await getActivityDetail(parseInt(id));
      setActivity(activityData);
      
      // 如果是时间段服务，加载时间段列表
      if (activityData.has_time_slots && activityData.expert_service_id) {
        setLoadingActivityTimeSlots(true);
        try {
          const today = new Date();
          const futureDate = new Date(today);
          futureDate.setDate(today.getDate() + 60);
          const slots = await getServiceTimeSlotsPublic(activityData.expert_service_id, {
            start_date: today.toISOString().split('T')[0],
            end_date: futureDate.toISOString().split('T')[0],
          });
          const activitySlots = Array.isArray(slots) 
            ? slots.filter((slot: any) => slot.has_activity && slot.activity_id === activityData.id)
            : [];
          setActivityTimeSlots(activitySlots);
        } catch (err: any) {
          console.error('加载时间段失败:', err);
          setActivityTimeSlots([]);
        } finally {
          setLoadingActivityTimeSlots(false);
        }
      }
    } catch (err: any) {
      console.error('加载活动详情失败:', err);
      setError(err.response?.data?.detail || '加载活动详情失败');
      message.error(err.response?.data?.detail || '加载活动详情失败');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    loadActivity();
  }, [loadActivity]);

  // 设置微信分享的 meta 标签（参考任务详情页的实现）
  useLayoutEffect(() => {
    if (!activity) return;

    // 构建活动详情页的URL
    const activityUrl = `${window.location.origin}${window.location.pathname}`;
    
    // 更新页面标题
    const seoTitle = `${activity.title} - Link²Ur活动`;
    document.title = seoTitle;
    
    // 构建分享描述
    const descriptionPreview = activity.description 
      ? activity.description.substring(0, 150).replace(/<[^>]*>/g, '').replace(/\n/g, ' ').trim() 
      : '';
    
    // 构建完整的分享描述
    const price = activity.discounted_price_per_participant || activity.original_price_per_participant || 0;
    const priceStr = price > 0 ? `£${price.toFixed(2)}` : (language === 'zh' ? '免费' : 'Free');
    const locationStr = activity.location || (language === 'zh' ? '未指定' : 'Not specified');
    
    let activityDescription = '';
    if (language === 'zh') {
      if (descriptionPreview) {
        activityDescription = `${descriptionPreview} | 价格：${priceStr}/人 | 地点：${locationStr}`;
      } else {
        activityDescription = `活动 | 价格：${priceStr}/人 | 地点：${locationStr}`;
      }
    } else {
      if (descriptionPreview) {
        activityDescription = `${descriptionPreview} | Price: ${priceStr}/person | Location: ${locationStr}`;
      } else {
        activityDescription = `Activity | Price: ${priceStr}/person | Location: ${locationStr}`;
      }
    }
    
    // 限制总长度在200字符内（微信分享建议不超过200字符）
    const seoDescription = activityDescription.substring(0, 200);
    
    // 更新meta标签的辅助函数
    const updateMetaTag = (name: string, content: string, property?: boolean) => {
      const selector = property ? `meta[property="${name}"]` : `meta[name="${name}"]`;
      const existingTag = document.querySelector(selector);
      if (existingTag) {
        existingTag.remove();
      }
      const metaTag = document.createElement('meta');
      if (property) {
        metaTag.setAttribute('property', name);
      } else {
        metaTag.setAttribute('name', name);
      }
      metaTag.content = content;
      document.head.insertBefore(metaTag, document.head.firstChild);
    };
    
    // 强制更新meta描述
    const allDescriptions = document.querySelectorAll('meta[name="description"]');
    allDescriptions.forEach(tag => tag.remove());
    const descTag = document.createElement('meta');
    descTag.name = 'description';
    descTag.content = seoDescription;
    document.head.insertBefore(descTag, document.head.firstChild);
    
    // 强制更新og:description
    const allOgDescriptions = document.querySelectorAll('meta[property="og:description"]');
    allOgDescriptions.forEach(tag => tag.remove());
    const ogDescTag = document.createElement('meta');
    ogDescTag.setAttribute('property', 'og:description');
    ogDescTag.content = seoDescription;
    document.head.insertBefore(ogDescTag, document.head.firstChild);
    
    // 强制更新twitter:description
    const allTwitterDescriptions = document.querySelectorAll('meta[name="twitter:description"]');
    allTwitterDescriptions.forEach(tag => tag.remove());
    const twitterDescTag = document.createElement('meta');
    twitterDescTag.name = 'twitter:description';
    twitterDescTag.content = seoDescription;
    document.head.insertBefore(twitterDescTag, document.head.firstChild);
    
    // 强制更新微信分享描述（微信优先读取weixin:description）
    const allWeixinDescriptions = document.querySelectorAll('meta[name="weixin:description"]');
    allWeixinDescriptions.forEach(tag => tag.remove());
    const weixinDescTag = document.createElement('meta');
    weixinDescTag.setAttribute('name', 'weixin:description');
    weixinDescTag.content = seoDescription;
    document.head.insertBefore(weixinDescTag, document.head.firstChild);
    
    // 同时设置微信分享标题（微信也会读取）
    const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
    allWeixinTitles.forEach(tag => tag.remove());
    const weixinTitleTag = document.createElement('meta');
    weixinTitleTag.setAttribute('name', 'weixin:title');
    weixinTitleTag.content = seoTitle;
    document.head.insertBefore(weixinTitleTag, document.head.firstChild);
    
    // 更新Open Graph标签
    updateMetaTag('og:type', 'website', true);
    
    // 强制更新og:title
    const existingOgTitle = document.querySelector('meta[property="og:title"]');
    if (existingOgTitle) {
      existingOgTitle.remove();
    }
    updateMetaTag('og:title', seoTitle, true);
    
    updateMetaTag('og:url', activityUrl, true);
    
    // 设置分享图片（优先使用活动图片，否则使用默认logo图片）
    let shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    if (activity.images && Array.isArray(activity.images) && activity.images.length > 0 && activity.images[0]) {
      const activityImageUrl = activity.images[0];
      if (activityImageUrl.startsWith('http://') || activityImageUrl.startsWith('https://')) {
        shareImageUrl = activityImageUrl;
      } else if (activityImageUrl.startsWith('/')) {
        shareImageUrl = `${window.location.origin}${activityImageUrl}`;
      } else {
        shareImageUrl = `${window.location.origin}/${activityImageUrl}`;
      }
    }
    
    // 强制更新og:image
    const existingOgImage = document.querySelector('meta[property="og:image"]');
    if (existingOgImage) {
      existingOgImage.remove();
    }
    updateMetaTag('og:image', shareImageUrl, true);
    updateMetaTag('og:image:width', '1200', true);
    updateMetaTag('og:image:height', '630', true);
    updateMetaTag('og:image:type', 'image/png', true);
    
    // 强制更新微信分享图片
    const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
    allWeixinImages.forEach(tag => tag.remove());
    const weixinImageTag = document.createElement('meta');
    weixinImageTag.setAttribute('name', 'weixin:image');
    weixinImageTag.content = shareImageUrl;
    document.head.insertBefore(weixinImageTag, document.head.firstChild);
  }, [activity, language]);

  // 处理申请活动
  const handleApply = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    
    if (!activity) return;

    // 如果是时间段服务，需要选择时间段
    if (activity.has_time_slots) {
      if (!selectedTimeSlotId) {
        message.warning('请先选择一个时间段');
        return;
      }
      const selectedSlot = activityTimeSlots.find((slot: any) => slot.id === selectedTimeSlotId);
      if (!selectedSlot) {
        message.warning('选中的时间段不存在');
        return;
      }
      if (selectedSlot.is_expired || selectedSlot.current_participants >= selectedSlot.max_participants) {
        message.warning('选中的时间段已不可用，请重新选择');
        setSelectedTimeSlotId(null);
        return;
      }
    }

    setApplying(true);
    try {
      const idempotencyKey = `${user.id}_${activity.id}_${Date.now()}`;
      await applyToActivity(activity.id, {
        idempotency_key: idempotencyKey,
        time_slot_id: selectedTimeSlotId || undefined,
        is_multi_participant: (activity.max_participants || 1) > 1,
      });
      message.success('申请成功！已为您创建任务');
      // 跳转到任务列表
      navigateLocalized('/tasks');
    } catch (err: any) {
      message.error(err.response?.data?.detail || '申请失败，请重试');
    } finally {
      setApplying(false);
    }
  };

  if (loading) {
    return (
      <div className={styles.container}>
        <div className={styles.loading}>
          <div className={styles.spinner}>⏳</div>
          <div>加载中...</div>
        </div>
      </div>
    );
  }

  if (error || !activity) {
    return (
      <div className={styles.container}>
        <div className={styles.error}>
          <div>❌</div>
          <div>{error || '活动不存在'}</div>
          <button onClick={() => navigateLocalized('/tasks')} className={styles.backButton}>
            返回任务列表
          </button>
        </div>
      </div>
    );
  }

  const hasDiscount = activity.discount_percentage && activity.discount_percentage > 0;
  const originalPrice = activity.original_price_per_participant || activity.reward;
  const currentPrice = activity.discounted_price_per_participant || activity.reward;
  const currency = activity.currency || 'GBP';
  const availableSpots = (activity.max_participants || 0) - (activity.current_participants || 0);

  return (
    <div className={styles.container}>
      <SEOHead
        title={`${activity.title} - Link²Ur`}
        description={activity.description?.substring(0, 160) || '活动详情'}
        keywords={`活动, ${activity.title}`}
      />
      
      {/* 头部 */}
      <header className={styles.header}>
        <div className={styles.headerContent}>
          <div className={styles.headerLeft}>
            <div className={styles.logo} onClick={() => navigateLocalized('/')}>
              Link²Ur
            </div>
            <button onClick={() => navigateLocalized('/tasks')} className={styles.backButton}>
              ← 返回
            </button>
          </div>
          <div className={styles.headerRight}>
            <NotificationButton user={user} unreadCount={0} onNotificationClick={() => {}} />
            <HamburgerMenu
              user={user}
              onLogout={async () => {
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={{}}
              unreadCount={0}
            />
          </div>
        </div>
      </header>

      {/* 主要内容 */}
      <main className={styles.main}>
        {/* 活动图片 */}
        <div className={styles.imageSection}>
          <LazyImage
            src={activity.images && activity.images.length > 0 
              ? activity.images[0] 
              : activity.service_images && activity.service_images.length > 0
              ? activity.service_images[0]
              : 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=1200&h=600&fit=crop'}
            alt={activity.title}
            className={styles.activityImage}
          />
          <div className={styles.imageOverlay}>
            <span className={styles.activityBadge}>🎯 活动</span>
          </div>
        </div>

        {/* 活动内容 */}
        <div className={styles.content}>
          {/* 标题 */}
          <h1 className={styles.title}>{activity.title}</h1>

          {/* 价格和参与者信息 */}
          <div className={styles.infoCard}>
            <div className={styles.infoItem}>
              <div className={styles.infoLabel}>参与费用</div>
              <div className={styles.price}>
                {!currentPrice || currentPrice <= 0 ? (
                  <span>免费</span>
                ) : hasDiscount && originalPrice && originalPrice > currentPrice ? (
                  <div className={styles.priceWithDiscount}>
                    <div className={styles.originalPrice}>
                      <span className={styles.strikethrough}>{currency}{originalPrice.toFixed(2)}</span>
                      <span className={styles.discountBadge}>-{activity.discount_percentage.toFixed(0)}%</span>
                    </div>
                    <div className={styles.currentPrice}>
                      {currency}{currentPrice.toFixed(2)} <span className={styles.perPerson}>/ 人</span>
                    </div>
                  </div>
                ) : (
                  <div className={styles.currentPrice}>
                    {currency}{currentPrice.toFixed(2)} <span className={styles.perPerson}>/ 人</span>
                  </div>
                )}
              </div>
            </div>
            <div className={styles.infoDivider} />
            <div className={styles.infoItem}>
              <div className={styles.infoLabel}>参与者</div>
              <div className={styles.participants}>
                <span className={styles.participantCount}>
                  {activity.current_participants || 0} / {activity.max_participants}
                </span>
                <span className={styles.availableSpots}>
                  {availableSpots} 个空位
                </span>
              </div>
            </div>
          </div>

          {/* 活动描述 */}
          <div className={styles.section}>
            <h2 className={styles.sectionTitle}>活动描述</h2>
            <p className={styles.description}>{activity.description}</p>
          </div>

          {/* 时间段信息 */}
          {activity.has_time_slots ? (
            <div className={styles.section}>
              <h2 className={styles.sectionTitle}>
                <span>⏰</span> 可选时间段
              </h2>
              {loadingActivityTimeSlots ? (
                <div className={styles.loadingSlots}>加载时间段中...</div>
              ) : activityTimeSlots.length === 0 ? (
                <div className={styles.emptySlots}>暂无可用时间段</div>
              ) : (
                <div className={styles.timeSlotsContainer}>
                  {(() => {
                    const slotsByDate: { [key: string]: any[] } = {};
                    activityTimeSlots
                      .sort((a, b) => {
                        const aStart = a.slot_start_datetime || (a.slot_date + 'T' + a.start_time + 'Z');
                        const bStart = b.slot_start_datetime || (b.slot_date + 'T' + b.start_time + 'Z');
                        return aStart.localeCompare(bStart);
                      })
                      .forEach((slot: any) => {
                        const slotStartStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                        const slotDateUK = TimeHandlerV2.formatUtcToLocal(
                          slotStartStr.includes('T') ? slotStartStr : `${slotStartStr}T00:00:00Z`,
                          'YYYY-MM-DD',
                          'Europe/London'
                        );
                        if (!slotsByDate[slotDateUK]) {
                          slotsByDate[slotDateUK] = [];
                        }
                        slotsByDate[slotDateUK]!.push(slot);
                      });

                    const dates = Object.keys(slotsByDate).sort();
                    
                    return dates.map(date => {
                      const slots = slotsByDate[date] ?? [];
                      const firstSlot = slots[0];
                      if (!firstSlot) return null;
                      const dateStr = firstSlot.slot_start_datetime || firstSlot.slot_date;
                      const formattedDate = TimeHandlerV2.formatUtcToLocal(
                        dateStr.includes('T') ? dateStr : `${dateStr}T00:00:00Z`,
                        'YYYY年MM月DD日 ddd',
                        'Europe/London'
                      );
                      
                      return (
                        <div key={date} className={styles.dateGroup}>
                          <div className={styles.dateHeader}>📅 {formattedDate}</div>
                          <div className={styles.slotsGrid}>
                            {slots.map((slot: any) => {
                              const isFull = slot.current_participants >= slot.max_participants;
                              const isExpired = slot.is_expired === true;
                              const availableSpots = slot.max_participants - slot.current_participants;
                              const isSelected = selectedTimeSlotId === slot.id;
                              const isClickable = !isExpired && !isFull;
                              
                              const startTimeStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                              const endTimeStr = slot.slot_end_datetime || (slot.slot_date + 'T' + slot.end_time + 'Z');
                              const startTimeUK = TimeHandlerV2.formatUtcToLocal(
                                startTimeStr.includes('T') ? startTimeStr : `${startTimeStr}T00:00:00Z`,
                                'HH:mm',
                                'Europe/London'
                              );
                              const endTimeUK = TimeHandlerV2.formatUtcToLocal(
                                endTimeStr.includes('T') ? endTimeStr : `${endTimeStr}T00:00:00Z`,
                                'HH:mm',
                                'Europe/London'
                              );
                              
                              return (
                                <div
                                  key={slot.id}
                                  onClick={() => {
                                    if (isClickable) {
                                      setSelectedTimeSlotId(slot.id);
                                    }
                                  }}
                                  className={`${styles.slotCard} ${isSelected ? styles.slotCardSelected : ''} ${!isClickable ? styles.slotCardDisabled : ''}`}
                                >
                                  <div className={styles.slotTime}>
                                    {startTimeUK} - {endTimeUK}
                                    {isSelected && <span className={styles.selectedBadge}>✓ 已选择</span>}
                                    {isExpired && <span className={styles.expiredBadge}>(已过期)</span>}
                                  </div>
                                  <div className={styles.slotPrice}>
                                    {currency} {slot.activity_price?.toFixed(2) || slot.price_per_participant.toFixed(2)} / 人
                                  </div>
                                  <div className={styles.slotParticipants}>
                                    {isFull ? (
                                      <span className={styles.fullBadge}>已满 ({slot.current_participants}/{slot.max_participants})</span>
                                    ) : (
                                      <span className={styles.availableBadge}>
                                        {slot.current_participants}/{slot.max_participants} 人 ({availableSpots} 个空位)
                                      </span>
                                    )}
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      );
                    });
                  })()}
                </div>
              )}
            </div>
          ) : activity.deadline ? (
            <div className={styles.section}>
              <h2 className={styles.sectionTitle}>
                <span>⏰</span> 活动时间
              </h2>
              <div className={styles.deadline}>
                <span>📅</span>
                <span>
                  {new Date(activity.deadline).toLocaleDateString('zh-CN', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                  })}
                </span>
                <span className={styles.deadlineDivider}>|</span>
                <span>
                  {new Date(activity.deadline).toLocaleTimeString('zh-CN', {
                    hour: '2-digit',
                    minute: '2-digit',
                    hour12: false,
                  })}
                </span>
              </div>
            </div>
          ) : null}

          {/* 操作按钮 */}
          <div className={styles.actions}>
            {activity.status === 'pending_review' ? (
              <button disabled className={`${styles.applyButton} ${styles.applyButtonDisabled}`}>
                待审核
              </button>
            ) : activity.status === 'rejected' ? (
              <button disabled className={`${styles.applyButton} ${styles.applyButtonDisabled}`}>
                已拒绝
              </button>
            ) : activity.has_applied && activity.user_task_id ? (
              // 已申请，显示支付按钮或等待按钮
              activity.user_task_has_negotiation && activity.user_task_status === 'pending_payment' ? (
                // 有议价且待支付，显示等待达人回应按钮（灰色不可点击）
                <button
                  disabled
                  className={`${styles.applyButton} ${styles.applyButtonDisabled}`}
                >
                  等待达人回应
                </button>
              ) : activity.user_task_status === 'pending_payment' && !activity.user_task_is_paid ? (
                // 待支付且未支付，在新标签页打开支付页面
                <button
                  onClick={() => {
                    window.open(`/${language}/tasks/${activity.user_task_id}/payment`, '_blank');
                  }}
                  className={styles.applyButton}
                >
                  继续支付
                </button>
              ) : activity.user_task_has_negotiation && activity.user_task_status !== 'pending_payment' ? (
                // 有议价但状态不是待支付，可能是等待达人回应
                <button
                  disabled
                  className={`${styles.applyButton} ${styles.applyButtonDisabled}`}
                >
                  等待达人回应
                </button>
              ) : (
                // 其他情况，显示已申请（灰色不可点击）
                <button
                  disabled
                  className={`${styles.applyButton} ${styles.applyButtonDisabled}`}
                >
                  已申请
                </button>
              )
            ) : (
              // 未申请，显示申请按钮（仅 status 为 open 时）
              <button
                onClick={handleApply}
                disabled={applying || (activity.has_time_slots && !selectedTimeSlotId)}
                className={`${styles.applyButton} ${(activity.has_time_slots && !selectedTimeSlotId) ? styles.applyButtonDisabled : ''}`}
              >
                {applying ? '申请中...' : '立即申请'}
              </button>
            )}
          </div>
        </div>
      </main>

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          window.location.reload();
        }}
      />
    </div>
  );
};

export default ActivityDetail;
