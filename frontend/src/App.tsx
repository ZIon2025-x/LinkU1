import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
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
import LanguageTest from './pages/LanguageTest';
import TermsOfService from './pages/TermsOfService';
import PrivacyPolicy from './pages/PrivacyPolicy';
import ProtectedRoute from './components/ProtectedRoute';
import AdminRoute from './components/AdminRoute';
import CustomerServiceRoute from './components/CustomerServiceRoute';
import { LanguageProvider } from './contexts/LanguageContext';

function App() {
  return (
    <LanguageProvider>
      <Router>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/tasks" element={<Tasks />} />
          <Route path="/about" element={<About />} />
          <Route path="/join-us" element={<JoinUs />} />
          <Route path="/language-test" element={<LanguageTest />} />
          <Route path="/terms" element={<TermsOfService />} />
          <Route path="/privacy" element={<PrivacyPolicy />} />
          <Route path="/publish" element={
            <ProtectedRoute>
              <PublishTask />
            </ProtectedRoute>
          } />
          <Route path="/profile" element={
            <ProtectedRoute>
              <Profile />
            </ProtectedRoute>
          } />
          <Route path="/message" element={
            <ProtectedRoute>
              <MessagePage />
            </ProtectedRoute>
          } />
          <Route path="/tasks/:id" element={<TaskDetail />} />
          <Route path="/my-tasks" element={
            <ProtectedRoute>
              <MyTasks />
            </ProtectedRoute>
          } />
          <Route path="/user/:userId" element={<UserProfile />} />
          <Route path="/task-experts" element={<TaskExperts />} />
          <Route path="/vip" element={<VIP />} />
          <Route path="/wallet" element={
            <ProtectedRoute>
              <Wallet />
            </ProtectedRoute>
          } />
          <Route path="/settings" element={
            <ProtectedRoute>
              <Settings />
            </ProtectedRoute>
          } />
          <Route path="/customer-service/login" element={<CustomerServiceLogin />} />
          <Route path="/admin/login" element={<AdminLogin />} />
          <Route path="/customer-service" element={
            <CustomerServiceRoute>
              <CustomerService />
            </CustomerServiceRoute>
          } />
          <Route path="/admin" element={
            <AdminRoute>
              <AdminDashboard />
            </AdminRoute>
          } />
        </Routes>
      </Router>
    </LanguageProvider>
  );
}

export default App;