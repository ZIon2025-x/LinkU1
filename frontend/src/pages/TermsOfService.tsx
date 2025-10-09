import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import { useLanguage } from '../contexts/LanguageContext';
import { fetchCurrentUser, logout } from '../api';

const TermsOfService: React.FC = () => {
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
              用户协议
            </h1>
            <p style={{
              fontSize: '1.1rem',
              color: '#64748b',
              margin: 0
            }}>
              最后更新：2024年1月1日
            </p>
          </div>

          {/* 协议内容 */}
          <div style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '40px',
            boxShadow: '0 4px 6px rgba(0,0,0,0.05)',
            lineHeight: '1.8'
          }}>
            <div style={{ color: '#374151', fontSize: '1rem' }}>
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                1. 服务条款
              </h2>
              <p>
                欢迎使用Link2Ur平台（以下简称"本平台"）。本用户协议（以下简称"本协议"）是您与Link2Ur之间关于您使用本平台服务所订立的协议。
              </p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                2. 服务内容
              </h2>
              <p>
                Link2Ur是一个连接个人用户和企业用户的平台，提供以下服务：
              </p>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>任务发布和接取服务</li>
                <li>用户匹配和推荐服务</li>
                <li>支付和结算服务</li>
                <li>用户评价和反馈系统</li>
                <li>客户服务和技术支持</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                3. 用户权利与义务
              </h2>
              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                3.1 用户权利
              </h3>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>注册和使用本平台服务</li>
                <li>发布和接取任务</li>
                <li>获得平台提供的客户服务</li>
                <li>对平台服务提出意见和建议</li>
              </ul>

              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                3.2 用户义务
              </h3>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>提供真实、准确、完整的个人信息</li>
                <li>遵守相关法律法规和本协议条款</li>
                <li>不得发布违法、有害、虚假信息</li>
                <li>不得恶意刷单、虚假交易</li>
                <li>保护账户安全，不得转让账户</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                4. 平台权利与义务
              </h2>
              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                4.1 平台权利
              </h3>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>对用户发布的内容进行审核</li>
                <li>对违规用户进行警告、限制或封禁</li>
                <li>根据业务需要调整服务内容</li>
                <li>收取合理的平台服务费用</li>
              </ul>

              <h3 style={{ color: '#374151', fontSize: '1.2rem', marginBottom: '12px', marginTop: '24px' }}>
                4.2 平台义务
              </h3>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>提供稳定、安全的平台服务</li>
                <li>保护用户个人信息安全</li>
                <li>及时处理用户投诉和反馈</li>
                <li>建立完善的客户服务体系</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                5. 费用与支付
              </h2>
              <p>
                本平台可能对部分服务收取费用，具体收费标准将在相关页面明确标示。用户同意按照平台公布的收费标准支付相应费用。
              </p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                6. 知识产权
              </h2>
              <p>
                本平台的所有内容，包括但不限于文字、图片、音频、视频、软件、程序、版面设计等，均受知识产权法保护。未经许可，不得复制、传播或用于商业用途。
              </p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                7. 免责声明
              </h2>
              <p>
                本平台不对以下情况承担责任：
              </p>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>因不可抗力导致的服务中断</li>
                <li>用户因使用第三方服务造成的损失</li>
                <li>用户违反本协议造成的损失</li>
                <li>因网络故障、系统维护等原因造成的服务中断</li>
              </ul>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                8. 协议修改
              </h2>
              <p>
                本平台有权根据业务发展需要修改本协议。修改后的协议将在平台公布，用户继续使用服务即视为同意修改后的协议。
              </p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                9. 争议解决
              </h2>
              <p>
                因本协议产生的争议，双方应友好协商解决。协商不成的，可向有管辖权的人民法院提起诉讼。
              </p>

              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                10. 联系方式
              </h2>
              <p>
                如果您对本协议有任何疑问，请通过以下方式联系我们：
              </p>
              <ul style={{ paddingLeft: '20px', marginBottom: '20px' }}>
                <li>邮箱：info@link2ur.com</li>
                <li>客服电话：400-123-4567</li>
                <li>在线客服：平台内客服系统</li>
              </ul>

              <div style={{
                marginTop: '40px',
                padding: '20px',
                backgroundColor: '#f8f9fa',
                borderRadius: '8px',
                border: '1px solid #e9ecef'
              }}>
                <p style={{ margin: 0, fontSize: '0.9rem', color: '#6c757d' }}>
                  <strong>重要提示：</strong>请仔细阅读本协议，特别是免除或限制责任的条款。如果您不同意本协议的任何条款，请停止使用本平台服务。
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default TermsOfService;
