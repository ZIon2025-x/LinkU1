import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Login from './pages/Login';
import Register from './pages/Register';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';
import Home from './pages/Home';
import PublishTask from './pages/PublishTask';
import Profile from './pages/Profile';
import MessagePage from './pages/Message';
import TaskDetail from './pages/TaskDetail';
import MyTasks from './pages/MyTasks';
import Tasks from './pages/Tasks';
import UserProfile from './pages/UserProfile';
import CustomerService from './pages/CustomerService';
import CustomerServiceLogin from './pages/CustomerServiceLogin';
import AdminLogin from './pages/AdminLogin';
import AdminDashboard from './pages/AdminDashboard';
import VIP from './pages/VIP';
import Wallet from './pages/Wallet';
import Settings from './pages/Settings';
import About from './pages/About';
import JoinUs from './pages/JoinUs';
import ProtectedRoute from './components/ProtectedRoute';
import AdminRoute from './components/AdminRoute';
import CustomerServiceRoute from './components/CustomerServiceRoute';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/forgot-password" element={<ForgotPassword />} />
        <Route path="/reset-password/:token" element={<ResetPassword />} />
        <Route path="/" element={<Home />} />
        <Route path="/tasks" element={<Tasks />} />
        <Route path="/about" element={<About />} />
        <Route path="/join-us" element={<JoinUs />} />
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
  );
}

export default App;
