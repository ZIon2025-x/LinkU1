import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { TASK_TYPES, CITIES } from './Tasks';
import api from '../api';
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

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
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
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: isMobile ? '10px' : '20px'
    }}>
      <div style={{
        maxWidth: isMobile ? '100%' : '600px',
        margin: '0 auto',
        background: '#fff',
        borderRadius: isMobile ? '16px' : '24px',
        boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
        padding: isMobile ? '20px' : '30px',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {/* 装饰性背景 */}
        <div style={{
          position: 'absolute',
          top: '-50px',
          right: '-50px',
          width: '200px',
          height: '200px',
          background: 'linear-gradient(45deg, #667eea, #764ba2)',
          borderRadius: '50%',
          opacity: 0.1
        }} />
        <div style={{
          position: 'absolute',
          bottom: '-30px',
          left: '-30px',
          width: '150px',
          height: '150px',
          background: 'linear-gradient(45deg, #764ba2, #667eea)',
          borderRadius: '50%',
          opacity: 0.1
        }} />
        
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
        <form onSubmit={handleSubmit} style={{ position: 'relative', zIndex: 1 }}>
          <div style={{
            display: 'flex', 
            gap: isMobile ? '12px' : '16px', 
            marginBottom: '20px',
            flexDirection: isMobile ? 'column' : 'row'
          }}>
            <div style={{flex: 1}}>
              <label style={{
                fontWeight: '600', 
                marginBottom: '8px', 
                display: 'block',
                color: '#374151',
                fontSize: '14px'
              }}>{t('publishTask.taskType')}</label>
              <select 
                name="task_type" 
                value={form.task_type} 
                onChange={handleChange} 
                style={{
                  padding: isMobile ? '12px 14px' : '10px 14px', 
                  borderRadius: '10px', 
                  border: '2px solid #e5e7eb', 
                  width: '100%', 
                  fontSize: isMobile ? '16px' : '16px', // 防止iOS缩放
                  outline: 'none', 
                  transition: 'all 0.3s ease',
                  background: '#fff',
                  cursor: 'pointer',
                  minHeight: isMobile ? '44px' : 'auto'
                }}
                onFocus={(e) => e.target.style.borderColor = '#667eea'}
                onBlur={(e) => e.target.style.borderColor = '#e5e7eb'}
              >
                {TASK_TYPES.map((type: string) => <option key={type} value={type}>{t(`publishTask.taskTypes.${type}`)}</option>)}
              </select>
            </div>
            <div style={{flex: 1}}>
              <label style={{
                fontWeight: '600', 
                marginBottom: '8px', 
                display: 'block',
                color: '#374151',
                fontSize: '14px'
              }}>{t('publishTask.city')}</label>
              <select 
                name="location" 
                value={form.location} 
                onChange={handleChange} 
                style={{
                  padding: isMobile ? '12px 14px' : '10px 14px', 
                  borderRadius: '10px', 
                  border: '2px solid #e5e7eb', 
                  width: '100%', 
                  fontSize: isMobile ? '16px' : '16px', // 防止iOS缩放
                  outline: 'none', 
                  transition: 'all 0.3s ease',
                  background: '#fff',
                  cursor: 'pointer',
                  minHeight: isMobile ? '44px' : 'auto'
                }}
                onFocus={(e) => e.target.style.borderColor = '#667eea'}
                onBlur={(e) => e.target.style.borderColor = '#e5e7eb'}
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
          <div style={{marginBottom: '24px'}}>
            <label style={{
              fontWeight: '600', 
              marginBottom: '8px', 
              display: 'block',
              color: '#374151',
              fontSize: '14px'
            }}>{t('publishTask.titleLabel')}</label>
            <input 
              name="title" 
              value={form.title} 
              onChange={handleChange} 
              style={{
                padding: isMobile ? '14px 16px' : '12px 16px', 
                borderRadius: '12px', 
                border: '2px solid #e5e7eb', 
                width: '100%', 
                fontSize: isMobile ? '16px' : '16px', // 防止iOS缩放
                outline: 'none', 
                transition: 'all 0.3s ease',
                background: '#fff',
                minHeight: isMobile ? '48px' : 'auto'
              }} 
              onFocus={(e) => e.target.style.borderColor = '#667eea'}
              onBlur={(e) => e.target.style.borderColor = '#e5e7eb'}
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
          <div style={{marginBottom: '24px'}}>
            <label style={{
              fontWeight: '600', 
              marginBottom: '8px', 
              display: 'block',
              color: '#374151',
              fontSize: '14px'
            }}>{t('publishTask.descriptionLabel')}</label>
            <textarea 
              name="description" 
              value={form.description} 
              onChange={handleChange} 
              style={{
                padding: isMobile ? '12px 14px' : '10px 14px', 
                borderRadius: '10px', 
                border: '2px solid #e5e7eb', 
                width: '100%', 
                minHeight: isMobile ? '90px' : '100px', 
                fontSize: isMobile ? '16px' : '16px', // 防止iOS缩放
                outline: 'none', 
                transition: 'all 0.3s ease',
                background: '#fff',
                resize: 'vertical'
              }} 
              onFocus={(e) => e.target.style.borderColor = '#667eea'}
              onBlur={(e) => e.target.style.borderColor = '#e5e7eb'}
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
          <div style={{
            display: 'flex', 
            gap: isMobile ? '12px' : '16px', 
            marginBottom: '20px',
            flexDirection: isMobile ? 'column' : 'row'
          }}>
            <div style={{flex: 1}}>
              <label style={{
                fontWeight: '600', 
                marginBottom: '8px', 
                display: 'block',
                color: '#374151',
                fontSize: '14px'
              }}>{t('publishTask.deadlineLabel')}</label>
              <input 
                name="deadline" 
                type="datetime-local" 
                value={form.deadline} 
                onChange={handleChange} 
                style={{
                  padding: isMobile ? '12px 14px' : '10px 14px', 
                  borderRadius: '10px', 
                  border: '2px solid #e5e7eb', 
                  width: '100%', 
                  fontSize: isMobile ? '16px' : '16px', // 防止iOS缩放
                  outline: 'none', 
                  transition: 'all 0.3s ease',
                  background: '#fff',
                  minHeight: isMobile ? '44px' : 'auto'
                }} 
                onFocus={(e) => e.target.style.borderColor = '#667eea'}
                onBlur={(e) => e.target.style.borderColor = '#e5e7eb'}
                required 
              />
            </div>
            <div style={{flex: 1}}>
              <label style={{
                fontWeight: '600', 
                marginBottom: '8px', 
                display: 'block',
                color: '#374151',
                fontSize: '14px'
              }}>{t('publishTask.rewardLabel')}</label>
              <input 
                name="reward" 
                type="number" 
                min="1" 
                step="0.01" 
                value={form.reward} 
                onChange={handleChange} 
                style={{
                  padding: isMobile ? '12px 14px' : '10px 14px', 
                  borderRadius: '10px', 
                  border: '2px solid #e5e7eb', 
                  width: '100%', 
                  fontSize: isMobile ? '16px' : '16px', // 防止iOS缩放
                  outline: 'none', 
                  transition: 'all 0.3s ease',
                  background: '#fff',
                  minHeight: isMobile ? '44px' : 'auto'
                }} 
                onFocus={(e) => e.target.style.borderColor = '#667eea'}
                onBlur={(e) => e.target.style.borderColor = '#e5e7eb'}
                required 
                placeholder={t('publishTask.rewardPlaceholder')} 
              />
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
              padding: isMobile ? '14px 20px' : '12px 20px',
              background: loading 
                ? 'linear-gradient(135deg, #cbd5e1, #94a3b8)' 
                : 'linear-gradient(135deg, #667eea, #764ba2)',
              color: '#fff',
              border: 'none',
              borderRadius: isMobile ? '10px' : '12px',
              fontSize: isMobile ? '16px' : '16px',
              fontWeight: '700',
              letterSpacing: '1px',
              boxShadow: loading 
                ? '0 4px 12px rgba(0,0,0,0.1)' 
                : '0 6px 20px rgba(102, 126, 234, 0.3)',
              cursor: loading ? 'not-allowed' : 'pointer',
              transition: 'all 0.3s ease',
              position: 'relative',
              overflow: 'hidden',
              minHeight: isMobile ? '48px' : 'auto'
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