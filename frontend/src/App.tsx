import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Home from './pages/Home';
import PublishTask from './pages/PublishTask';
import Profile from './pages/Profile';
import MessagePage from './pages/Message';
import TaskDetail from './pages/TaskDetail';
import MyTasks from './pages/MyTasks';
import Tasks from './pages/Tasks';
import UserProfile from './pages/UserProfile';
import TaskExperts from './pages/TaskExperts';
import CustomerService from './pages/CustomerService';
import CustomerServiceLogin from './pages/CustomerServiceLogin';
import AdminLogin from './pages/AdminLogin';
import AdminDashboard from './pages/AdminDashboard';
import VIP from './pages/VIP';
import Wallet from './pages/Wallet';
import Settings from './pages/Settings';
import About from './pages/About';
import JoinUs from './pages/JoinUs';
import TermsOfService from './pages/TermsOfService';
import FAQ from './pages/FAQ';
import PrivacyPolicy from './pages/PrivacyPolicy';
import Partners from './pages/Partners';
import MerchantCooperation from './pages/MerchantCooperation';
import ProtectedRoute from './components/ProtectedRoute';
import AdminRoute from './components/AdminRoute';
import CustomerServiceRoute from './components/CustomerServiceRoute';
import UserProfileRedirect from './components/UserProfileRedirect';
import ParamRedirect from './components/ParamRedirect';
import ScrollToTop from './components/ScrollToTop';
import { LanguageProvider } from './contexts/LanguageContext';
import { CookieProvider } from './contexts/CookieContext';
import { AuthProvider } from './contexts/AuthContext';
import CookieManager from './components/CookieManager';
import AdminAuth from './components/AdminAuth';
import ServiceAuth from './components/ServiceAuth';
import { AdminGuard, ServiceGuard, UserGuard } from './components/AuthGuard';
import { getLanguageFromPath, detectBrowserLanguage, DEFAULT_LANGUAGE, SUPPORTED_LANGUAGES, Language } from './utils/i18n';

// 语言重定向组件 - 优化重定向策略
const LanguageRedirect: React.FC = () => {
  const [language, setLanguage] = React.useState<Language | null>(null);

  React.useEffect(() => {
    // 检测用户语言偏好
    const detectedLanguage = detectBrowserLanguage();
    setLanguage(detectedLanguage);
    
    // 立即重定向，避免长时间加载
    const redirectPath = `/${detectedLanguage}`;
    window.location.replace(redirectPath);
  }, []);

  // 显示重定向状态
  return (
    <div style={{ 
      display: 'flex', 
      justifyContent: 'center', 
      alignItems: 'center', 
      height: '100vh',
      fontSize: '18px',
      color: '#666'
    }}>
      Redirecting to your preferred language...
    </div>
  );
};

// 语言路由组件
const LanguageRoutes: React.FC = () => {
  return (
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
    </Routes>
  );
};

function App() {
  return (
    <LanguageProvider>
      <CookieProvider>
        <AuthProvider>
          <Router>
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