import React, { Suspense, lazy } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import ProtectedRoute from './components/ProtectedRoute';
import AdminRoute from './components/AdminRoute';
import CustomerServiceRoute from './components/CustomerServiceRoute';
import UserProfileRedirect from './components/UserProfileRedirect';
import ParamRedirect from './components/ParamRedirect';
import QueryPreservingRedirect from './components/QueryPreservingRedirect';
import ScrollToTop from './components/ScrollToTop';
import FaviconManager from './components/FaviconManager';
import LanguageMetaManager from './components/LanguageMetaManager';
import { LanguageProvider } from './contexts/LanguageContext';
import { CookieProvider } from './contexts/CookieContext';
import { AuthProvider } from './contexts/AuthContext';
import CookieManager from './components/CookieManager';
import AdminAuth from './components/AdminAuth';
import ServiceAuth from './components/ServiceAuth';
import { AdminGuard, ServiceGuard, UserGuard } from './components/AuthGuard';
import { getLanguageFromPath, detectBrowserLanguage, DEFAULT_LANGUAGE, SUPPORTED_LANGUAGES, Language } from './utils/i18n';

// 懒加载组件 - 减少初始包大小，提升首屏加载速度
const Home = lazy(() => import('./pages/Home'));
const PublishTask = lazy(() => import('./pages/PublishTask'));
const Profile = lazy(() => import('./pages/Profile'));
const MessagePage = lazy(() => import('./pages/Message'));
const TaskDetail = lazy(() => import('./pages/TaskDetail'));
const MyTasks = lazy(() => import('./pages/MyTasks'));
const Tasks = lazy(() => import('./pages/Tasks'));
const UserProfile = lazy(() => import('./pages/UserProfile'));
const TaskExperts = lazy(() => import('./pages/TaskExperts'));
const CustomerService = lazy(() => import('./pages/CustomerService'));
const CustomerServiceLogin = lazy(() => import('./pages/CustomerServiceLogin'));
const AdminLogin = lazy(() => import('./pages/AdminLogin'));
const AdminDashboard = lazy(() => import('./pages/AdminDashboard'));
const VIP = lazy(() => import('./pages/VIP'));
const Wallet = lazy(() => import('./pages/Wallet'));
const Settings = lazy(() => import('./pages/Settings'));
const About = lazy(() => import('./pages/About'));
const JoinUs = lazy(() => import('./pages/JoinUs'));
const TermsOfService = lazy(() => import('./pages/TermsOfService'));
const FAQ = lazy(() => import('./pages/FAQ'));
const PrivacyPolicy = lazy(() => import('./pages/PrivacyPolicy'));
const Partners = lazy(() => import('./pages/Partners'));
const MerchantCooperation = lazy(() => import('./pages/MerchantCooperation'));
const VerifyEmail = lazy(() => import('./pages/VerifyEmail'));

// 语言重定向组件 - 使用React Router的Navigate而不是window.location
const LanguageRedirect: React.FC = () => {
  const detectedLanguage = detectBrowserLanguage();
  const redirectPath = `/${detectedLanguage}`;
  
  // 使用Navigate组件而不是window.location.replace，避免页面重新加载
  // 这样可以避免Bing爬虫遇到JavaScript重定向问题
  return <Navigate to={redirectPath} replace />;
};

// 加载中占位组件
const LoadingFallback: React.FC = () => {
  React.useEffect(() => {
    // 添加旋转动画样式
    const style = document.createElement('style');
    style.textContent = `
      @keyframes spin {
        from { transform: rotate(0deg); }
        to { transform: rotate(360deg); }
      }
      .loading-spinner {
        animation: spin 1s linear infinite;
      }
    `;
    document.head.appendChild(style);
    return () => {
      document.head.removeChild(style);
    };
  }, []);

  return (
    <div style={{
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)'
    }}>
      <div style={{
        background: '#fff',
        padding: '40px',
        borderRadius: '20px',
        boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
        textAlign: 'center'
      }}>
        <div className="loading-spinner" style={{
          fontSize: '48px',
          marginBottom: '20px',
          display: 'inline-block'
        }}>⏳</div>
        <div style={{
          fontSize: '18px',
          color: '#3b82f6',
          fontWeight: '600'
        }}>加载中...</div>
      </div>
    </div>
  );
};

// 语言路由组件
const LanguageRoutes: React.FC = () => {
  return (
    <Suspense fallback={<LoadingFallback />}>
      <Routes>
      {/* 根路径重定向到用户语言偏好或默认语言 */}
      <Route path="/" element={<LanguageRedirect />} />
      
      {/* 语言路由 */}
      {SUPPORTED_LANGUAGES.map((lang) => (
        <React.Fragment key={lang}>
          <Route path={`/${lang}`} element={<Home />} />
          <Route path={`/${lang}/tasks`} element={<Tasks />} />
          <Route path={`/${lang}/about`} element={<About />} />
              <Route path={`/${lang}/faq`} element={<FAQ />} />
          <Route path={`/${lang}/join-us`} element={<JoinUs />} />
          <Route path={`/${lang}/terms`} element={<TermsOfService />} />
          <Route path={`/${lang}/privacy`} element={<PrivacyPolicy />} />
          <Route path={`/${lang}/partners`} element={<Partners />} />
          <Route path={`/${lang}/merchant-cooperation`} element={<MerchantCooperation />} />
          <Route path={`/${lang}/publish`} element={
            <ProtectedRoute>
              <PublishTask />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/profile`} element={
            <ProtectedRoute>
              <Profile />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/message`} element={
            <ProtectedRoute>
              <MessagePage />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/tasks/:id`} element={<TaskDetail />} />
          <Route path={`/${lang}/my-tasks`} element={
            <ProtectedRoute>
              <MyTasks />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/user/:userId`} element={<UserProfile />} />
          <Route path={`/${lang}/task-experts`} element={<TaskExperts />} />
          <Route path={`/${lang}/vip`} element={<VIP />} />
          <Route path={`/${lang}/wallet`} element={
            <ProtectedRoute>
              <Wallet />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/settings`} element={
            <ProtectedRoute>
              <Settings />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/customer-service/login`} element={<CustomerServiceLogin />} />
          <Route path={`/${lang}/admin/login`} element={<AdminLogin />} />
          <Route path={`/${lang}/service/login`} element={<ServiceAuth />} />
          <Route path={`/${lang}/verify-email`} element={<VerifyEmail />} />
          <Route path={`/${lang}/admin/auth`} element={
            <AdminRoute>
              <AdminAuth />
            </AdminRoute>
          } />
          <Route path={`/${lang}/customer-service`} element={
            <CustomerServiceRoute>
              <CustomerService />
            </CustomerServiceRoute>
          } />
          <Route path={`/${lang}/admin`} element={
            <AdminRoute>
              <AdminDashboard />
            </AdminRoute>
          } />
          {/* 新的独立认证路由 */}
          <Route path={`/${lang}/service`} element={
            <ServiceGuard>
              <ServiceAuth />
            </ServiceGuard>
          } />
          <Route path={`/${lang}/admin-panel`} element={
            <AdminGuard>
              <AdminAuth />
            </AdminGuard>
          } />
        </React.Fragment>
      ))}
      
      {/* 处理没有语言前缀的旧链接 */}
      <Route path="/tasks" element={<Navigate to={`/${DEFAULT_LANGUAGE}/tasks`} replace />} />
      <Route path="/about" element={<Navigate to={`/${DEFAULT_LANGUAGE}/about`} replace />} />
      <Route path="/faq" element={<Navigate to={`/${DEFAULT_LANGUAGE}/faq`} replace />} />
      <Route path="/join-us" element={<Navigate to={`/${DEFAULT_LANGUAGE}/join-us`} replace />} />
      <Route path="/language-test" element={<Navigate to={`/${DEFAULT_LANGUAGE}/language-test`} replace />} />
      <Route path="/i18n-test" element={<Navigate to={`/${DEFAULT_LANGUAGE}/i18n-test`} replace />} />
      <Route path="/cookie-test" element={<Navigate to={`/${DEFAULT_LANGUAGE}/cookie-test`} replace />} />
      <Route path="/terms" element={<Navigate to={`/${DEFAULT_LANGUAGE}/terms`} replace />} />
      <Route path="/privacy" element={<Navigate to={`/${DEFAULT_LANGUAGE}/privacy`} replace />} />
      <Route path="/partners" element={<Navigate to={`/${DEFAULT_LANGUAGE}/partners`} replace />} />
      <Route path="/merchant-cooperation" element={<Navigate to={`/${DEFAULT_LANGUAGE}/merchant-cooperation`} replace />} />
      <Route path="/publish" element={<Navigate to={`/${DEFAULT_LANGUAGE}/publish`} replace />} />
      <Route path="/profile" element={<Navigate to={`/${DEFAULT_LANGUAGE}/profile`} replace />} />
      <Route path="/message" element={<Navigate to={`/${DEFAULT_LANGUAGE}/message`} replace />} />
      <Route path="/tasks/:id" element={<ParamRedirect basePath="/tasks/:id" />} />
      <Route path="/my-tasks" element={<Navigate to={`/${DEFAULT_LANGUAGE}/my-tasks`} replace />} />
      <Route path="/user/:userId" element={<UserProfileRedirect />} />
      <Route path="/task-experts" element={<Navigate to={`/${DEFAULT_LANGUAGE}/task-experts`} replace />} />
      <Route path="/vip" element={<Navigate to={`/${DEFAULT_LANGUAGE}/vip`} replace />} />
      <Route path="/wallet" element={<Navigate to={`/${DEFAULT_LANGUAGE}/wallet`} replace />} />
      <Route path="/settings" element={<Navigate to={`/${DEFAULT_LANGUAGE}/settings`} replace />} />
      <Route path="/customer-service/login" element={<Navigate to={`/${DEFAULT_LANGUAGE}/customer-service/login`} replace />} />
      <Route path="/admin/login" element={<Navigate to={`/${DEFAULT_LANGUAGE}/admin/login`} replace />} />
      <Route path="/customer-service" element={<Navigate to={`/${DEFAULT_LANGUAGE}/customer-service`} replace />} />
      <Route path="/admin" element={<Navigate to={`/${DEFAULT_LANGUAGE}/admin`} replace />} />
      <Route path="/verify-email" element={<QueryPreservingRedirect to={`/${DEFAULT_LANGUAGE}/verify-email`} />} />
      </Routes>
    </Suspense>
  );
};

function App() {
  return (
    <LanguageProvider>
      <CookieProvider>
        <AuthProvider>
          <Router>
            <LanguageMetaManager />
            <FaviconManager />
            <ScrollToTop />
            <LanguageRoutes />
            <CookieManager />
          </Router>
        </AuthProvider>
      </CookieProvider>
    </LanguageProvider>
  );
}

export default App;