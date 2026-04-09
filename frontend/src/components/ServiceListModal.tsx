/**
 * 服务列表弹窗组件
 * 显示任务达人的所有可用服务，用户可以选择服务并查看详情
 */

import React, { useState, useEffect } from 'react';
import { message } from 'antd';
import api, { applyForService, fetchCurrentUser, getServiceTimeSlotsPublic, applyToActivity } from '../api';
import ServiceDetailModal from './ServiceDetailModal';
import LoginModal from './LoginModal';
import { MODAL_OVERLAY_STYLE } from './TaskDetailModal.styles';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LazyImage from './LazyImage';
interface ServiceListModalProps {
  isOpen: boolean;
  onClose: () => void;
  expertId: string;
  expertName?: string;
}

interface Service {
  id: number;
  expert_id: string;
  service_name: string;
  description: string;
  images?: string[];
  base_price: number;
  currency: string;
  status: string;
  view_count: number;
  application_count: number;
  created_at: string;
  // 时间段相关字段（可选）
  has_time_slots?: boolean;
  time_slot_duration_minutes?: number;
  time_slot_start_time?: string;
  time_slot_end_time?: string;
  participants_per_slot?: number;
}

interface TimeSlot {
  id: number;
  slot_start_datetime: string;
  slot_end_datetime: string;
  price_per_participant: number;
  max_participants: number;
  current_participants: number;
  is_available: boolean;
  has_activity?: boolean;
  activity_id?: number;
  // 向后兼容的字段
  slot_date?: string;
  start_time?: string;
  end_time?: string;
  is_expired?: boolean;
}

const ServiceListModal: React.FC<ServiceListModalProps> = ({
  isOpen,
  onClose,
  expertId,
  expertName,
}) => {
  const [services, setServices] = useState<Service[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedServiceId, setSelectedServiceId] = useState<number | null>(null);
  const [showServiceDetailModal, setShowServiceDetailModal] = useState(false);
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [selectedServiceForApply, setSelectedServiceForApply] = useState<Service | null>(null);
  const [applyMessage, setApplyMessage] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState<number | undefined>();
  const [isNegotiateChecked, setIsNegotiateChecked] = useState(false);
  const [isFlexible, setIsFlexible] = useState(false);
  const [deadline, setDeadline] = useState<string>('');
  const [applying, setApplying] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  // 时间段相关状态
  const [timeSlots, setTimeSlots] = useState<TimeSlot[]>([]);
  const [loadingTimeSlots, setLoadingTimeSlots] = useState(false);
  const [selectedTimeSlotId, setSelectedTimeSlotId] = useState<number | null>(null);
  const [selectedDate, setSelectedDate] = useState<string>('');

  // 加载服务列表
  useEffect(() => {
    if (isOpen && expertId) {
      loadServices();
      loadCurrentUser();
    } else {
      // 关闭时重置状态
      setServices([]);
      setError('');
      setSelectedServiceId(null);
      setShowServiceDetailModal(false);
      setShowApplyModal(false);
      setSelectedServiceForApply(null);
      setApplyMessage('');
      setNegotiatedPrice(undefined);
      setIsNegotiateChecked(false);
      setIsFlexible(false);
      setDeadline('');
      setTimeSlots([]);
      setSelectedTimeSlotId(null);
      setSelectedDate('');
    }
  }, [isOpen, expertId]);

  const loadCurrentUser = async () => {
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
    } catch (err) {
      setUser(null);
    }
  };

  const loadServices = async () => {
    setLoading(true);
    setError('');
    try {
      // Phase B1 收口: 走新 /api/experts/{expertId}/services (expert_service_routes.py:74)
      // expertId 来自 getPublicTaskExperts 返回的新 ExpertOut.id (8 字符团队 ID)
      // 响应是 List[dict] 直接返回,不再包 {services: [...]}
      const response = await api.get(`/api/experts/${expertId}/services`, {
        params: { status: 'active' },
      });
      const servicesList: any[] = Array.isArray(response.data) ? response.data : [];
      setServices(servicesList);

      if (servicesList.length === 0) {
        setError('达人准备中，请稍后再来~');
      }
    } catch (err: any) {
      setError('加载服务列表失败');
      message.error('加载服务列表失败');
    } finally {
      setLoading(false);
    }
  };

  const handleServiceClick = (serviceId: number) => {
    setSelectedServiceId(serviceId);
    setShowServiceDetailModal(true);
  };

  const handleServiceDetailClose = () => {
    setShowServiceDetailModal(false);
    setSelectedServiceId(null);
  };

  const loadTimeSlots = async (serviceId: number, date?: string) => {
    setLoadingTimeSlots(true);
    try {
      const params: any = {};
      if (date) {
        // 加载指定日期的时间段
        params.start_date = date;
        params.end_date = date;
      } else {
        // 加载未来30天的时间段
        const today = new Date();
        const futureDate = new Date(today);
        futureDate.setDate(today.getDate() + 30);
        params.start_date = today.toISOString().split('T')[0];
        params.end_date = futureDate.toISOString().split('T')[0];
      }
      const slots = await getServiceTimeSlotsPublic(serviceId, params);
      const slotsArray = Array.isArray(slots) ? slots : [];
      setTimeSlots(slotsArray);
    } catch (err: any) {
            message.error('加载时间段失败');
    } finally {
      setLoadingTimeSlots(false);
    }
  };

  const handleApplyClick = (e: React.MouseEvent, service: Service) => {
    e.stopPropagation(); // 阻止事件冒泡，避免触发服务卡片点击
    
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    
    // 检查是否是自己的服务
    if (service.expert_id === user.id) {
      message.warning('不能申请自己的服务');
      return;
    }
    
    setSelectedServiceForApply(service);
    
    // 如果服务启用了时间段，需要先选择日期
    if (service.has_time_slots) {
      // 设置默认日期为今天
      const today = new Date().toISOString().split('T')[0] as string;
      setSelectedDate(today);
      // 加载今天的时间段
      loadTimeSlots(service.id, today);
    }
    
    setShowApplyModal(true);
  };

  const handleSubmitApplication = async () => {
    if (!selectedServiceForApply || !user) return;
    
    setApplying(true);
    try {
      // 如果服务启用了时间段，必须选择时间段
      if (selectedServiceForApply.has_time_slots) {
        if (!selectedDate) {
          message.error('请选择日期');
          setApplying(false);
          return;
        }
        if (!selectedTimeSlotId) {
          message.error('请选择时间段');
          setApplying(false);
          return;
        }
        
        // 检查选中的时间段是否有活动
        const selectedSlot = timeSlots.find((slot: any) => slot.id === selectedTimeSlotId);
        if (selectedSlot && selectedSlot.has_activity && selectedSlot.activity_id) {
          // 如果有活动，使用活动申请API
          const idempotencyKey = `${user.id}_${selectedSlot.activity_id}_${selectedTimeSlotId}_${Date.now()}`;
          await applyToActivity(selectedSlot.activity_id, {
            idempotency_key: idempotencyKey,
            time_slot_id: selectedTimeSlotId,
            is_multi_participant: true,
            max_participants: 1,
            min_participants: 1,
          });
          message.success('活动申请已提交！');
          setShowApplyModal(false);
          setApplyMessage('');
          setNegotiatedPrice(undefined);
          setIsNegotiateChecked(false);
          setIsFlexible(false);
          setDeadline('');
          setSelectedTimeSlotId(null);
          setSelectedDate('');
          setTimeSlots([]);
          setSelectedServiceForApply(null);
          
          // 重新加载服务列表以更新申请数量
          await loadServices();
          setApplying(false);
          return;
        }
      } else {
        // 如果服务未启用时间段，验证截至日期
        if (!isFlexible && !deadline) {
          message.error('请选择截至日期或选择灵活模式');
          setApplying(false);
          return;
        }
      }

      // 格式化截至日期（仅当服务未启用时间段时）
      let deadlineDate: string | undefined = undefined;
      if (!selectedServiceForApply.has_time_slots && !isFlexible && deadline) {
        // 将日期时间字符串转换为 ISO 格式
        const date = new Date(deadline);
        if (isNaN(date.getTime())) {
          message.error('截至日期格式不正确');
          setApplying(false);
          return;
        }
        deadlineDate = date.toISOString();
      }

      await applyForService(selectedServiceForApply.id, {
        application_message: applyMessage || undefined,
        negotiated_price: isNegotiateChecked && negotiatedPrice ? negotiatedPrice : undefined,
        currency: selectedServiceForApply.currency || 'GBP',
        deadline: deadlineDate,
        is_flexible: isFlexible ? 1 : 0,
        time_slot_id: selectedTimeSlotId || undefined,
      });
      
      // 检查是否自动批准（不议价且选择了时间段）
      const isAutoApproved = !isNegotiateChecked && selectedServiceForApply.has_time_slots && selectedTimeSlotId;
      if (isAutoApproved) {
        message.success('申请已通过，任务已创建！');
      } else {
        message.success('申请已提交，等待任务达人处理');
      }
      
      setShowApplyModal(false);
      setApplyMessage('');
      setNegotiatedPrice(undefined);
      setIsNegotiateChecked(false);
      setIsFlexible(false);
      setDeadline('');
      setSelectedTimeSlotId(null);
      setSelectedDate('');
      setTimeSlots([]);
      setSelectedServiceForApply(null);
      
      // 重新加载服务列表以更新申请数量
      await loadServices();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '提交申请失败');
    } finally {
      setApplying(false);
    }
  };

  if (!isOpen) return null;

  return (
    <>
      <div style={{
        ...MODAL_OVERLAY_STYLE,
        background: 'rgba(0, 0, 0, 0.6)',
        backdropFilter: 'blur(4px)'
      }} onClick={onClose}>
        <div
          style={{
            backgroundColor: 'rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(20px)',
            border: '1px solid rgba(255, 255, 255, 0.2)',
            borderRadius: '16px',
            padding: '24px',
            maxWidth: '800px',
            width: '90%',
            maxHeight: '90vh',
            overflowY: 'auto',
            position: 'relative',
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.2)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <button
            onClick={onClose}
            style={{
              position: 'absolute',
              top: '16px',
              right: '16px',
              background: 'rgba(255, 255, 255, 0.2)',
              backdropFilter: 'blur(10px)',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: 'white',
              width: '32px',
              height: '32px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: '50%',
              transition: 'background 0.2s',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255, 255, 255, 0.3)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)';
            }}
          >
            ×
          </button>

          <h2 style={{ marginBottom: '24px', color: 'white', fontSize: '24px', fontWeight: 600 }}>
            {expertName ? `${expertName} 的服务菜单` : '服务菜单'}
          </h2>

          {loading ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <div style={{ fontSize: '18px', color: 'rgba(255, 255, 255, 0.9)' }}>加载中...</div>
            </div>
          ) : error ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <div style={{ fontSize: '18px', color: '#e53e3e' }}>{error}</div>
            </div>
          ) : services.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <div style={{ fontSize: '18px', color: 'rgba(255, 255, 255, 0.9)' }}>达人准备中，请稍后再来~</div>
            </div>
          ) : (
            <div style={{ display: 'grid', gap: '16px' }}>
              {services.map((service) => (
                <div
                  key={service.id}
                  onClick={() => handleServiceClick(service.id)}
                  style={{
                    border: '1px solid rgba(255, 255, 255, 0.2)',
                    borderRadius: '12px',
                    padding: '20px',
                    cursor: 'pointer',
                    transition: 'all 0.3s ease',
                    background: 'rgba(255, 255, 255, 0.1)',
                    backdropFilter: 'blur(10px)',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.3)';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.2)';
                    e.currentTarget.style.transform = 'translateY(-2px)';
                    e.currentTarget.style.background = 'rgba(255, 255, 255, 0.15)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.2)';
                    e.currentTarget.style.boxShadow = 'none';
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)';
                  }}
                >
                  <div style={{ display: 'flex', gap: '16px', alignItems: 'flex-start' }}>
                    {/* 服务图片 */}
                    {service.images && service.images.length > 0 && (
                      <LazyImage
                        src={service.images[0] ?? ''}
                        alt={service.service_name}
                        style={{
                          width: '120px',
                          height: '120px',
                          objectFit: 'cover',
                          borderRadius: '8px',
                          flexShrink: 0,
                          border: '1px solid rgba(255, 255, 255, 0.2)',
                        }}
                      />
                    )}
                    
                    <div style={{ flex: 1 }}>
                      {/* 服务名称 */}
                      <h3 style={{
                        fontSize: '18px',
                        fontWeight: 600,
                        color: 'white',
                        marginBottom: '8px',
                      }}>
                        {service.service_name}
                      </h3>
                      
                      {/* 服务描述 */}
                      <p style={{
                        fontSize: '14px',
                        color: 'rgba(255, 255, 255, 0.9)',
                        marginBottom: '12px',
                        lineHeight: '1.5',
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden',
                      }}>
                        {service.description}
                      </p>
                      
                      {/* 价格和统计 */}
                      <div style={{ display: 'flex', gap: '16px', alignItems: 'center', flexWrap: 'wrap', marginBottom: '12px' }}>
                        <div style={{
                          fontSize: '20px',
                          fontWeight: 700,
                          color: 'white',
                        }}>
                          {service.currency} {Number(service.base_price).toFixed(2)}
                        </div>
                        
                        <div style={{
                          fontSize: '12px',
                          color: 'rgba(255, 255, 255, 0.8)',
                          display: 'flex',
                          gap: '12px',
                        }}>
                          <span>👁️ {service.view_count} 次浏览</span>
                          <span>📝 {service.application_count} 次申请</span>
                        </div>
                      </div>

                      {/* 申请按钮 */}
                      {service.status === 'active' && (
                        <button
                          onClick={(e) => handleApplyClick(e, service)}
                          style={{
                            padding: '10px 20px',
                            background: 'rgba(255, 255, 255, 0.2)',
                            backdropFilter: 'blur(10px)',
                            color: 'white',
                            border: '1px solid rgba(255, 255, 255, 0.3)',
                            borderRadius: '8px',
                            fontSize: '14px',
                            fontWeight: 600,
                            cursor: 'pointer',
                            transition: 'all 0.2s',
                            width: '100%',
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.transform = 'translateY(-2px)';
                            e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.2)';
                            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.3)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.transform = 'translateY(0)';
                            e.currentTarget.style.boxShadow = 'none';
                            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)';
                          }}
                        >
                          申请服务
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* 服务详情弹窗 */}
      <ServiceDetailModal
        isOpen={showServiceDetailModal}
        onClose={handleServiceDetailClose}
        serviceId={selectedServiceId}
        onApplySuccess={() => {
          handleServiceDetailClose();
          loadServices(); // 重新加载服务列表以更新申请数量
        }}
      />

      {/* 申请服务弹窗 */}
      {showApplyModal && selectedServiceForApply && (
        <div style={MODAL_OVERLAY_STYLE} onClick={() => setShowApplyModal(false)}>
          <div
            style={{
              backgroundColor: '#fff',
              borderRadius: '16px',
              padding: '24px',
              maxWidth: selectedServiceForApply.has_time_slots ? '600px' : '500px',
              width: '100%',
              maxHeight: '90vh',
              overflowY: 'auto',
              position: 'relative',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setShowApplyModal(false)}
              style={{
                position: 'absolute',
                top: '16px',
                right: '16px',
                background: 'none',
                border: 'none',
                fontSize: '24px',
                cursor: 'pointer',
                color: '#666',
                width: '32px',
                height: '32px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                borderRadius: '50%',
                transition: 'background 0.2s',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = '#f0f0f0';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'none';
              }}
            >
              ×
            </button>

            <h2 style={{ marginBottom: '24px', color: '#1a202c', fontSize: '20px', fontWeight: 600 }}>
              申请服务：{selectedServiceForApply.service_name}
            </h2>

            {/* 如果有时间段，显示提示 */}
            {selectedServiceForApply.has_time_slots && (
              <div style={{ 
                marginBottom: '20px', 
                padding: '12px', 
                background: '#e0f2fe', 
                borderRadius: '8px',
                border: '1px solid #bae6fd',
                fontSize: '14px',
                color: '#0369a1',
              }}>
                ⏰ 此服务需要选择时间段，请先选择日期和时间段
              </div>
            )}

            {/* 申请留言 */}
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
                申请留言（可选）
              </label>
              <textarea
                value={applyMessage}
                onChange={(e) => setApplyMessage(e.target.value)}
                placeholder="请输入您的申请留言..."
                maxLength={1000}
                style={{
                  width: '100%',
                  minHeight: '100px',
                  padding: '12px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '14px',
                  resize: 'vertical',
                  fontFamily: 'inherit',
                  outline: 'none',
                  transition: 'border-color 0.2s',
                  boxSizing: 'border-box',
                }}
                onFocus={(e) => {
                  e.currentTarget.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.borderColor = '#e2e8f0';
                }}
              />
              <div style={{ fontSize: 12, color: '#666', textAlign: 'right', marginTop: 4 }}>
                {applyMessage.length}/1000
              </div>
            </div>

            {/* 议价选项 */}
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={isNegotiateChecked}
                  onChange={(e) => {
                    setIsNegotiateChecked(e.target.checked);
                    if (!e.target.checked) {
                      setNegotiatedPrice(undefined);
                    }
                  }}
                />
                <span style={{ color: '#2d3748' }}>我想议价</span>
              </label>
              
              {isNegotiateChecked && (
                <div style={{ marginTop: '12px', marginLeft: '24px' }}>
                  <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
                    期望价格（{selectedServiceForApply.currency}）
                  </label>
                  <input
                    type="number"
                    value={negotiatedPrice || ''}
                    onChange={(e) => {
                      const value = parseFloat(e.target.value);
                      setNegotiatedPrice(isNaN(value) ? undefined : value);
                    }}
                    placeholder={`最低 ${selectedServiceForApply.currency} ${(selectedServiceForApply.base_price * 0.5).toFixed(2)}`}
                    min={selectedServiceForApply.base_price * 0.5}
                    step="0.01"
                    style={{
                      width: '100%',
                      padding: '12px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '8px',
                      fontSize: '14px',
                      fontFamily: 'inherit',
                      outline: 'none',
                      transition: 'border-color 0.2s',
                      boxSizing: 'border-box',
                    }}
                    onFocus={(e) => {
                      e.currentTarget.style.borderColor = '#3b82f6';
                    }}
                    onBlur={(e) => {
                      e.currentTarget.style.borderColor = '#e2e8f0';
                    }}
                  />
                  <div style={{ marginTop: '4px', fontSize: '12px', color: '#718096' }}>
                    最低价格为基础价格的50%（{selectedServiceForApply.currency} {(selectedServiceForApply.base_price * 0.5).toFixed(2)}）
                  </div>
                </div>
              )}
            </div>

            {/* 时间段选择（如果服务启用了时间段） */}
            {selectedServiceForApply.has_time_slots && (
              <div style={{ marginBottom: '20px' }}>
                <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
                  选择日期 *
                </label>
                <input
                  type="date"
                  value={selectedDate}
                  onChange={(e) => {
                    const date = e.target.value;
                    setSelectedDate(date);
                    setSelectedTimeSlotId(null);
                    if (date && selectedServiceForApply.id) {
                      loadTimeSlots(selectedServiceForApply.id, date);
                    }
                  }}
                  min={new Date().toISOString().split('T')[0]}
                  style={{
                    width: '100%',
                    padding: '12px',
                    border: '1px solid #e2e8f0',
                    borderRadius: '8px',
                    fontSize: '14px',
                    fontFamily: 'inherit',
                    outline: 'none',
                    transition: 'border-color 0.2s',
                    boxSizing: 'border-box',
                    marginBottom: '12px',
                  }}
                />
                
                {selectedDate && (
                  <>
                    <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
                      选择时间段 *
                    </label>
                    {loadingTimeSlots ? (
                      <div style={{ padding: '20px', textAlign: 'center', color: '#718096' }}>
                        加载时间段中...
                      </div>
                    ) : timeSlots.length === 0 ? (
                      <div style={{ padding: '20px', textAlign: 'center', color: '#e53e3e' }}>
                        该日期暂无可用时间段
                      </div>
                    ) : (
                      <div style={{ 
                        display: 'grid', 
                        gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', 
                        gap: '12px',
                        maxHeight: '200px',
                        overflowY: 'auto',
                      }}>
                        {timeSlots
                          .filter((slot: any) => {
                            // 确保slot_date格式匹配（可能是YYYY-MM-DD或带时间）
                            const slotDateStr = slot.slot_date ? slot.slot_date.split('T')[0] : '';
                            const selectedDateStr = selectedDate ? selectedDate.split('T')[0] : '';
                            const isDateMatch = slotDateStr === selectedDateStr;
                            const isAvailable = slot.is_available !== false; // 允许undefined/null
                            return isDateMatch && isAvailable;
                          })
                          .map((slot) => {
                            const isFull = slot.current_participants >= slot.max_participants;
                            const isExpired = slot.is_expired === true; // 时间段已过期
                            const isDisabled = isFull || isExpired; // 已满或已过期都不可选
                            const isSelected = selectedTimeSlotId === slot.id;
                            
                            // 使用UTC时间转换为英国时间显示
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
                              <button
                                key={slot.id}
                                onClick={() => !isDisabled && setSelectedTimeSlotId(slot.id)}
                                disabled={isDisabled}
                                style={{
                                  padding: '12px',
                                  border: `2px solid ${isSelected ? '#3b82f6' : isDisabled ? '#e2e8f0' : '#cbd5e0'}`,
                                  borderRadius: '8px',
                                  background: isSelected ? '#eff6ff' : isDisabled ? '#f7fafc' : '#fff',
                                  cursor: isDisabled ? 'not-allowed' : 'pointer',
                                  textAlign: 'left',
                                  transition: 'all 0.2s',
                                  opacity: isDisabled ? 0.6 : 1,
                                }}
                                onMouseEnter={(e) => {
                                  if (!isDisabled) {
                                    e.currentTarget.style.borderColor = '#3b82f6';
                                    e.currentTarget.style.background = '#eff6ff';
                                  }
                                }}
                                onMouseLeave={(e) => {
                                  if (!isSelected) {
                                    e.currentTarget.style.borderColor = isDisabled ? '#e2e8f0' : '#cbd5e0';
                                    e.currentTarget.style.background = isDisabled ? '#f7fafc' : '#fff';
                                  }
                                }}
                              >
                                <div style={{ fontWeight: 600, color: isExpired ? '#9ca3af' : '#1a202c', marginBottom: '4px' }}>
                                  {startTimeUK} - {endTimeUK}
                                  {isExpired && <span style={{ marginLeft: '8px', fontSize: '12px', color: '#ef4444' }}>(已过期)</span>}
                                </div>
                                <div style={{ fontSize: '12px', color: '#718096' }}>
                                  {selectedServiceForApply.currency} {slot.price_per_participant.toFixed(2)} / 人
                                </div>
                                <div style={{ fontSize: '12px', color: isFull ? '#e53e3e' : '#48bb78', marginTop: '4px' }}>
                                  {isFull ? '已满' : `${slot.current_participants}/${slot.max_participants} 人`}
                                </div>
                              </button>
                            );
                          })}
                      </div>
                    )}
                  </>
                )}
              </div>
            )}

            {/* 截至日期或灵活选项（如果服务未启用时间段） */}
            {!selectedServiceForApply.has_time_slots && (
              <div style={{ marginBottom: '20px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', marginBottom: '12px' }}>
                  <input
                    type="checkbox"
                    checked={isFlexible}
                    onChange={(e) => {
                      setIsFlexible(e.target.checked);
                      if (e.target.checked) {
                        setDeadline('');
                      }
                    }}
                  />
                  <span style={{ color: '#2d3748', fontWeight: 500 }}>灵活（无截至日期）</span>
                </label>
                
                {!isFlexible && (
                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
                      任务截至日期
                    </label>
                    <input
                      type="datetime-local"
                      value={deadline}
                      onChange={(e) => setDeadline(e.target.value)}
                      min={new Date().toISOString().slice(0, 16)}
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #e2e8f0',
                        borderRadius: '8px',
                        fontSize: '14px',
                        fontFamily: 'inherit',
                        outline: 'none',
                        transition: 'border-color 0.2s',
                        boxSizing: 'border-box',
                      }}
                      onFocus={(e) => {
                        e.currentTarget.style.borderColor = '#3b82f6';
                      }}
                      onBlur={(e) => {
                        e.currentTarget.style.borderColor = '#e2e8f0';
                      }}
                    />
                    <div style={{ marginTop: '4px', fontSize: '12px', color: '#718096' }}>
                      请选择任务的截至日期和时间
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* 提交按钮 */}
            <div style={{ display: 'flex', gap: '12px' }}>
              <button
                onClick={handleSubmitApplication}
                disabled={applying || (isNegotiateChecked && (!negotiatedPrice || negotiatedPrice < selectedServiceForApply.base_price * 0.5)) || (selectedServiceForApply.has_time_slots ? !selectedTimeSlotId : (!isFlexible && !deadline))}
                style={{
                  flex: 1,
                  padding: '12px',
                  background: applying
                    ? '#cbd5e0'
                    : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '16px',
                  fontWeight: 600,
                  cursor: applying ? 'not-allowed' : 'pointer',
                  transition: 'all 0.2s',
                }}
              >
                {applying ? '提交中...' : '提交申请'}
              </button>
              <button
                onClick={() => setShowApplyModal(false)}
                style={{
                  padding: '12px 24px',
                  background: '#f7fafc',
                  color: '#2d3748',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '16px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#edf2f7';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#f7fafc';
                }}
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          loadCurrentUser();
        }}
      />
    </>
  );
};

export default ServiceListModal;

