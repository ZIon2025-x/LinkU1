/**
 * 服务详情弹窗组件
 * 显示任务达人服务的详细信息，支持申请服务
 */

import React, { useState, useEffect } from 'react';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { getTaskExpertServiceDetail, applyForService, fetchCurrentUser, getServiceTimeSlotsPublic } from '../api';
import LoginModal from './LoginModal';
import { MODAL_OVERLAY_STYLE } from './TaskDetailModal.styles';

interface ServiceDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  serviceId: number | null;
  onApplySuccess?: () => void;
}

interface ServiceDetail {
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
  has_time_slots?: boolean;
  time_slot_duration_minutes?: number;
  time_slot_start_time?: string;
  time_slot_end_time?: string;
  participants_per_slot?: number;
}

interface TimeSlot {
  id: number;
  service_id: number;
  slot_date: string;
  start_time: string;
  end_time: string;
  price_per_participant: number;
  max_participants: number;
  current_participants: number;
  is_available: boolean;
}

interface ExpertInfo {
  id: string;
  expert_name?: string;
  bio?: string;
  avatar?: string;
  rating: number;
  total_services: number;
  completed_tasks: number;
}

const ServiceDetailModal: React.FC<ServiceDetailModalProps> = ({
  isOpen,
  onClose,
  serviceId,
  onApplySuccess,
}) => {
  const { t } = useLanguage();
  const [service, setService] = useState<ServiceDetail | null>(null);
  const [expert, setExpert] = useState<ExpertInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [applyMessage, setApplyMessage] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState<number | undefined>();
  const [isNegotiateChecked, setIsNegotiateChecked] = useState(false);
  const [isFlexible, setIsFlexible] = useState(false);
  const [deadline, setDeadline] = useState<string>('');
  const [applying, setApplying] = useState(false);
  const [enlargedImage, setEnlargedImage] = useState<string | null>(null);
  // 时间段相关状态
  const [timeSlots, setTimeSlots] = useState<TimeSlot[]>([]);
  const [loadingTimeSlots, setLoadingTimeSlots] = useState(false);
  const [selectedTimeSlotId, setSelectedTimeSlotId] = useState<number | null>(null);
  const [selectedDate, setSelectedDate] = useState<string>('');

  // 加载服务详情
  useEffect(() => {
    if (isOpen && serviceId) {
      loadServiceDetail();
      loadCurrentUser();
    } else {
      // 关闭时重置状态
      setService(null);
      setExpert(null);
      setError('');
      setApplyMessage('');
      setNegotiatedPrice(undefined);
      setIsNegotiateChecked(false);
      setIsFlexible(false);
      setDeadline('');
      setTimeSlots([]);
      setSelectedTimeSlotId(null);
      setSelectedDate('');
    }
  }, [isOpen, serviceId]);

  const loadServiceDetail = async () => {
    if (!serviceId) return;
    
    setLoading(true);
    setError('');
    try {
      const data = await getTaskExpertServiceDetail(serviceId);
      setService(data);
      
      // 如果服务启用了时间段，加载时间段列表
      if (data.has_time_slots) {
        loadTimeSlots(data.id);
      }
      
      // 加载任务达人信息
      if (data.expert_id) {
        try {
          const expertData = await fetch(`/api/task-experts/${data.expert_id}`).then(res => res.json());
          setExpert(expertData);
        } catch (e) {
          console.error('Failed to load expert info:', e);
        }
      }
    } catch (err: any) {
      setError(err.response?.data?.detail || '加载服务详情失败');
      message.error(err.response?.data?.detail || '加载服务详情失败');
    } finally {
      setLoading(false);
    }
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
      setTimeSlots(Array.isArray(slots) ? slots : []);
    } catch (err: any) {
      console.error('加载时间段失败:', err);
      message.error('加载时间段失败');
    } finally {
      setLoadingTimeSlots(false);
    }
  };

  const loadCurrentUser = async () => {
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
    } catch (err) {
      setUser(null);
    }
  };

  const handleApplyClick = () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    
    // 检查是否是自己的服务
    if (service && expert && expert.id === user.id) {
      message.warning('不能申请自己的服务');
      return;
    }
    
    // 如果服务启用了时间段，需要先选择日期
    if (service?.has_time_slots) {
      // 设置默认日期为今天
      const today = new Date().toISOString().split('T')[0];
      setSelectedDate(today);
      // 加载今天的时间段
      if (service.id) {
        loadTimeSlots(service.id, today);
      }
    }
    
    setShowApplyModal(true);
  };

  const handleSubmitApplication = async () => {
    if (!serviceId || !user) return;
    
    // 验证截至日期
    if (!isFlexible && !deadline) {
      message.error('请选择截至日期或选择灵活模式');
      return;
    }

    setApplying(true);
    try {
      // 格式化截至日期
      let deadlineDate: string | undefined = undefined;
      if (!isFlexible && deadline) {
        // 将日期时间字符串转换为 ISO 格式
        const date = new Date(deadline);
        if (isNaN(date.getTime())) {
          message.error('截至日期格式不正确');
          setApplying(false);
          return;
        }
        deadlineDate = date.toISOString();
      }

      // 如果服务启用了时间段，必须选择时间段
      if (service?.has_time_slots && !selectedTimeSlotId) {
        message.error('请选择时间段');
        setApplying(false);
        return;
      }

      await applyForService(serviceId, {
        application_message: applyMessage || undefined,
        negotiated_price: isNegotiateChecked && negotiatedPrice ? negotiatedPrice : undefined,
        currency: service?.currency || 'GBP',
        deadline: deadlineDate,
        is_flexible: isFlexible ? 1 : 0,
        time_slot_id: selectedTimeSlotId || undefined,
      });
      
      message.success('申请已提交，等待任务达人处理');
      setShowApplyModal(false);
      setApplyMessage('');
      setNegotiatedPrice(undefined);
      setIsNegotiateChecked(false);
      setIsFlexible(false);
      setDeadline('');
      setSelectedTimeSlotId(null);
      setSelectedDate('');
      setTimeSlots([]);
      
      // 重新加载服务详情（更新申请次数）
      await loadServiceDetail();
      
      if (onApplySuccess) {
        onApplySuccess();
      }
    } catch (err: any) {
      message.error(err.response?.data?.detail || '提交申请失败');
    } finally {
      setApplying(false);
    }
  };

  if (!isOpen) return null;

  return (
    <>
      <div style={MODAL_OVERLAY_STYLE} onClick={onClose}>
        <div
          style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '24px',
            maxWidth: '800px',
            width: '100%',
            maxHeight: '90vh',
            overflowY: 'auto',
            position: 'relative',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          {/* 关闭按钮 */}
          <button
            onClick={onClose}
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

          {loading ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <div>加载中...</div>
            </div>
          ) : error ? (
            <div style={{ textAlign: 'center', padding: '40px', color: '#f56565' }}>
              {error}
            </div>
          ) : service ? (
            <>
              {/* 服务名称 */}
              <h2 style={{ marginBottom: '16px', color: '#1a202c', fontSize: '24px', fontWeight: 600 }}>
                {service.service_name}
              </h2>

              {/* 任务达人信息 */}
              {expert && (
                <div style={{ marginBottom: '24px', padding: '16px', background: '#f7fafc', borderRadius: '8px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    {expert.avatar && (
                      <img
                        src={expert.avatar}
                        alt={expert.expert_name || '任务达人'}
                        style={{ width: '48px', height: '48px', borderRadius: '50%', objectFit: 'cover' }}
                      />
                    )}
                    <div>
                      <div style={{ fontWeight: 600, color: '#1a202c' }}>
                        {expert.expert_name || '任务达人'}
                      </div>
                      <div style={{ fontSize: '14px', color: '#718096' }}>
                        评分: {expert.rating.toFixed(1)} | 服务数: {expert.total_services} | 完成任务: {expert.completed_tasks}
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* 服务图片 */}
              {service.images && service.images.length > 0 && (
                <div style={{ marginBottom: '24px' }}>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: '12px' }}>
                    {service.images.map((img, index) => (
                      <img
                        key={index}
                        src={img}
                        alt={`${service.service_name} ${index + 1}`}
                        style={{
                          width: '100%',
                          height: '150px',
                          objectFit: 'cover',
                          borderRadius: '8px',
                          cursor: 'pointer',
                        }}
                        onClick={() => setEnlargedImage(img)}
                      />
                    ))}
                  </div>
                </div>
              )}

              {/* 服务描述 */}
              <div style={{ marginBottom: '24px' }}>
                <h3 style={{ marginBottom: '12px', color: '#2d3748', fontSize: '18px', fontWeight: 600 }}>
                  服务描述
                </h3>
                <div style={{ color: '#4a5568', lineHeight: '1.6', whiteSpace: 'pre-wrap' }}>
                  {service.description}
                </div>
              </div>

              {/* 价格信息 */}
              <div style={{ marginBottom: '24px', padding: '16px', background: '#edf2f7', borderRadius: '8px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: '14px', color: '#718096', marginBottom: '4px' }}>基础价格</div>
                    <div style={{ fontSize: '24px', fontWeight: 600, color: '#1a202c' }}>
                      {service.currency} {service.base_price.toFixed(2)}
                    </div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '14px', color: '#718096', marginBottom: '4px' }}>申请次数</div>
                    <div style={{ fontSize: '18px', fontWeight: 600, color: '#2d3748' }}>
                      {service.application_count}
                    </div>
                  </div>
                </div>
              </div>

              {/* 申请按钮 */}
              {service.status === 'active' && (
                <button
                  onClick={handleApplyClick}
                  style={{
                    width: '100%',
                    padding: '14px',
                    background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    fontSize: '16px',
                    fontWeight: 600,
                    cursor: 'pointer',
                    transition: 'all 0.2s',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'translateY(-2px)';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.4)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = 'none';
                  }}
                >
                  申请服务
                </button>
              )}

              {service.status !== 'active' && (
                <div style={{ padding: '12px', background: '#fed7d7', color: '#c53030', borderRadius: '8px', textAlign: 'center' }}>
                  该服务已下架
                </div>
              )}
            </>
          ) : null}
        </div>
      </div>

      {/* 申请服务弹窗 */}
      {showApplyModal && service && (
        <div style={MODAL_OVERLAY_STYLE} onClick={() => setShowApplyModal(false)}>
          <div
            style={{
              backgroundColor: '#fff',
              borderRadius: '16px',
              padding: '24px',
              maxWidth: '500px',
              width: '100%',
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
              }}
            >
              ×
            </button>

            <h2 style={{ marginBottom: '24px', color: '#1a202c', fontSize: '20px', fontWeight: 600 }}>
              申请服务：{service.service_name}
            </h2>

            {/* 申请留言 */}
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
                申请留言（可选）
              </label>
              <textarea
                value={applyMessage}
                onChange={(e) => setApplyMessage(e.target.value)}
                placeholder="请输入您的申请留言..."
                style={{
                  width: '100%',
                  minHeight: '100px',
                  padding: '12px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '14px',
                  resize: 'vertical',
                }}
              />
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
                    期望价格（{service.currency}）
                  </label>
                  <input
                    type="number"
                    value={negotiatedPrice || ''}
                    onChange={(e) => {
                      const value = parseFloat(e.target.value);
                      setNegotiatedPrice(isNaN(value) ? undefined : value);
                    }}
                    placeholder={`最低 ${service.currency} ${(service.base_price * 0.5).toFixed(2)}`}
                    min={service.base_price * 0.5}
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
                    最低价格为基础价格的50%（{service.currency} {(service.base_price * 0.5).toFixed(2)}）
                  </div>
                </div>
              )}
            </div>

            {/* 时间段选择（如果服务启用了时间段） */}
            {service.has_time_slots && (
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
                    if (date && service.id) {
                      loadTimeSlots(service.id, date);
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
                          .filter(slot => slot.slot_date === selectedDate && slot.is_available)
                          .map((slot) => {
                            const isFull = slot.current_participants >= slot.max_participants;
                            const isSelected = selectedTimeSlotId === slot.id;
                            return (
                              <button
                                key={slot.id}
                                onClick={() => !isFull && setSelectedTimeSlotId(slot.id)}
                                disabled={isFull}
                                style={{
                                  padding: '12px',
                                  border: `2px solid ${isSelected ? '#3b82f6' : isFull ? '#e2e8f0' : '#cbd5e0'}`,
                                  borderRadius: '8px',
                                  background: isSelected ? '#eff6ff' : isFull ? '#f7fafc' : '#fff',
                                  cursor: isFull ? 'not-allowed' : 'pointer',
                                  textAlign: 'left',
                                  transition: 'all 0.2s',
                                  opacity: isFull ? 0.6 : 1,
                                }}
                                onMouseEnter={(e) => {
                                  if (!isFull) {
                                    e.currentTarget.style.borderColor = '#3b82f6';
                                    e.currentTarget.style.background = '#eff6ff';
                                  }
                                }}
                                onMouseLeave={(e) => {
                                  if (!isSelected) {
                                    e.currentTarget.style.borderColor = isFull ? '#e2e8f0' : '#cbd5e0';
                                    e.currentTarget.style.background = isFull ? '#f7fafc' : '#fff';
                                  }
                                }}
                              >
                                <div style={{ fontWeight: 600, color: '#1a202c', marginBottom: '4px' }}>
                                  {slot.start_time.substring(0, 5)} - {slot.end_time.substring(0, 5)}
                                </div>
                                <div style={{ fontSize: '12px', color: '#718096' }}>
                                  {service.currency} {slot.price_per_participant.toFixed(2)} / 人
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
            {!service.has_time_slots && (
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
                disabled={applying || (isNegotiateChecked && (!negotiatedPrice || negotiatedPrice < service.base_price * 0.5)) || (service.has_time_slots ? !selectedTimeSlotId : (!isFlexible && !deadline))}
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
                }}
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 图片放大 */}
      {enlargedImage && (
        <div
          style={{
            ...MODAL_OVERLAY_STYLE,
            backgroundColor: 'rgba(0, 0, 0, 0.9)',
          }}
          onClick={() => setEnlargedImage(null)}
        >
          <img
            src={enlargedImage}
            alt="放大图片"
            style={{
              maxWidth: '90%',
              maxHeight: '90%',
              objectFit: 'contain',
            }}
            onClick={(e) => e.stopPropagation()}
          />
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

export default ServiceDetailModal;

