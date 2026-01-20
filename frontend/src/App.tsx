import React, { Suspense, lazy } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ConfigProvider } from 'antd';
import { antdTheme } from './styles/theme';
import ProtectedRoute from './components/ProtectedRoute';
import UserProfileRedirect from './components/UserProfileRedirect';
import ParamRedirect from './components/ParamRedirect';
import QueryPreservingRedirect from './components/QueryPreservingRedirect';
import ScrollToTop from './components/ScrollToTop';
import FaviconManager from './components/FaviconManager';
import LanguageMetaManager from './components/LanguageMetaManager';
import OrganizationStructuredData from './components/OrganizationStructuredData';
import ErrorBoundary from './components/ErrorBoundary';
import ErrorFallback from './components/ErrorFallback';
import { LanguageProvider } from './contexts/LanguageContext';
import { CookieProvider } from './contexts/CookieContext';
import { AuthProvider } from './contexts/AuthContext';
import { UnreadMessageProvider } from './contexts/UnreadMessageContext';
import CookieManager from './components/CookieManager';
import InstallPrompt from './components/InstallPrompt';
import { detectBrowserLanguage, DEFAULT_LANGUAGE, SUPPORTED_LANGUAGES } from './utils/i18n';

// P1 优化：创建 React Query 客户端
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,  // 默认5分钟数据新鲜
      gcTime: 10 * 60 * 1000,     // 默认10分钟垃圾回收
      retry: 2,                    // 默认重试2次
      refetchOnWindowFocus: false, // 窗口聚焦时不自动重新获取
    },
  },
});

// 懒加载组件 - 减少初始包大小，提升首屏加载速度
// 添加错误处理和重试机制，防止懒加载失败导致白屏
const lazyWithRetry = (componentImport: () => Promise<any>) => {
  return lazy(async () => {
    try {
      return await componentImport();
    } catch (error) {
            // 如果加载失败，等待1秒后重试一次
      await new Promise(resolve => setTimeout(resolve, 1000));
      try {
        return await componentImport();
      } catch (retryError) {
                // 返回一个错误组件，而不是让应用崩溃
        // 直接返回 ErrorFallback 组件，它会在渲染时使用语言上下文
        return {
          default: ErrorFallback
        };
      }
    }
  });
};

const Home = lazyWithRetry(() => import('./pages/Home'));
const PublishTask = lazyWithRetry(() => import('./pages/PublishTask'));
const Profile = lazyWithRetry(() => import('./pages/Profile'));
const MessagePage = lazyWithRetry(() => import('./pages/Message'));
const TaskDetail = lazyWithRetry(() => import('./pages/TaskDetail'));
const MyTasks = lazyWithRetry(() => import('./pages/MyTasks'));
const Tasks = lazyWithRetry(() => import('./pages/Tasks'));
const UserProfile = lazyWithRetry(() => import('./pages/UserProfile'));
const TaskExperts = lazyWithRetry(() => import('./pages/TaskExperts'));
const TaskExpertsIntro = lazyWithRetry(() => import('./pages/TaskExpertsIntro'));
const TaskExpertDashboard = lazyWithRetry(() => import('./pages/TaskExpertDashboard'));
const MyServiceApplications = lazyWithRetry(() => import('./pages/MyServiceApplications'));
const VIP = lazyWithRetry(() => import('./pages/VIP'));
const Wallet = lazyWithRetry(() => import('./pages/Wallet'));
const Settings = lazyWithRetry(() => import('./pages/Settings'));
const About = lazyWithRetry(() => import('./pages/About'));
const JoinUs = lazyWithRetry(() => import('./pages/JoinUs'));
const TermsOfService = lazyWithRetry(() => import('./pages/TermsOfService'));
const FAQ = lazyWithRetry(() => import('./pages/FAQ'));
const PrivacyPolicy = lazyWithRetry(() => import('./pages/PrivacyPolicy'));
const Partners = lazyWithRetry(() => import('./pages/Partners'));
const MerchantCooperation = lazyWithRetry(() => import('./pages/MerchantCooperation'));
const VerifyEmail = lazyWithRetry(() => import('./pages/VerifyEmail'));
const ResetPassword = lazyWithRetry(() => import('./pages/ResetPassword'));
const StudentVerification = lazyWithRetry(() => import('./pages/StudentVerification'));
const TaskPayment = lazyWithRetry(() => import('./pages/TaskPayment'));
const PaymentHistory = lazyWithRetry(() => import('./pages/PaymentHistory'));
const VerifyStudentEmail = lazyWithRetry(() => import('./pages/VerifyStudentEmail'));
const FleaMarketPage = lazyWithRetry(() => import('./pages/FleaMarketPage'));
const Forum = lazyWithRetry(() => import('./pages/Forum'));
const ForumPostList = lazyWithRetry(() => import('./pages/ForumPostList'));
const ForumPostDetail = lazyWithRetry(() => import('./pages/ForumPostDetail'));
const ForumCreatePost = lazyWithRetry(() => import('./pages/ForumCreatePost'));
const ForumMyContent = lazyWithRetry(() => import('./pages/ForumMyContent'));
const ForumNotifications = lazyWithRetry(() => import('./pages/ForumNotifications'));
const ForumSearch = lazyWithRetry(() => import('./pages/ForumSearch'));
const ForumLeaderboard = lazyWithRetry(() => import('./pages/ForumLeaderboard'));
const CustomLeaderboardDetail = lazyWithRetry(() => import('./pages/CustomLeaderboardDetail'));
const LeaderboardItemDetail = lazyWithRetry(() => import('./pages/LeaderboardItemDetail'));
const FleaMarketItemDetail = lazyWithRetry(() => import('./pages/FleaMarketItemDetail'));
const ActivityDetail = lazyWithRetry(() => import('./pages/ActivityDetail'));

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
          <Route path={`/${lang}/flea-market`} element={<FleaMarketPage />} />
          <Route path={`/${lang}/flea-market/:itemId`} element={<FleaMarketItemDetail />} />
          <Route path={`/${lang}/forum`} element={<Forum />} />
          <Route path={`/${lang}/forum/category/:categoryId`} element={<ForumPostList />} />
          <Route path={`/${lang}/forum/post/:postId`} element={<ForumPostDetail />} />
          <Route path={`/${lang}/forum/create`} element={
            <ProtectedRoute>
              <ForumCreatePost />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/forum/post/:postId/edit`} element={
            <ProtectedRoute>
              <ForumCreatePost />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/forum/my`} element={
            <ProtectedRoute>
              <ForumMyContent />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/forum/notifications`} element={
            <ProtectedRoute>
              <ForumNotifications />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/forum/search`} element={<ForumSearch />} />
          <Route path={`/${lang}/forum/leaderboard`} element={<ForumLeaderboard />} />
          <Route path={`/${lang}/leaderboard/custom/:leaderboardId`} element={<CustomLeaderboardDetail />} />
          <Route path={`/${lang}/leaderboard/item/:itemId`} element={<LeaderboardItemDetail />} />
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
          <Route path={`/${lang}/activities/:id`} element={<ActivityDetail />} />
          <Route path={`/${lang}/tasks/:taskId/payment`} element={
            <ProtectedRoute>
              <TaskPayment />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/my-tasks`} element={
            <ProtectedRoute>
              <MyTasks />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/user/:userId`} element={<UserProfile />} />
          <Route path={`/${lang}/task-experts`} element={<TaskExperts />} />
          <Route path={`/${lang}/task-experts/intro`} element={<TaskExpertsIntro />} />
          <Route path={`/${lang}/task-experts/me/dashboard`} element={
            <ProtectedRoute>
              <TaskExpertDashboard />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/users/me/service-applications`} element={
            <ProtectedRoute>
              <MyServiceApplications />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/vip`} element={<VIP />} />
          <Route path={`/${lang}/wallet`} element={
            <ProtectedRoute>
              <Wallet />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/payment-history`} element={
            <ProtectedRoute>
              <PaymentHistory />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/settings`} element={
            <ProtectedRoute>
              <Settings />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/verify-email`} element={<VerifyEmail />} />
          <Route path={`/${lang}/reset-password/:token`} element={<ResetPassword />} />
          <Route path={`/${lang}/student-verification`} element={
            <ProtectedRoute>
              <StudentVerification />
            </ProtectedRoute>
          } />
          <Route path={`/${lang}/student-verification/verify/:token`} element={<VerifyStudentEmail />} />
        </React.Fragment>
      ))}
      
      {/* 处理没有语言前缀的旧链接 */}
      <Route path="/forum" element={<Navigate to={`/${DEFAULT_LANGUAGE}/forum`} replace />} />
      <Route path="/forum/*" element={<ParamRedirect basePath="/forum" />} />
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
      <Route path="/activities/:id" element={<ParamRedirect basePath="/activities/:id" />} />
      <Route path="/my-tasks" element={<Navigate to={`/${DEFAULT_LANGUAGE}/my-tasks`} replace />} />
      <Route path="/user/:userId" element={<UserProfileRedirect />} />
      <Route path="/task-experts" element={<Navigate to={`/${DEFAULT_LANGUAGE}/task-experts`} replace />} />
      <Route path="/task-experts/intro" element={<Navigate to={`/${DEFAULT_LANGUAGE}/task-experts/intro`} replace />} />
      <Route path="/task-experts/me/dashboard" element={<Navigate to={`/${DEFAULT_LANGUAGE}/task-experts/me/dashboard`} replace />} />
      <Route path="/users/me/service-applications" element={<Navigate to={`/${DEFAULT_LANGUAGE}/users/me/service-applications`} replace />} />
      <Route path="/vip" element={<Navigate to={`/${DEFAULT_LANGUAGE}/vip`} replace />} />
      <Route path="/wallet" element={<Navigate to={`/${DEFAULT_LANGUAGE}/wallet`} replace />} />
      <Route path="/settings" element={<Navigate to={`/${DEFAULT_LANGUAGE}/settings`} replace />} />
      <Route path="/verify-email" element={<QueryPreservingRedirect to={`/${DEFAULT_LANGUAGE}/verify-email`} />} />
      <Route path="/reset-password/:token" element={<ParamRedirect basePath="/reset-password/:token" />} />
      <Route path="/student-verification/verify/:token" element={<ParamRedirect basePath="/student-verification/verify/:token" />} />
      
      {/* Catch-all路由：处理未匹配的路径，重定向到首页 */}
      <Route path="*" element={<Navigate to={`/${DEFAULT_LANGUAGE}`} replace />} />
      </Routes>
    </Suspense>
  );
};

function App() {
  return (
    <ErrorBoundary
      fallback={<ErrorFallback />}
    >
      <QueryClientProvider client={queryClient}>
        <ConfigProvider theme={antdTheme}>
          <LanguageProvider>
            <CookieProvider>
              <AuthProvider>
                <UnreadMessageProvider>
                  <Router>
                    <ErrorBoundary>
                      <LanguageMetaManager />
                      <FaviconManager />
                      {/* 全局 Organization 结构化数据 - 确保所有页面都能访问 */}
                      <OrganizationStructuredData />
                      <ScrollToTop />
                      <LanguageRoutes />
                      <CookieManager />
                      <InstallPrompt />
                    </ErrorBoundary>
                  </Router>
                </UnreadMessageProvider>
              </AuthProvider>
            </CookieProvider>
          </LanguageProvider>
        </ConfigProvider>
      </QueryClientProvider>
    </ErrorBoundary>
  );
}

export default App;