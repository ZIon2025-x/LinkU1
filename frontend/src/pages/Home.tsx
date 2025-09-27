import React, { useEffect, useState } from 'react';
import api, { fetchTasks, fetchCurrentUser, getNotifications, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, customerServiceLogout, getPublicSystemSettings } from '../api';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from '../components/LoginModal';
import Footer from '../components/Footer';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

// 剩余时间计算函数 - 使用本地时间
function getRemainTime(deadline: string) {
  const now = dayjs();
  const end = dayjs(deadline).local();
  const diff = end.diff(now, 'minute');
  
  if (diff <= 0) return "已过期";
  
  const hours = Math.floor(diff / 60);
  const minutes = diff % 60;
  
  if (hours > 0) {
    return `${hours}小时${minutes}分钟`;
  }
  return `${minutes}分钟`;
}

// 检查是否即将过期 - 使用本地时间
function isExpiringSoon(deadline: string) {
  const now = dayjs();
  const end = dayjs(deadline).local();
  const oneDayLater = now.add(1, 'day');
  
  return now.isBefore(end) && end.isBefore(oneDayLater);
}

// 检查是否已过期 - 使用本地时间
function isExpired(deadline: string) {
  const now = dayjs();
  const end = dayjs(deadline).local();
  return now.isAfter(end);
}

// 添加可爱的动画样式
const bellStyles = `
  @keyframes bellShake {
    0%, 100% { transform: rotate(0deg); }
    10%, 30%, 50%, 70%, 90% { transform: rotate(5deg); }
    20%, 40%, 60%, 80% { transform: rotate(-5deg); }
  }
  
  @keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.1); }
    100% { transform: scale(1); }
  }
  
  @keyframes bounce {
    0%, 20%, 50%, 80%, 100% { transform: translateY(0); }
    40% { transform: translateY(-3px); }
    60% { transform: translateY(-2px); }
  }
  
  @keyframes float {
    0% { transform: translateX(-50%) translateY(-50%) rotate(0deg); }
    100% { transform: translateX(-50%) translateY(-50%) rotate(360deg); }
  }
  
  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(30px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
`;

// 注入样式到页面
if (typeof document !== 'undefined') {
  const styleElement = document.createElement('style');
  styleElement.textContent = bellStyles;
  document.head.appendChild(styleElement);
}

export const TASK_TYPES = [
  "Housekeeping", "Campus Life", "Second-hand & Rental", "Errand Running", "Skill Service", "Social Help", "Transportation", "Pet Care", "Life Convenience", "Other"
];
export const CITIES = [
  "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"
];

interface Notification {
  id: number;
  type: string;
  title: string;
  content: string;
  related_id?: number;
  is_read: number;
  created_at: string;
}

const Home: React.FC = () => {
  // 联调相关状态
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [type, setType] = useState('全部类型');
  const [city, setCity] = useState('全部城市');
  const [keyword, setKeyword] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize] = useState(6);
  const [total, setTotal] = useState(0);

  // 用户登录与头像逻辑
  const [user, setUser] = useState<any>(null);
  const [showMenu, setShowMenu] = useState(false);
  
  // 通知相关状态
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  
  // 系统设置状态
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // 登录弹窗状态
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  
  useEffect(() => {
    const loadUserData = async () => {
      try {
        // 直接尝试获取用户信息，HttpOnly Cookie会自动发送
        const userData = await fetchCurrentUser();
        console.log('获取用户资料成功:', userData);
        setUser(userData);
      } catch (error: any) {
        console.log('获取用户资料失败:', error);
        console.log('错误详情:', error.response?.status, error.response?.data);
        setUser(null);
      }
    };
    
    // 添加短暂延迟，确保页面完全加载后再获取用户资料
    const timer = setTimeout(loadUserData, 100);
    
    // 加载系统设置
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
    
    return () => clearTimeout(timer);
  }, []);

  // 获取通知数据
  useEffect(() => {
    if (user) {
      console.log('获取通知数据，用户ID:', user.id);
      // 获取通知列表
      getNotifications(10).then(notifications => {
        console.log('获取到的通知列表:', notifications);
        setNotifications(notifications);
      }).catch(error => {
        console.error('获取通知失败:', error);
      });
      // 获取未读数量
      getUnreadNotificationCount().then(count => {
        console.log('获取到的未读通知数量:', count);
        setUnreadCount(count);
      }).catch(error => {
        console.error('获取未读数量失败:', error);
      });
    }
  }, [user]);

  // 定期更新未读通知数量
  useEffect(() => {
    if (user) {
      const interval = setInterval(() => {
        // 只在页面可见时才更新
        if (!document.hidden) {
          getUnreadNotificationCount().then(count => {
            console.log('定期更新未读通知数量:', count);
            setUnreadCount(count);
          }).catch(error => {
            console.error('定期更新未读数量失败:', error);
          });
        }
      }, 30000); // 每30秒更新一次
      return () => clearInterval(interval);
    }
  }, [user]);

  // 获取任务数据
  useEffect(() => {
    setLoading(true);
    console.log('开始获取任务数据，参数:', { type, city, keyword, page, pageSize });
    fetchTasks({ type, city, keyword, page, pageSize })
      .then(data => {
        console.log('获取到的任务数据:', data);
        setTasks(Array.isArray(data) ? data : (data.items || []));
        setTotal(data.total || 0);
      })
      .catch(error => {
        console.error('获取任务数据失败:', error);
        setTasks([]);
        setTotal(0);
      })
      .finally(() => setLoading(false));
  }, [type, city, keyword, page, pageSize]);

  // 定期刷新任务列表以更新剩余时间和状态
  useEffect(() => {
    const interval = setInterval(() => {
      if (tasks.length > 0) {
        // 重新获取任务数据以更新状态
        fetchTasks({ type, city, keyword, page, pageSize })
          .then(data => {
            const newTasks = Array.isArray(data) ? data : (data.items || []);
            setTasks(newTasks);
            setTotal(data.total || 0);
          })
          .catch(error => {
            console.error('定期刷新任务列表失败:', error);
          });
      }
    }, 60000); // 每分钟更新一次
    return () => clearInterval(interval);
  }, [type, city, keyword, page, pageSize, tasks.length]);

  const navigate = useNavigate();

  // 处理通知点击 - 只标记为已读，不跳转
  const handleNotificationClick = async (notification: Notification) => {
    // 只标记通知为已读，不进行任何跳转
    await markNotificationRead(notification.id);
    
    // 更新本地状态，标记为已读
    setNotifications(prev => 
      prev.map(n => 
        n.id === notification.id ? { ...n, is_read: 1 } : n
      )
    );
    
    // 更新未读数量
    setUnreadCount(prev => Math.max(0, prev - 1));
    
    // 不关闭通知面板，让用户可以继续查看其他通知
  };

  // 标记所有通知为已读
  const handleMarkAllRead = async () => {
    await markAllNotificationsRead();
    setUnreadCount(0);
    // 更新通知列表，标记所有为已读
    setNotifications(prev => prev.map(n => ({ ...n, is_read: 1 })));
  };



  // 点击外部关闭弹窗
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('.notification-container') && !target.closest('.bell-icon') && !target.closest('.avatar-menu')) {
        setShowNotifications(false);
        setShowMenu(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  return (
    <div>
      {/* 顶部导航栏 */}
      <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
        <div style={{display: 'flex', alignItems: 'center', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          <div style={{fontWeight: 'bold', fontSize: 24, background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent'}}>LinkU</div>
          <nav style={{marginLeft: 40, flex: 1}}>
            <button onClick={() => navigate('/tasks')} style={{marginRight: 24, color: '#A67C52', fontWeight: 600, textDecoration: 'none', background: 'none', border: 'none', cursor: 'pointer', fontSize: 'inherit'}}>任务大厅</button>
            <button onClick={() => navigate('/publish')} style={{marginRight: 24, color: '#A67C52', fontWeight: 600, textDecoration: 'none', background: 'none', border: 'none', cursor: 'pointer', fontSize: 'inherit'}}>发布任务</button>
            <button onClick={() => navigate('/join-us')} style={{marginRight: 24, color: '#A67C52', fontWeight: 600, textDecoration: 'none', background: 'none', border: 'none', cursor: 'pointer', fontSize: 'inherit'}}>加入我们</button>
            <button onClick={() => navigate('/about')} style={{marginRight: 24, color: '#A67C52', fontWeight: 600, textDecoration: 'none', background: 'none', border: 'none', cursor: 'pointer', fontSize: 'inherit'}}>关于我们</button>
          </nav>
          {/* 登录/注册 或 头像下拉菜单 */}
          <div style={{position: 'relative', display: 'flex', alignItems: 'center', gap: 16}}>
            {user ? (
              <>
                {/* 可爱的卡通铃铛图标 */}
                <div className="bell-icon" style={{position: 'relative', cursor: 'pointer'}} onClick={() => { setShowNotifications(prev => !prev); setShowMenu(false); }}>
                  <div style={{
                    width: 40,
                    height: 40,
                    background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                    borderRadius: '50%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: '0 6px 12px rgba(255, 215, 0, 0.4), inset 0 2px 4px rgba(255,255,255,0.3)',
                    border: '3px solid #FFF',
                    position: 'relative',
                    animation: unreadCount > 0 ? 'bellShake 2s infinite' : 'none',
                    transition: 'all 0.3s ease',
                    cursor: 'pointer'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'scale(1.15) rotate(5deg)';
                    e.currentTarget.style.boxShadow = '0 8px 16px rgba(255, 215, 0, 0.6), inset 0 2px 4px rgba(255,255,255,0.3)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = unreadCount > 0 ? 'scale(1)' : 'scale(1)';
                    e.currentTarget.style.boxShadow = '0 6px 12px rgba(255, 215, 0, 0.4), inset 0 2px 4px rgba(255,255,255,0.3)';
                  }}
                  >
                    <div style={{
                      fontSize: 20,
                      color: '#8B4513',
                      fontWeight: 'bold',
                      textShadow: '2px 2px 4px rgba(255,255,255,0.9)',
                      filter: 'drop-shadow(1px 1px 2px rgba(0,0,0,0.1))'
                    }}>
                      🔔
                    </div>
                    {/* 铃铛的装饰小点 */}
                    <div style={{
                      position: 'absolute',
                      top: 3,
                      right: 3,
                      width: 5,
                      height: 5,
                      background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
                      borderRadius: '50%',
                      boxShadow: '0 0 6px rgba(255, 107, 107, 0.8), inset 0 1px 2px rgba(255,255,255,0.3)',
                      animation: 'pulse 2s infinite'
                    }} />
                    {/* 铃铛的光晕效果 */}
                    <div style={{
                      position: 'absolute',
                      top: -2,
                      left: -2,
                      right: -2,
                      bottom: -2,
                      background: 'radial-gradient(circle, rgba(255,215,0,0.2) 0%, transparent 70%)',
                      borderRadius: '50%',
                      animation: unreadCount > 0 ? 'pulse 3s infinite' : 'none'
                    }} />
                  </div>
                  
                  {unreadCount > 0 && (
                    <div style={{
                      position: 'absolute',
                      top: -6,
                      right: -6,
                      background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
                      color: 'white',
                      borderRadius: '50%',
                      width: 22,
                      height: 22,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: 11,
                      fontWeight: 'bold',
                      border: '3px solid #fff',
                      boxShadow: '0 3px 6px rgba(255, 107, 107, 0.4), 0 0 0 2px rgba(255, 107, 107, 0.2)',
                      animation: 'pulse 1.5s infinite'
                    }}>
                      {unreadCount > 99 ? '99+' : unreadCount}
                    </div>
                  )}
                </div>
                
                {/* 可爱的通知弹窗 */}
                {showNotifications && (
                  <div className="notification-container" style={{
                    position: 'absolute',
                    right: 0,
                    top: 48,
                    background: 'linear-gradient(135deg, #fff 0%, #f8f9fa 100%)',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.15), 0 4px 8px rgba(255, 215, 0, 0.1)',
                    borderRadius: 16,
                    minWidth: 320,
                    maxWidth: 400,
                    maxHeight: 400,
                    overflowY: 'auto',
                    zIndex: 1000,
                    border: '2px solid rgba(255, 215, 0, 0.2)',
                    animation: 'bounce 0.5s ease-out'
                  }}>
                    <div style={{
                      padding: '16px 20px',
                      borderBottom: '2px solid rgba(255, 215, 0, 0.2)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      background: 'linear-gradient(135deg, rgba(255, 215, 0, 0.05) 0%, rgba(255, 215, 0, 0.1) 100%)'
                    }}>
                      <span style={{
                        fontWeight: 700, 
                        color: '#A67C52',
                        fontSize: 16,
                        display: 'flex',
                        alignItems: 'center',
                        gap: 8
                      }}>
                        🔔 通知
                      </span>
                                             <div style={{display: 'flex', gap: 8}}>
                         {unreadCount > 0 && (
                           <button
                             onClick={handleMarkAllRead}
                             style={{
                               background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                               border: 'none',
                               color: 'white',
                               fontSize: 12,
                               cursor: 'pointer',
                               padding: '6px 12px',
                               borderRadius: 12,
                               fontWeight: 600,
                               boxShadow: '0 2px 4px rgba(110, 193, 228, 0.3)',
                               transition: 'all 0.2s ease'
                             }}
                             onMouseEnter={(e) => {
                               e.currentTarget.style.transform = 'scale(1.05)';
                               e.currentTarget.style.boxShadow = '0 4px 8px rgba(110, 193, 228, 0.4)';
                             }}
                             onMouseLeave={(e) => {
                               e.currentTarget.style.transform = 'scale(1)';
                               e.currentTarget.style.boxShadow = '0 2px 4px rgba(110, 193, 228, 0.3)';
                             }}
                           >
                             ✓ 全部已读
                           </button>
                         )}
                       </div>
                    </div>
                    
                    {notifications.length === 0 ? (
                      <div style={{padding: '20px', textAlign: 'center', color: '#888'}}>
                        暂无通知
                      </div>
                    ) : (
                      <div>
                        {notifications.map(notification => (
                          <div
                            key={notification.id}
                            onClick={() => handleNotificationClick(notification)}
                            style={{
                              padding: '12px 16px',
                              borderBottom: '1px solid #f0f0f0',
                              cursor: 'default', // 改为默认光标，表示不可点击跳转
                              background: notification.is_read === 0 ? '#f8fbff' : 'transparent',
                              transition: 'background-color 0.2s',
                              position: 'relative'
                            }}
                            onMouseEnter={(e) => e.currentTarget.style.backgroundColor = notification.is_read === 0 ? '#f0f8ff' : '#f9f9f9'}
                            onMouseLeave={(e) => e.currentTarget.style.backgroundColor = notification.is_read === 0 ? '#f8fbff' : 'transparent'}
                          >
                            <div style={{
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'flex-start',
                              marginBottom: 4
                            }}>
                              <div style={{
                                fontWeight: notification.is_read === 0 ? 600 : 500,
                                color: '#333',
                                fontSize: 14
                              }}>
                                {notification.title}
                              </div>
                              {notification.is_read === 0 && (
                                <div style={{
                                  width: 6,
                                  height: 6,
                                  borderRadius: '50%',
                                  background: '#ff4757',
                                  flexShrink: 0,
                                  marginTop: 4
                                }} />
                              )}
                            </div>
                            <div style={{
                              color: '#666',
                              fontSize: 12,
                              lineHeight: 1.4,
                              marginBottom: 4
                            }}>
                              {notification.content}
                            </div>
                            <div style={{
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center'
                            }}>
                              <div style={{
                                color: '#999',
                                fontSize: 11
                              }}>
                                {dayjs(notification.created_at).tz('Europe/London').format('YYYY/MM/DD HH:mm:ss')} (英国时间)
                              </div>
                              <div style={{
                                color: '#ccc',
                                fontSize: 10,
                                display: 'flex',
                                alignItems: 'center',
                                gap: 4
                              }}>
                                <span>👁️</span>
                                <span>仅查看</span>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}
                
                <img
                  src={user.avatar || '/avatar1.png'}
                  alt="头像"
                  style={{width: 38, height: 38, borderRadius: '50%', border: '2px solid #8b5cf6', background: '#f8fbff', objectFit: 'cover', verticalAlign: 'middle', cursor: 'pointer'}}
                  onClick={() => { setShowMenu(prev => !prev); setShowNotifications(false); }}
                />
                {showMenu && (
                  <div className="avatar-menu" style={{position: 'absolute', right: 0, top: 48, background: '#fff', boxShadow: '0 2px 8px #e6f7ff', borderRadius: 8, minWidth: 160, zIndex: 999}}>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/my-tasks'); }}>我的任务</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/message'); }}>我的信息</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/profile'); }}>个人主页</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/wallet'); }}>💰 我的钱包</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/settings'); }}>⚙️ 设置</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#d32f2f', fontWeight: 600, borderTop: '1px solid #eee'}} onClick={async () => { 
                      setShowMenu(false); 
                      // 调用后端登出接口清除HttpOnly Cookie
                      try {
                        await api.post('/api/users/logout');
                      } catch (error) {
                        console.log('登出请求失败:', error);
                      }
                      window.location.reload(); 
                    }}>退出登录</div>
                  </div>
                )}
                
                {/* VIP按钮 - 根据系统设置显示 */}
                {systemSettings.vip_button_visible && (
                  <button 
                    onClick={() => navigate('/vip')} 
                    style={{
                      padding: '8px 16px',
                      background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '20px',
                      fontSize: '14px',
                      fontWeight: 'bold',
                      cursor: 'pointer',
                      boxShadow: '0 2px 8px rgba(255, 215, 0, 0.3)',
                      transition: 'all 0.3s ease',
                      textShadow: '0 1px 2px rgba(0,0,0,0.2)'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.transform = 'translateY(-2px)';
                      e.currentTarget.style.boxShadow = '0 4px 12px rgba(255, 215, 0, 0.4)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 2px 8px rgba(255, 215, 0, 0.3)';
                    }}
                  >
                    ✨ VIP
                  </button>
                )}
              </>
            ) : (
              <>
                <button 
                  onClick={() => setShowLoginModal(true)}
                  style={{
                    color: '#A67C52', 
                    fontWeight: 600, 
                    background: 'none', 
                    border: 'none', 
                    cursor: 'pointer', 
                    fontSize: 'inherit'
                  }}
                >
                  登录
                </button>
              </>
            )}
          </div>
        </div>
      </header>
      {/* 占位，防止内容被导航栏遮挡 */}
      <div style={{height: 60}} />
      
      {/* 英雄区域 - 重新设计 */}
      <section style={{
        background: 'linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%)',
        padding: '80px 0',
        textAlign: 'center',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {/* 背景装饰 */}
        <div style={{
          position: 'absolute',
          top: '-50%',
          left: '-50%',
          width: '200%',
          height: '200%',
          background: 'radial-gradient(circle, rgba(255,255,255,0.1) 1px, transparent 1px)',
          backgroundSize: '50px 50px',
          animation: 'float 20s infinite linear',
          pointerEvents: 'none'
        }} />
        
        <div style={{maxWidth: 1200, margin: '0 auto', padding: '0 24px', position: 'relative', zIndex: 2}}>
          <h1 style={{
            fontSize: '48px',
            fontWeight: '800',
            marginBottom: '24px',
            color: '#fff',
            textShadow: '0 4px 8px rgba(0,0,0,0.3)',
            lineHeight: '1.2'
          }}>
            连接英国留学生
            <br />
            <span style={{color: '#FFD700'}}>互助共赢</span>
          </h1>
          
          <p style={{
            fontSize: '20px',
            color: 'rgba(255,255,255,0.9)',
            marginBottom: '40px',
            maxWidth: '600px',
            margin: '0 auto 40px',
            lineHeight: '1.6'
          }}>
            发布任务，寻找帮手，安全交易，建立信任社区
          </p>
          
          <div style={{display: 'flex', justifyContent: 'center', gap: '20px', flexWrap: 'wrap', marginBottom: '60px'}}>
            <button 
              onClick={() => navigate('/tasks')}
              style={{
                background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                color: '#8B4513',
                padding: '16px 32px',
                borderRadius: '50px',
                fontSize: '18px',
                fontWeight: '700',
                border: 'none',
                cursor: 'pointer',
                boxShadow: '0 8px 24px rgba(255, 215, 0, 0.4)',
                transition: 'all 0.3s ease',
                transform: 'translateY(0)'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)';
                e.currentTarget.style.boxShadow = '0 12px 32px rgba(255, 215, 0, 0.6)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 8px 24px rgba(255, 215, 0, 0.4)';
              }}
            >
              🚀 浏览任务
            </button>
            
            <button 
              onClick={() => navigate('/publish')}
              style={{
                background: 'rgba(255,255,255,0.2)',
                color: '#fff',
                padding: '16px 32px',
                borderRadius: '50px',
                fontSize: '18px',
                fontWeight: '700',
                border: '2px solid rgba(255,255,255,0.3)',
                cursor: 'pointer',
                backdropFilter: 'blur(10px)',
                transition: 'all 0.3s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'rgba(255,255,255,0.3)';
                e.currentTarget.style.borderColor = 'rgba(255,255,255,0.5)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                e.currentTarget.style.borderColor = 'rgba(255,255,255,0.3)';
              }}
            >
              ✨ 发布任务
            </button>
        </div>
          
          {/* 统计数据 */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
            gap: '40px',
            maxWidth: '800px',
            margin: '0 auto'
          }}>
            <div style={{textAlign: 'center'}}>
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>1000+</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>活跃用户</div>
          </div>
            <div style={{textAlign: 'center'}}>
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>5000+</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>完成任务</div>
          </div>
            <div style={{textAlign: 'center'}}>
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>98%</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>满意度</div>
            </div>
          </div>
        </div>
      </section>
      
      {/* 特色功能区域 */}
      <section style={{padding: '80px 0', background: '#f8fafc'}}>
        <div style={{maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          <h2 style={{
            fontSize: '36px',
            fontWeight: '700',
            textAlign: 'center',
            marginBottom: '16px',
            color: '#2d3748'
          }}>
            为什么选择 LinkU？
          </h2>
          <p style={{
            fontSize: '18px',
            color: '#718096',
            textAlign: 'center',
            marginBottom: '60px',
            maxWidth: '600px',
            margin: '0 auto 60px'
          }}>
            专为英国留学生设计的互助平台，让生活更简单
          </p>
          
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
            gap: '40px'
          }}>
            <div style={{
              background: '#fff',
              padding: '40px 30px',
              borderRadius: '20px',
              boxShadow: '0 10px 40px rgba(0,0,0,0.1)',
              textAlign: 'center',
              transition: 'transform 0.3s ease',
              border: '1px solid #e2e8f0'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-8px)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
            }}
            >
              <div style={{
                width: '80px',
                height: '80px',
                background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 24px',
                fontSize: '32px'
              }}>
                🎯
              </div>
              <h3 style={{fontSize: '24px', fontWeight: '700', marginBottom: '16px', color: '#2d3748'}}>
                精准匹配
              </h3>
              <p style={{color: '#718096', lineHeight: '1.6'}}>
                智能算法匹配最适合的任务和帮手，提高成功率，节省时间
              </p>
            </div>
            
            <div style={{
              background: '#fff',
              padding: '40px 30px',
              borderRadius: '20px',
              boxShadow: '0 10px 40px rgba(0,0,0,0.1)',
              textAlign: 'center',
              transition: 'transform 0.3s ease',
              border: '1px solid #e2e8f0'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-8px)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
            }}
            >
              <div style={{
                width: '80px',
                height: '80px',
                background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 24px',
                fontSize: '32px'
              }}>
                🛡️
              </div>
              <h3 style={{fontSize: '24px', fontWeight: '700', marginBottom: '16px', color: '#2d3748'}}>
                安全保障
              </h3>
              <p style={{color: '#718096', lineHeight: '1.6'}}>
                平台担保交易，实名认证，多重保障让您放心交易
              </p>
            </div>
            
            <div style={{
              background: '#fff',
              padding: '40px 30px',
              borderRadius: '20px',
              boxShadow: '0 10px 40px rgba(0,0,0,0.1)',
              textAlign: 'center',
              transition: 'transform 0.3s ease',
              border: '1px solid #e2e8f0'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-8px)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
            }}
            >
              <div style={{
                width: '80px',
                height: '80px',
                background: 'linear-gradient(135deg, #48bb78, #38a169)',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 24px',
                fontSize: '32px'
              }}>
                ⚡
              </div>
              <h3 style={{fontSize: '24px', fontWeight: '700', marginBottom: '16px', color: '#2d3748'}}>
                快速响应
              </h3>
              <p style={{color: '#718096', lineHeight: '1.6'}}>
                24小时在线客服，实时消息推送，快速解决问题
              </p>
            </div>
          </div>
        </div>
      </section>
      {/* 最新任务区块 - 重新设计 */}
      <main style={{maxWidth: 1200, margin: '0 auto', padding: '80px 24px'}}>
        <div style={{textAlign: 'center', marginBottom: '60px'}}>
          <h2 style={{
            fontSize: '36px',
            fontWeight: '700',
            marginBottom: '16px',
            color: '#2d3748'
          }}>
            最新任务
          </h2>
          <p style={{
            fontSize: '18px',
            color: '#718096',
            maxWidth: '600px',
            margin: '0 auto'
          }}>
            发现适合你的任务，开始你的互助之旅
          </p>
        </div>
        {/* 筛选/搜索栏 - 重新设计 */}
        <div style={{
          background: '#fff',
          borderRadius: '16px',
          padding: '24px',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)',
          marginBottom: '40px',
          border: '1px solid #e2e8f0'
        }}>
          <div style={{display: 'flex', gap: '16px', flexWrap: 'wrap', alignItems: 'center'}}>
            <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
              <span style={{color: '#4a5568', fontWeight: '600', fontSize: '14px'}}>类型:</span>
              <select 
                value={type} 
                onChange={e => { setType(e.target.value); setPage(1); }} 
                style={{
                  padding: '10px 16px',
                  borderRadius: '8px',
                  border: '1px solid #e2e8f0',
                  color: '#4a5568',
                  fontWeight: '500',
                  background: '#fff',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#8b5cf6';
                  e.target.style.boxShadow = '0 0 0 3px rgba(139, 92, 246, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = 'none';
                }}
              >
            <option>全部类型</option>
            {TASK_TYPES.map(type => (
              <option key={type} value={type}>{type}</option>
            ))}
          </select>
            </div>
            
            <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
              <span style={{color: '#4a5568', fontWeight: '600', fontSize: '14px'}}>城市:</span>
              <select 
                value={city} 
                onChange={e => { setCity(e.target.value); setPage(1); }} 
                style={{
                  padding: '10px 16px',
                  borderRadius: '8px',
                  border: '1px solid #e2e8f0',
                  color: '#4a5568',
                  fontWeight: '500',
                  background: '#fff',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#8b5cf6';
                  e.target.style.boxShadow = '0 0 0 3px rgba(139, 92, 246, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = 'none';
                }}
              >
            <option>全部城市</option>
            {CITIES.map(city => (
              <option key={city} value={city}>{city}</option>
            ))}
          </select>
            </div>
            
            <div style={{flex: 1, minWidth: '200px'}}>
              <input 
                type="text" 
                value={keyword} 
                onChange={e => setKeyword(e.target.value)} 
                placeholder="搜索任务关键词..." 
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  borderRadius: '8px',
                  border: '1px solid #e2e8f0',
                  color: '#4a5568',
                  fontSize: '14px',
                  transition: 'all 0.2s ease'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#8b5cf6';
                  e.target.style.boxShadow = '0 0 0 3px rgba(139, 92, 246, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = 'none';
                }}
              />
            </div>
            
            <button 
              onClick={() => { setPage(1); }} 
              style={{
                padding: '12px 24px',
                background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                color: '#fff',
                border: 'none',
                borderRadius: '8px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-1px)';
                e.currentTarget.style.boxShadow = '0 6px 16px rgba(59, 130, 246, 0.4)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
              }}
            >
              🔍 搜索
            </button>
          </div>
        </div>
        {/* 自动取消过期任务提示 */}
        <div style={{
          background: 'linear-gradient(135deg, #fff3cd, #ffeaa7)',
          border: '1px solid #ffc107',
          borderRadius: 8,
          padding: 12,
          marginBottom: 16,
          display: 'flex',
          alignItems: 'center',
          gap: 8
        }}>
          <span style={{fontSize: 16}}>⏰</span>
          <span style={{color: '#856404', fontSize: 14}}>
            系统会自动取消超过截止日期的任务，确保任务时效性
          </span>
        </div>
        {/* 任务卡片列表 - 重新设计 */}
        {loading ? (
          <div style={{
            textAlign: 'center', 
            padding: '80px 40px',
            background: '#fff',
            borderRadius: '16px',
            boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
          }}>
            <div style={{fontSize: '18px', color: '#718096'}}>🔄 正在加载任务...</div>
          </div>
        ) : tasks.length === 0 ? (
          <div style={{
            textAlign: 'center', 
            padding: '80px 40px',
            background: '#fff',
            borderRadius: '16px',
            boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
          }}>
            <div style={{fontSize: '48px', marginBottom: '16px'}}>📝</div>
            <div style={{fontSize: '18px', color: '#718096', marginBottom: '8px'}}>暂无任务</div>
            <div style={{fontSize: '14px', color: '#a0aec0'}}>请稍后再来查看或发布新任务</div>
          </div>
        ) : (
          <div style={{
            display: 'grid', 
            gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', 
            gap: '32px'
          }}>
            {tasks.map(task => {
              // 任务等级标签样式
              const getTaskLevelStyle = (level: string) => {
                switch (level) {
                  case 'vip':
                    return {
                      background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                      color: '#8B4513',
                      border: '2px solid #FFD700',
                      boxShadow: '0 2px 8px rgba(255, 215, 0, 0.3)'
                    };
                  case 'super':
                    return {
                      background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
                      color: '#fff',
                      border: '2px solid #FF4757',
                      boxShadow: '0 2px 8px rgba(255, 107, 107, 0.3)'
                    };
                  default:
                    return {
                      background: '#f8f9fa',
                      color: '#6c757d',
                      border: '1px solid #dee2e6'
                    };
                }
              };

              const getTaskLevelText = (level: string) => {
                switch (level) {
                  case 'vip':
                    return '⭐ VIP任务';
                  case 'super':
                    return '🔥 超级任务';
                  default:
                    return '普通任务';
                }
              };

              return (
                <div key={task.id} style={{
                  background: '#fff', 
                  borderRadius: '20px', 
                  boxShadow: '0 8px 32px rgba(0,0,0,0.08)', 
                  padding: '24px', 
                  display: 'flex', 
                  flexDirection: 'column', 
                  justifyContent: 'space-between', 
                  border: '1px solid #e2e8f0',
                  position: 'relative',
                  overflow: 'hidden',
                  transition: 'all 0.3s ease',
                  cursor: 'pointer'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-4px)';
                  e.currentTarget.style.boxShadow = '0 12px 40px rgba(0,0,0,0.12)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 8px 32px rgba(0,0,0,0.08)';
                }}
                onClick={() => navigate(`/tasks/${task.id}`)}
                >
                  {/* 任务等级标签 */}
                  {task.task_level && task.task_level !== 'normal' && (
                    <div style={{
                      position: 'absolute',
                      top: 12,
                      right: 12,
                      padding: '4px 8px',
                      borderRadius: 12,
                      fontSize: 12,
                      fontWeight: 700,
                      zIndex: 1,
                      ...getTaskLevelStyle(task.task_level)
                    }}>
                      {getTaskLevelText(task.task_level)}
                    </div>
                  )}
                  
                  <div>
                    <div style={{
                      fontWeight: '700', 
                      fontSize: '20px', 
                      marginBottom: '12px',
                      color: '#2d3748',
                      lineHeight: '1.4'
                    }}>
                      {task.title}
                    </div>
                    
                    <div style={{
                      display: 'flex',
                      gap: '12px',
                      marginBottom: '16px',
                      flexWrap: 'wrap'
                    }}>
                      <span style={{
                        background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                        color: '#fff',
                        padding: '4px 12px',
                        borderRadius: '20px',
                        fontSize: '12px',
                        fontWeight: '600'
                      }}>
                        {task.task_type}
                      </span>
                      <span style={{
                        background: '#f7fafc',
                        color: '#4a5568',
                        padding: '4px 12px',
                        borderRadius: '20px',
                        fontSize: '12px',
                        fontWeight: '500',
                        border: '1px solid #e2e8f0'
                      }}>
                        📍 {task.location}
                      </span>
                    </div>
                    
                    <div style={{
                      color: '#4a5568', 
                      marginBottom: '16px',
                      lineHeight: '1.6',
                      fontSize: '14px',
                      display: '-webkit-box',
                      WebkitLineClamp: 3,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden'
                    }}>
                      {task.description}
                    </div>
                    {/* 任务状态和时间信息 */}
                    <div style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginBottom: '20px',
                      padding: '12px 16px',
                      background: '#f8fafc',
                      borderRadius: '12px',
                      border: '1px solid #e2e8f0'
                    }}>
                      <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
                        <div style={{
                          width: '8px',
                          height: '8px',
                          borderRadius: '50%',
                          background: task.status === 'open' ? '#48bb78' : 
                                     task.status === 'taken' ? '#ed8936' : 
                                     task.status === 'in_progress' ? '#4299e1' : 
                                     task.status === 'completed' ? '#9f7aea' : 
                                     task.status === 'cancelled' ? '#f56565' : '#a0aec0'
                        }} />
                        <span style={{
                          color: task.status === 'open' ? '#48bb78' : 
                                 task.status === 'taken' ? '#ed8936' : 
                                 task.status === 'in_progress' ? '#4299e1' : 
                                 task.status === 'completed' ? '#9f7aea' : 
                                 task.status === 'cancelled' ? '#f56565' : '#a0aec0',
                          fontWeight: '600',
                          fontSize: '14px'
                      }}>
                        {task.status === 'open' ? '开放中' :
                         task.status === 'taken' ? '已接受' :
                         task.status === 'in_progress' ? '进行中' :
                         task.status === 'completed' ? '已完成' :
                         task.status === 'cancelled' ? '已取消' : task.status}
                      </span>
                    </div>
                      
                    {task.status === 'open' && !isExpired(task.deadline) && (
                        <div style={{
                          color: isExpiringSoon(task.deadline) ? '#ed8936' : '#48bb78',
                          fontWeight: '600',
                          fontSize: '12px'
                        }}>
                          ⏰ {getRemainTime(task.deadline)}
                      </div>
                    )}
                  </div>
                  </div>
                  
                  {/* 底部价格和操作区域 */}
                  <div style={{
                    display: 'flex', 
                    justifyContent: 'space-between', 
                    alignItems: 'center',
                    paddingTop: '16px',
                    borderTop: '1px solid #e2e8f0'
                  }}>
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px'
                    }}>
                      <span style={{
                        color: '#2d3748', 
                        fontWeight: '800', 
                        fontSize: '24px'
                      }}>
                        £{task.reward.toFixed(2)}
                      </span>
                      <span style={{
                        color: '#718096',
                        fontSize: '12px',
                        fontWeight: '500'
                      }}>
                        赏金
                      </span>
                    </div>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        navigate(`/tasks/${task.id}`);
                      }} 
                      style={{
                        background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                        color: '#fff',
                        border: 'none',
                        borderRadius: '8px',
                        padding: '8px 16px',
                        fontWeight: '600',
                        fontSize: '14px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        boxShadow: '0 2px 8px rgba(59, 130, 246, 0.3)'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.transform = 'translateY(-1px)';
                        e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.4)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.transform = 'translateY(0)';
                        e.currentTarget.style.boxShadow = '0 2px 8px rgba(59, 130, 246, 0.3)';
                      }}
                    >
                      查看详情
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
        {/* 分页按钮 */}
        <div style={{marginTop: 32, textAlign: 'center'}}>
          <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} style={{marginRight: 8, padding: '6px 16px', borderRadius: 4, border: '1px solid #8b5cf6', background: page === 1 ? '#eee' : '#fff', color: '#8b5cf6', fontWeight: 700}}>上一页</button>
          <span style={{margin: '0 12px', color: '#A67C52', fontWeight: 600}}>第 {page} 页</span>
          <button onClick={() => setPage(p => p + 1)} disabled={tasks.length < pageSize} style={{padding: '6px 16px', borderRadius: 4, border: '1px solid #8b5cf6', background: tasks.length < pageSize ? '#eee' : '#8b5cf6', color: tasks.length < pageSize ? '#8b5cf6' : '#fff', fontWeight: 700}}>下一页</button>
        </div>
      </main>
      {/* 平台优势/亮点区块 */}
      <section style={{background: '#f8fbff', padding: '48px 0'}}>
        <div style={{maxWidth: 1200, margin: '0 auto', display: 'flex', gap: 32, flexWrap: 'wrap', justifyContent: 'center'}}>
          <div style={{flex: 1, minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 32, textAlign: 'center', borderTop: '4px solid #8b5cf6'}}>
            <div style={{fontSize: 32, color: '#8b5cf6', marginBottom: 12}}>🌟</div>
            <div style={{fontWeight: 600, fontSize: 20, marginBottom: 8, color: '#A67C52'}}>多样任务类型</div>
            <div style={{color: '#888'}}>学业、生活、技能、跑腿等多种任务，满足不同需求</div>
          </div>
          <div style={{flex: 1, minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 32, textAlign: 'center', borderTop: '4px solid #A67C52'}}>
            <div style={{fontSize: 32, color: '#A67C52', marginBottom: 12}}>🔒</div>
            <div style={{fontWeight: 600, fontSize: 20, marginBottom: 8, color: '#A67C52'}}>安全结算保障</div>
            <div style={{color: '#888'}}>平台担保交易，资金安全有保障</div>
          </div>
          <div style={{flex: 1, minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 32, textAlign: 'center', borderTop: '4px solid #8b5cf6'}}>
            <div style={{fontSize: 32, color: '#8b5cf6', marginBottom: 12}}>⏱️</div>
            <div style={{fontWeight: 600, fontSize: 20, marginBottom: 8, color: '#A67C52'}}>高效撮合</div>
            <div style={{color: '#888'}}>智能推荐，优先展示会员任务，接单更快</div>
          </div>
        </div>
      </section>
      {/* 新手引导/操作流程区块 */}
      <section style={{background: '#fff', padding: '48px 0'}}>
        <div style={{maxWidth: 900, margin: '0 auto', textAlign: 'center'}}>
          <h3 style={{fontSize: 24, fontWeight: 700, marginBottom: 32, color: '#A67C52'}}>新手如何使用LinkU？</h3>
          <div style={{display: 'flex', justifyContent: 'center', gap: 40, flexWrap: 'wrap'}}>
            <div style={{minWidth: 180}}>
              <div style={{fontSize: 32, color: '#8b5cf6', marginBottom: 8}}>📝</div>
              <div style={{fontWeight: 600, marginBottom: 4, color: '#A67C52'}}>1. 注册/登录</div>
              <div style={{color: '#888'}}>快速注册账号，完善个人信息</div>
            </div>
            <div style={{minWidth: 180}}>
              <div style={{fontSize: 32, color: '#A67C52', marginBottom: 8}}>🔍</div>
              <div style={{fontWeight: 600, marginBottom: 4, color: '#A67C52'}}>2. 浏览/筛选任务</div>
              <div style={{color: '#888'}}>根据兴趣和能力选择合适的任务</div>
            </div>
            <div style={{minWidth: 180}}>
              <div style={{fontSize: 32, color: '#A67C52', marginBottom: 8}}>🤝</div>
              <div style={{fontWeight: 600, marginBottom: 4, color: '#A67C52'}}>3. 发布/接单</div>
              <div style={{color: '#888'}}>发布需求或接单，平台担保交易</div>
            </div>
            <div style={{minWidth: 180}}>
              <div style={{fontSize: 32, color: '#A67C52', marginBottom: 8}}>💬</div>
              <div style={{fontWeight: 600, marginBottom: 4, color: '#A67C52'}}>4. 沟通与结算</div>
              <div style={{color: '#888'}}>在线沟通，完成任务后安全结算</div>
            </div>
          </div>
        </div>
      </section>
      {/* 用户反馈/平台公告区块 */}
      <section style={{background: '#f8fbff', padding: '48px 0'}}>
        <div style={{maxWidth: 900, margin: '0 auto', textAlign: 'center'}}>
          <h3 style={{fontSize: 24, fontWeight: 700, marginBottom: 32, color: '#A67C52'}}>用户反馈 & 平台公告</h3>
          <div style={{display: 'flex', justifyContent: 'center', gap: 40, flexWrap: 'wrap'}}>
            <div style={{minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 24, marginBottom: 16, borderLeft: '6px solid #A67C52'}}>
              <div style={{fontWeight: 600, marginBottom: 8, color: '#A67C52'}}>“平台很靠谱，接单流程很顺畅！”</div>
              <div style={{color: '#888'}}>—— 用户A</div>
            </div>
            <div style={{minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 24, marginBottom: 16, borderLeft: '6px solid #8b5cf6'}}>
              <div style={{fontWeight: 600, marginBottom: 8, color: '#A67C52'}}>“任务种类多，结算也很安全。”</div>
              <div style={{color: '#888'}}>—— 用户B</div>
            </div>
            <div style={{minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 24, marginBottom: 16, borderLeft: '6px solid #A67C52'}}>
              <div style={{fontWeight: 600, marginBottom: 8, color: '#A67C52'}}>【公告】平台将于本月上线新会员功能，敬请期待！</div>
              <div style={{color: '#888'}}>2025-07-22</div>
            </div>
          </div>
        </div>
      </section>
      {/* 底部信息区块 */}
      <Footer />
      
      {/* 登录弹窗 */}
      <LoginModal 
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          // 登录成功后刷新用户状态
          window.location.reload();
        }}
        onReopen={() => {
          // 重新打开登录弹窗
          setShowLoginModal(true);
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => {
          setShowForgotPasswordModal(true);
        }}
        onHideForgotPassword={() => {
          setShowForgotPasswordModal(false);
        }}
      />
    </div>
  );
};

export default Home; 