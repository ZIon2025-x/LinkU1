import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LocalizedLink from '../components/LocalizedLink';
import { getLanguageSwitchUrl } from '../utils/i18n';
import { useLocation } from 'react-router-dom';

const InternationalizationTest: React.FC = () => {
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const location = useLocation();

  const switchToEnglish = () => {
    const newUrl = getLanguageSwitchUrl(location.pathname, 'en');
    window.location.href = newUrl;
  };

  const switchToChinese = () => {
    const newUrl = getLanguageSwitchUrl(location.pathname, 'zh');
    window.location.href = newUrl;
  };

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '40px 20px',
      fontFamily: 'Arial, sans-serif'
    }}>
      <div style={{
        maxWidth: '800px',
        margin: '0 auto',
        background: 'white',
        borderRadius: '20px',
        padding: '40px',
        boxShadow: '0 20px 40px rgba(0,0,0,0.1)'
      }}>
        <h1 style={{ 
          textAlign: 'center', 
          marginBottom: '40px',
          color: '#333',
          fontSize: '2.5rem'
        }}>
          🌍 国际化功能测试 / Internationalization Test
        </h1>

        <div style={{ marginBottom: '30px' }}>
          <h2>当前语言 / Current Language: {language}</h2>
          <p>当前路径 / Current Path: {location.pathname}</p>
        </div>

        <div style={{ marginBottom: '30px' }}>
          <h3>语言切换 / Language Switch:</h3>
          <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
            <button 
              onClick={switchToEnglish}
              style={{
                padding: '10px 20px',
                background: language === 'en' ? '#007bff' : '#f8f9fa',
                color: language === 'en' ? 'white' : '#333',
                border: '1px solid #007bff',
                borderRadius: '5px',
                cursor: 'pointer'
              }}
            >
              English
            </button>
            <button 
              onClick={switchToChinese}
              style={{
                padding: '10px 20px',
                background: language === 'zh' ? '#007bff' : '#f8f9fa',
                color: language === 'zh' ? 'white' : '#333',
                border: '1px solid #007bff',
                borderRadius: '5px',
                cursor: 'pointer'
              }}
            >
              中文
            </button>
          </div>
        </div>

        <div style={{ marginBottom: '30px' }}>
          <h3>翻译测试 / Translation Test:</h3>
          <div style={{ background: '#f8f9fa', padding: '20px', borderRadius: '10px' }}>
            <p><strong>欢迎信息 / Welcome:</strong> {t('home.welcome')}</p>
            <p><strong>副标题 / Subtitle:</strong> {t('home.subtitle')}</p>
            <p><strong>开始使用 / Get Started:</strong> {t('home.getStarted')}</p>
            <p><strong>了解更多 / Learn More:</strong> {t('home.learnMore')}</p>
          </div>
        </div>

        <div style={{ marginBottom: '30px' }}>
          <h3>本地化链接测试 / Localized Link Test:</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <LocalizedLink 
              to="/tasks" 
              style={{ 
                color: '#007bff', 
                textDecoration: 'none',
                padding: '10px',
                background: '#f8f9fa',
                borderRadius: '5px',
                textAlign: 'center'
              }}
            >
              {t('navigation.tasks')} / 任务页面
            </LocalizedLink>
            <LocalizedLink 
              to="/about" 
              style={{ 
                color: '#007bff', 
                textDecoration: 'none',
                padding: '10px',
                background: '#f8f9fa',
                borderRadius: '5px',
                textAlign: 'center'
              }}
            >
              {t('navigation.about')} / 关于页面
            </LocalizedLink>
            <LocalizedLink 
              to="/join-us" 
              style={{ 
                color: '#007bff', 
                textDecoration: 'none',
                padding: '10px',
                background: '#f8f9fa',
                borderRadius: '5px',
                textAlign: 'center'
              }}
            >
              {t('navigation.joinUs')} / 加入我们
            </LocalizedLink>
          </div>
        </div>

        <div style={{ marginBottom: '30px' }}>
          <h3>编程式导航测试 / Programmatic Navigation Test:</h3>
          <div style={{ display: 'flex', gap: '10px' }}>
            <button 
              onClick={() => navigate('/tasks')}
              style={{
                padding: '10px 20px',
                background: '#28a745',
                color: 'white',
                border: 'none',
                borderRadius: '5px',
                cursor: 'pointer'
              }}
            >
              导航到任务页面 / Navigate to Tasks
            </button>
            <button 
              onClick={() => navigate('/about')}
              style={{
                padding: '10px 20px',
                background: '#17a2b8',
                color: 'white',
                border: 'none',
                borderRadius: '5px',
                cursor: 'pointer'
              }}
            >
              导航到关于页面 / Navigate to About
            </button>
          </div>
        </div>

        <div style={{ textAlign: 'center', marginTop: '40px' }}>
          <LocalizedLink 
            to="/" 
            style={{ 
              color: '#6c757d', 
              textDecoration: 'none',
              fontSize: '14px'
            }}
          >
            ← 返回首页 / Back to Home
          </LocalizedLink>
        </div>
      </div>
    </div>
  );
};

export default InternationalizationTest;
