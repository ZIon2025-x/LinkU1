import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import { useLanguage } from '../contexts/LanguageContext';
import { fetchCurrentUser, logout } from '../api';

const PrivacyPolicy: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error) {
        setUser(null);
      }
    };
    loadUser();
  }, []);

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      {/* 顶部导航栏 */}
      <header style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        background: '#fff',
        zIndex: 100,
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        borderBottom: '1px solid #e9ecef'
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          height: 60,
          maxWidth: 1200,
          margin: '0 auto',
          padding: '0 24px'
        }}>
          {/* Logo */}
          <div 
            style={{
              fontWeight: 'bold',
              fontSize: 24,
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer'
            }}
            onClick={() => navigate('/')}
          >
            Link2Ur
          </div>
          
          {/* 语言切换器和汉堡菜单 */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <LanguageSwitcher />
            <HamburgerMenu
              user={user}
              onLogout={async () => {
                try {
                  await logout();
                } catch (error) {
                  console.log('登出请求失败:', error);
                }
                window.location.reload();
              }}
              onLoginClick={() => navigate('/login')}
              systemSettings={{}}
            />
          </div>
        </div>
      </header>

      {/* 主要内容 */}
      <div style={{ paddingTop: '80px', paddingBottom: '40px' }}>
        <div style={{
          maxWidth: 800,
          margin: '0 auto',
          padding: '0 24px'
        }}>
          {/* 页面标题 */}
          <div style={{
            textAlign: 'center',
            marginBottom: '40px',
            padding: '40px 0'
          }}>
            <h1 style={{
              fontSize: '2.5rem',
              fontWeight: '800',
              color: '#1e293b',
              marginBottom: '16px',
              background: 'linear-gradient(135deg, #667eea, #764ba2)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent'
            }}>
              隐私政策
            </h1>
            <p style={{
              fontSize: '1.1rem',
              color: '#64748b',
              margin: 0
            }}>
              最后更新：2024年1月1日
            </p>
          </div>

          {/* 政策内容 */}
          <div style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '40px',
            boxShadow: '0 4px 6px rgba(0,0,0,0.05)',
            lineHeight: '1.8'
          }}>
            <div style={{ color: '#374151', fontSize: '1rem' }}>
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                1. 引言
              </h2>
              <p>
                Link2Ur平台（以下简称"我们"）非常重视您的隐私保护。本隐私政策详细说明了我们如何收集、使用、存储和保护您的个人信息。请您仔细阅读本政策，如有疑问请及时联系我们。
              </p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                2. 信息收集
              </h2>
              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                2.1 我们收集的信息类型
              </h3>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li><strong>账户信息：</strong>姓名、邮箱、手机号、密码等注册信息</li>
                <li><strong>个人资料：</strong>头像、个人简介、技能标签、工作经历等</li>
                <li><strong>交易信息：</strong>任务发布、接取、支付记录等</li>
                <li><strong>设备信息：</strong>IP地址、设备型号、操作系统、浏览器类型等</li>
                <li><strong>使用数据：</strong>访问记录、操作日志、偏好设置等</li>
                <li><strong>位置信息：</strong>基于IP地址的大致位置信息</li>
              </ul>

              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                2.2 信息收集方式
              </h3>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>您主动提供的信息（注册、填写资料等）</li>
                <li>自动收集的信息（使用服务时产生的数据）</li>
                <li>第三方平台授权获取的信息</li>
                <li>通过Cookie和类似技术收集的信息</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                3. 信息使用
              </h2>
              <p>我们收集您的个人信息用于以下目的：</p>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>提供、维护和改进我们的服务</li>
                <li>处理您的交易和支付</li>
                <li>匹配任务发布者和接取者</li>
                <li>发送重要通知和更新</li>
                <li>提供客户支持</li>
                <li>进行数据分析以改善用户体验</li>
                <li>防范欺诈和确保平台安全</li>
                <li>遵守法律法规要求</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                4. 信息共享
              </h2>
              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                4.1 我们不会出售您的个人信息
              </h3>
              <p>我们不会向第三方出售、出租或以其他方式披露您的个人信息用于商业目的。</p>

              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                4.2 信息共享情况
              </h3>
              <p>我们仅在以下情况下共享您的信息：</p>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>获得您的明确同意</li>
                <li>与可信的第三方服务提供商共享（如支付处理商）</li>
                <li>为完成交易而必要的共享</li>
                <li>法律要求或政府机关要求</li>
                <li>保护我们的权利、财产或安全</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                5. 信息存储与安全
              </h2>
              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                5.1 存储期限
              </h3>
              <p>我们仅在实现收集目的所必需的期间内保留您的个人信息，除非法律要求更长的保留期。</p>

              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                5.2 安全措施
              </h3>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>使用SSL加密技术保护数据传输</li>
                <li>采用行业标准的安全措施保护存储的数据</li>
                <li>定期进行安全审计和漏洞扫描</li>
                <li>限制员工对个人信息的访问权限</li>
                <li>建立数据泄露应急响应机制</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                6. 您的权利
              </h2>
              <p>根据相关法律法规，您享有以下权利：</p>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li><strong>访问权：</strong>了解我们收集了您的哪些个人信息</li>
                <li><strong>更正权：</strong>要求更正不准确的个人信息</li>
                <li><strong>删除权：</strong>要求删除您的个人信息</li>
                <li><strong>限制处理权：</strong>要求限制对您个人信息的处理</li>
                <li><strong>数据可携权：</strong>要求以结构化格式获取您的数据</li>
                <li><strong>反对权：</strong>反对我们处理您的个人信息</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                7. Cookie和类似技术
              </h2>
              <p>我们使用Cookie和类似技术来：</p>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>记住您的登录状态和偏好设置</li>
                <li>分析网站使用情况以改善服务</li>
                <li>提供个性化的内容和广告</li>
                <li>确保网站安全和防止欺诈</li>
              </ul>
              <p>您可以通过浏览器设置管理Cookie，但禁用Cookie可能影响某些功能的使用。</p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                8. 第三方服务
              </h2>
              <p>我们的服务可能包含第三方链接或服务，这些第三方有自己的隐私政策。我们不对第三方的隐私做法负责，建议您查看其隐私政策。</p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                9. 儿童隐私
              </h2>
              <p>我们的服务不面向13岁以下的儿童。我们不会故意收集13岁以下儿童的个人信息。如果我们发现收集了儿童的个人信息，将立即删除。</p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                10. 政策更新
              </h2>
              <p>我们可能会不时更新本隐私政策。重大变更将通过平台公告或邮件通知您。继续使用我们的服务即表示您接受更新后的政策。</p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                11. 联系我们
              </h2>
              <p>如果您对本隐私政策有任何疑问或需要行使您的权利，请通过以下方式联系我们：</p>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>邮箱：privacy@linku.com</li>
                <li>客服电话：400-123-4567</li>
                <li>在线客服：平台内客服系统</li>
                <li>邮寄地址：北京市朝阳区某某大厦1001室</li>
              </ul>

              <div style={{
                marginTop: '40px',
                padding: '20px',
                backgroundColor: '#f8f9fa',
                borderRadius: '8px',
                border: '1px solid #e9ecef'
              }}>
                <p style={{ margin: 0, fontSize: '0.9rem', color: '#6c757d' }}>
                  <strong>重要提示：</strong>本隐私政策是您与Link2Ur之间关于个人信息处理的协议。我们承诺按照本政策保护您的隐私权益。
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PrivacyPolicy;
