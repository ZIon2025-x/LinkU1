import React, { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { message } from 'antd';
import { getActivityDetail, applyToActivity, getServiceTimeSlotsPublic, fetchCurrentUser } from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LoginModal from '../components/LoginModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import LanguageSwitcher from '../components/LanguageSwitcher';
import SEOHead from '../components/SEOHead';
import LazyImage from '../components/LazyImage';
import { TimeHandlerV2 } from '../utils/timeUtils';
import styles from './ActivityDetail.module.css';

const ActivityDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { t, language } = useLanguage();
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
                        slotsByDate[slotDateUK].push(slot);
                      });

                    const dates = Object.keys(slotsByDate).sort();
                    
                    return dates.map(date => {
                      const slots = slotsByDate[date];
                      const firstSlot = slots[0];
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
            <button
              onClick={handleApply}
              disabled={applying || (activity.has_time_slots && !selectedTimeSlotId)}
              className={`${styles.applyButton} ${(activity.has_time_slots && !selectedTimeSlotId) ? styles.applyButtonDisabled : ''}`}
            >
              {applying ? '申请中...' : '立即申请'}
            </button>
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
