import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { TASK_TYPES, CITIES } from './Tasks';
import api, { getPublicSystemSettings } from '../api';
import { useLanguage } from '../contexts/LanguageContext';

// 移动端检测函数
const isMobileDevice = () => {
  const isSmallScreen = window.innerWidth <= 768;
  const isMobileUA = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
  
  return isSmallScreen || (isMobileUA && isTouchDevice);
};

const PublishTask: React.FC = () => {
  const { t } = useLanguage();
  const [form, setForm] = useState({
    title: '',
    description: '',
    deadline: '',
    reward: '',
    location: CITIES[0],
    task_type: TASK_TYPES[0],
    is_public: 1, // 1=公开, 0=仅自己可见
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [isMobile, setIsMobile] = useState(false);
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_price_threshold: 10.0,
    super_vip_price_threshold: 50.0,
    vip_enabled: true,
    super_vip_enabled: true
  });
  const navigate = useNavigate();

  // 移动端检测
  useEffect(() => {
    const checkMobile = () => {
      const mobile = isMobileDevice();
      setIsMobile(mobile);
    };

    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // 加载系统设置
  useEffect(() => {
    const loadSystemSettings = async () => {
      try {
        const settings = await getPublicSystemSettings();
        console.log('任务发布页面系统设置加载成功:', settings);
        console.log('VIP阈值:', settings.vip_price_threshold);
        console.log('超级VIP阈值:', settings.super_vip_price_threshold);
        console.log('VIP启用:', settings.vip_enabled);
        console.log('超级VIP启用:', settings.super_vip_enabled);
        setSystemSettings(settings);
      } catch (error) {
        console.error('加载系统设置失败:', error);
        console.error('错误详情:', error);
      }
    };

    loadSystemSettings();
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  // 获取任务等级提示
  const getTaskLevelHint = (reward: number) => {
    if (!reward || reward <= 0) return '';
    
    console.log('任务等级提示调试:', {
      reward,
      vipThreshold: systemSettings.vip_price_threshold,
      superVipThreshold: systemSettings.super_vip_price_threshold,
      vipEnabled: systemSettings.vip_enabled,
      superVipEnabled: systemSettings.super_vip_enabled,
      systemSettings: systemSettings
    });
    
    if (systemSettings.super_vip_enabled && reward >= systemSettings.super_vip_price_threshold) {
      return `💰 超级任务 (≥${systemSettings.super_vip_price_threshold}元)`;
    } else if (systemSettings.vip_enabled && reward >= systemSettings.vip_price_threshold) {
      return `⭐ VIP任务 (≥${systemSettings.vip_price_threshold}元)`;
    } else {
      return `📝 普通任务 (<${systemSettings.vip_price_threshold}元)`;
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    if (!form.title || !form.description || !form.deadline || !form.reward) {
      setError(t('publishTask.fillAllFields'));
      return;
    }
    setLoading(true);
    try {
      await api.post('/api/tasks', {
        ...form,
        reward: parseFloat(form.reward),
        deadline: new Date(form.deadline).toISOString(),
        is_public: form.is_public,
      });
      setSuccess(t('publishTask.publishSuccess'));
      setTimeout(() => navigate('/my-tasks'), 1500);
    } catch (err: any) {
      let errorMsg = t('publishTask.publishError');
      if (err?.response?.data?.detail) {
        if (typeof err.response.data.detail === 'string') {
          errorMsg = err.response.data.detail;
        } else if (Array.isArray(err.response.data.detail)) {
          errorMsg = err.response.data.detail.map((item: any) => item.msg).join('；');
        } else if (typeof err.response.data.detail === 'object' && err.response.data.detail.msg) {
          errorMsg = err.response.data.detail.msg;
        } else {
          errorMsg = JSON.stringify(err.response.data.detail);
        }
      } else if (err?.message) {
        errorMsg = err.message;
      }
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: isMobile 
        ? 'linear-gradient(180deg, #f8fafc 0%, #e2e8f0 100%)'
        : 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: isMobile ? '0' : '20px',
      // 防止移动端回弹
      overscrollBehavior: 'contain',
      WebkitOverflowScrolling: 'touch'
    }}>
      {/* SEO优化：H1标签，可见但样式简洁 */}
      <h1 style={{
        position: 'absolute',
        top: '-100px',
        left: '-100px',
        width: '1px',
        height: '1px',
        padding: '0',
        margin: '0',
        overflow: 'hidden',
        clip: 'rect(0, 0, 0, 0)',
        whiteSpace: 'nowrap',
        border: '0',
        fontSize: '1px',
        color: 'transparent',
        background: 'transparent'
      }}>
        发布任务
      </h1>
      <div style={{
        maxWidth: isMobile ? '100%' : '700px',
        margin: '0 auto',
        background: '#fff',
        borderRadius: isMobile ? '0' : '24px',
        boxShadow: isMobile ? 'none' : '0 25px 50px rgba(0,0,0,0.15)',
        padding: isMobile ? '24px 20px' : '40px',
        position: 'relative',
        overflow: 'visible',
        minHeight: isMobile ? '100vh' : 'auto'
      }}>
        {/* 移动端顶部装饰条 */}
        {isMobile && (
          <div style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            height: '4px',
            background: 'linear-gradient(90deg, #667eea, #764ba2)',
            borderRadius: '0 0 8px 8px'
          }} />
        )}
        
        {/* 桌面端装饰性背景 */}
        {!isMobile && (
          <>
            <div style={{
              position: 'absolute',
              top: '-60px',
              right: '-60px',
              width: '240px',
              height: '240px',
              background: 'linear-gradient(45deg, #667eea, #764ba2)',
              borderRadius: '50%',
              opacity: 0.08
            }} />
            <div style={{
              position: 'absolute',
              bottom: '-40px',
              left: '-40px',
              width: '180px',
              height: '180px',
              background: 'linear-gradient(45deg, #764ba2, #667eea)',
              borderRadius: '50%',
              opacity: 0.08
            }} />
          </>
        )}
        
        {/* 标题区域 */}
        <div style={{
          textAlign: 'center',
          marginBottom: isMobile ? '20px' : '30px',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{
            fontSize: isMobile ? '36px' : '48px',
            marginBottom: '16px'
          }}>📝</div>
          <h2 style={{
            fontSize: isMobile ? '24px' : '32px',
            fontWeight: '800',
            marginBottom: '8px',
            background: 'linear-gradient(135deg, #667eea, #764ba2)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            letterSpacing: '1px'
          }}>{t('publishTask.title')}</h2>
          <p style={{
            color: '#6b7280',
            fontSize: isMobile ? '14px' : '16px',
            margin: 0
          }}>{t('publishTask.subtitle')}</p>
        </div>
        <form onSubmit={handleSubmit} style={{ 
          position: 'relative', 
          zIndex: 1,
          display: 'flex',
          flexDirection: 'column',
          gap: isMobile ? '24px' : '32px'
        }}>
          {/* 任务类型和城市选择 */}
          <div style={{
            display: 'flex', 
            gap: isMobile ? '12px' : '20px', 
            flexDirection: 'row'
          }}>
            <div style={{
              flex: 1,
              background: '#f8fafc',
              padding: isMobile ? '20px 16px' : '24px 20px',
              borderRadius: '16px',
              border: '2px solid #e2e8f0',
              transition: 'all 0.3s ease'
            }}>
              <label style={{
                fontWeight: '700', 
                marginBottom: '12px', 
                display: 'block',
                color: '#1f2937',
                fontSize: isMobile ? '15px' : '16px'
              }}>{t('publishTask.taskType')}</label>
              <select 
                name="task_type" 
                value={form.task_type} 
                onChange={handleChange} 
                style={{
                  padding: isMobile ? '16px 18px' : '14px 16px', 
                  borderRadius: '12px', 
                  border: '2px solid #e2e8f0', 
                  width: '100%', 
                  fontSize: isMobile ? '16px' : '16px',
                  outline: 'none', 
                  transition: 'all 0.3s ease',
                  background: '#fff',
                  cursor: 'pointer',
                  minHeight: isMobile ? '52px' : 'auto',
                  fontWeight: '500',
                  color: '#374151',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#667eea';
                  e.target.style.boxShadow = '0 0 0 3px rgba(102, 126, 234, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
                }}
              >
                {TASK_TYPES.map((type: string) => <option key={type} value={type}>{t(`publishTask.taskTypes.${type}`)}</option>)}
              </select>
            </div>
            <div style={{
              flex: 1,
              background: '#f8fafc',
              padding: isMobile ? '20px 16px' : '24px 20px',
              borderRadius: '16px',
              border: '2px solid #e2e8f0',
              transition: 'all 0.3s ease'
            }}>
              <label style={{
                fontWeight: '700', 
                marginBottom: '12px', 
                display: 'block',
                color: '#1f2937',
                fontSize: isMobile ? '15px' : '16px'
              }}>{t('publishTask.city')}</label>
              <select 
                name="location" 
                value={form.location} 
                onChange={handleChange} 
                style={{
                  padding: isMobile ? '16px 18px' : '14px 16px', 
                  borderRadius: '12px', 
                  border: '2px solid #e2e8f0', 
                  width: '100%', 
                  fontSize: isMobile ? '16px' : '16px',
                  outline: 'none', 
                  transition: 'all 0.3s ease',
                  background: '#fff',
                  cursor: 'pointer',
                  minHeight: isMobile ? '52px' : 'auto',
                  fontWeight: '500',
                  color: '#374151',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#667eea';
                  e.target.style.boxShadow = '0 0 0 3px rgba(102, 126, 234, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
                }}
              >
                {CITIES.map((city: string) => <option key={city} value={city}>{t(`publishTask.cities.${city}`)}</option>)}
              </select>
            </div>
          </div>
          <div style={{marginBottom: '24px'}}>
            <label style={{
              fontWeight: '600', 
              marginBottom: '12px', 
              display: 'block',
              color: '#374151',
              fontSize: '14px'
            }}>{t('publishTask.visibilitySettings')}</label>
            <div style={{
              display: 'flex', 
              gap: '24px', 
              alignItems: 'center',
              background: '#f8fafc',
              padding: '16px',
              borderRadius: '12px',
              border: '2px solid #e5e7eb'
            }}>
              <label style={{
                display: 'flex', 
                alignItems: 'center', 
                gap: '12px', 
                cursor: 'pointer',
                padding: '8px 16px',
                borderRadius: '8px',
                background: form.is_public === 1 ? '#667eea' : 'transparent',
                color: form.is_public === 1 ? '#fff' : '#374151',
                transition: 'all 0.3s ease'
              }}>
                <input 
                  type="radio" 
                  name="is_public" 
                  value="1" 
                  checked={form.is_public === 1} 
                  onChange={(e) => setForm({...form, is_public: parseInt(e.target.value)})}
                  style={{width: '18px', height: '18px', accentColor: '#667eea'}}
                />
                <span style={{fontWeight: '500'}}>{t('publishTask.publicDisplay')}</span>
              </label>
              <label style={{
                display: 'flex', 
                alignItems: 'center', 
                gap: '12px', 
                cursor: 'pointer',
                padding: '8px 16px',
                borderRadius: '8px',
                background: form.is_public === 0 ? '#667eea' : 'transparent',
                color: form.is_public === 0 ? '#fff' : '#374151',
                transition: 'all 0.3s ease'
              }}>
                <input 
                  type="radio" 
                  name="is_public" 
                  value="0" 
                  checked={form.is_public === 0} 
                  onChange={(e) => setForm({...form, is_public: parseInt(e.target.value)})}
                  style={{width: '18px', height: '18px', accentColor: '#667eea'}}
                />
                <span style={{fontWeight: '500'}}>{t('publishTask.privateOnly')}</span>
              </label>
            </div>
            <div style={{
              fontSize: '13px', 
              color: '#6b7280', 
              marginTop: '8px',
              padding: '8px 12px',
              background: '#f1f5f9',
              borderRadius: '8px'
            }}>
              {form.is_public === 1 ? t('publishTask.publicDescription') : t('publishTask.privateDescription')}
            </div>
          </div>
          {/* 标题输入 */}
          <div style={{
            background: '#f8fafc',
            padding: isMobile ? '24px 20px' : '28px 24px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            overflow: 'hidden'
          }}>
            <label style={{
              fontWeight: '700', 
              marginBottom: '12px', 
              display: 'block',
              color: '#1f2937',
              fontSize: isMobile ? '15px' : '16px'
            }}>{t('publishTask.titleLabel')}</label>
            <input 
              name="title" 
              value={form.title} 
              onChange={handleChange} 
              style={{
                padding: isMobile ? '18px 20px' : '16px 18px', 
                borderRadius: '12px', 
                border: '2px solid #e2e8f0', 
                width: '80%',
                maxWidth: '80%',
                margin: '0 auto',
                boxSizing: 'border-box',
                fontSize: isMobile ? '16px' : '16px',
                outline: 'none', 
                transition: 'all 0.3s ease',
                background: '#fff',
                minHeight: isMobile ? '56px' : 'auto',
                fontWeight: '500',
                color: '#374151',
                boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
              }} 
              onFocus={(e) => {
                e.target.style.borderColor = '#667eea';
                e.target.style.boxShadow = '0 0 0 3px rgba(102, 126, 234, 0.1)';
              }}
              onBlur={(e) => {
                e.target.style.borderColor = '#e2e8f0';
                e.target.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
              }}
              maxLength={50} 
              required 
              placeholder={t('publishTask.titlePlaceholder')} 
            />
            <div style={{
              fontSize: '12px',
              color: '#6b7280',
              marginTop: '4px',
              textAlign: 'right'
            }}>
              {form.title.length}/50
            </div>
          </div>
          {/* 描述输入 */}
          <div style={{
            background: '#f8fafc',
            padding: isMobile ? '24px 20px' : '28px 24px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            overflow: 'hidden'
          }}>
            <label style={{
              fontWeight: '700', 
              marginBottom: '12px', 
              display: 'block',
              color: '#1f2937',
              fontSize: isMobile ? '15px' : '16px'
            }}>{t('publishTask.descriptionLabel')}</label>
            <textarea 
              name="description" 
              value={form.description} 
              onChange={handleChange} 
              style={{
                padding: isMobile ? '18px 20px' : '16px 18px', 
                borderRadius: '12px', 
                border: '2px solid #e2e8f0', 
                width: '80%',
                maxWidth: '80%',
                margin: '0 auto',
                boxSizing: 'border-box',
                minHeight: isMobile ? '120px' : '140px', 
                fontSize: isMobile ? '16px' : '16px',
                outline: 'none', 
                transition: 'all 0.3s ease',
                background: '#fff',
                resize: 'vertical',
                fontWeight: '500',
                color: '#374151',
                boxShadow: '0 2px 4px rgba(0,0,0,0.05)',
                lineHeight: '1.5'
              }} 
              onFocus={(e) => {
                e.target.style.borderColor = '#667eea';
                e.target.style.boxShadow = '0 0 0 3px rgba(102, 126, 234, 0.1)';
              }}
              onBlur={(e) => {
                e.target.style.borderColor = '#e2e8f0';
                e.target.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
              }}
              maxLength={500} 
              required 
              placeholder={t('publishTask.descriptionPlaceholder')} 
            />
            <div style={{
              fontSize: '12px',
              color: '#6b7280',
              marginTop: '4px',
              textAlign: 'right'
            }}>
              {form.description.length}/500
            </div>
          </div>
          {/* 截止日期和金额 */}
          <div style={{
            display: 'flex', 
            gap: isMobile ? '16px' : '20px', 
            flexDirection: isMobile ? 'column' : 'row'
          }}>
            <div style={{
              flex: 1,
              background: '#f8fafc',
              padding: isMobile ? '20px 16px' : '24px 20px',
              borderRadius: '16px',
              border: '2px solid #e2e8f0',
              transition: 'all 0.3s ease'
            }}>
              <label style={{
                fontWeight: '700', 
                marginBottom: '12px', 
                display: 'block',
                color: '#1f2937',
                fontSize: isMobile ? '15px' : '16px'
              }}>{t('publishTask.deadlineLabel')}</label>
              <input 
                name="deadline" 
                type="datetime-local" 
                value={form.deadline} 
                onChange={handleChange} 
                style={{
                  padding: isMobile ? '16px 18px' : '14px 16px', 
                  borderRadius: '12px', 
                  border: '2px solid #e2e8f0', 
                  width: '80%', 
                  maxWidth: '80%',
                  margin: '0 auto',
                  boxSizing: 'border-box',
                  fontSize: isMobile ? '16px' : '16px',
                  outline: 'none', 
                  transition: 'all 0.3s ease',
                  background: '#fff',
                  minHeight: isMobile ? '52px' : 'auto',
                  fontWeight: '500',
                  color: '#374151',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
                }} 
                onFocus={(e) => {
                  e.target.style.borderColor = '#667eea';
                  e.target.style.boxShadow = '0 0 0 3px rgba(102, 126, 234, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
                }}
                required 
              />
            </div>
            <div style={{
              flex: 1,
              background: '#f8fafc',
              padding: isMobile ? '20px 16px' : '24px 20px',
              borderRadius: '16px',
              border: '2px solid #e2e8f0',
              transition: 'all 0.3s ease'
            }}>
              <label style={{
                fontWeight: '700', 
                marginBottom: '12px', 
                display: 'block',
                color: '#1f2937',
                fontSize: isMobile ? '15px' : '16px'
              }}>{t('publishTask.rewardLabel')}</label>
              <input 
                name="reward" 
                type="number" 
                min="1" 
                step="0.01" 
                value={form.reward} 
                onChange={handleChange} 
                style={{
                  padding: isMobile ? '16px 18px' : '14px 16px', 
                  borderRadius: '12px', 
                  border: '2px solid #e2e8f0', 
                  width: '80%',
                  maxWidth: '80%',
                  margin: '0 auto',
                  boxSizing: 'border-box',
                  fontSize: isMobile ? '16px' : '16px',
                  outline: 'none', 
                  transition: 'all 0.3s ease',
                  background: '#fff',
                  minHeight: isMobile ? '52px' : 'auto',
                  fontWeight: '500',
                  color: '#374151',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
                }} 
                onFocus={(e) => {
                  e.target.style.borderColor = '#667eea';
                  e.target.style.boxShadow = '0 0 0 3px rgba(102, 126, 234, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
                }}
                required 
                placeholder={t('publishTask.rewardPlaceholder')} 
              />
              {/* 任务等级提示 */}
              {form.reward && parseFloat(form.reward) > 0 && (
                <div style={{
                  marginTop: '8px',
                  padding: '8px 12px',
                  borderRadius: '8px',
                  fontSize: isMobile ? '13px' : '14px',
                  fontWeight: '500',
                  textAlign: 'center',
                  background: systemSettings.super_vip_enabled && parseFloat(form.reward) >= systemSettings.super_vip_price_threshold 
                    ? 'linear-gradient(135deg, #8b5cf6, #a855f7)' 
                    : systemSettings.vip_enabled && parseFloat(form.reward) >= systemSettings.vip_price_threshold
                    ? 'linear-gradient(135deg, #f59e0b, #fbbf24)'
                    : 'linear-gradient(135deg, #6b7280, #9ca3af)',
                  color: '#fff',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                }}>
                  {getTaskLevelHint(parseFloat(form.reward))}
                </div>
              )}
            </div>
          </div>
          {error && (
            <div style={{
              color: '#dc2626',
              marginBottom: '20px',
              textAlign: 'center',
              fontWeight: '600',
              padding: '12px 16px',
              background: '#fef2f2',
              border: '2px solid #fecaca',
              borderRadius: '12px',
              fontSize: '14px'
            }}>
              ❌ {error}
            </div>
          )}
          {success && (
            <div style={{
              color: '#059669',
              marginBottom: '20px',
              textAlign: 'center',
              fontWeight: '600',
              padding: '12px 16px',
              background: '#f0fdf4',
              border: '2px solid #bbf7d0',
              borderRadius: '12px',
              fontSize: '14px'
            }}>
              ✅ {success}
            </div>
          )}
          <button 
            type="submit" 
            disabled={loading} 
            style={{
              width: '100%',
              padding: isMobile ? '20px 24px' : '24px 32px',
              background: loading 
                ? 'linear-gradient(135deg, #cbd5e1, #94a3b8)' 
                : 'linear-gradient(135deg, #667eea, #764ba2)',
              color: '#fff',
              border: 'none',
              borderRadius: '16px',
              fontSize: isMobile ? '18px' : '20px',
              fontWeight: '800',
              letterSpacing: '0.5px',
              boxShadow: loading 
                ? '0 4px 12px rgba(0,0,0,0.1)' 
                : '0 8px 25px rgba(102, 126, 234, 0.4)',
              cursor: loading ? 'not-allowed' : 'pointer',
              transition: 'all 0.3s ease',
              position: 'relative',
              overflow: 'hidden',
              minHeight: isMobile ? '60px' : 'auto'
            }}
            onMouseEnter={(e) => {
              if (!loading) {
                e.currentTarget.style.transform = 'translateY(-2px)';
                e.currentTarget.style.boxShadow = '0 12px 32px rgba(102, 126, 234, 0.4)';
              }
            }}
            onMouseLeave={(e) => {
              if (!loading) {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 8px 24px rgba(102, 126, 234, 0.3)';
              }
            }}
          >
            {loading ? (
              t('publishTask.publishingButton')
            ) : (
              t('publishTask.publishButton')
            )}
          </button>
        </form>
      </div>
    </div>
  );
};

export default PublishTask; 