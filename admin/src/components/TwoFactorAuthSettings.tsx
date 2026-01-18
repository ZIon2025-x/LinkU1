import React, { useState, useEffect } from 'react';
import { Modal, Button, Input, message, Typography, Space, Alert, Divider } from 'antd';
import { SafetyOutlined, QrcodeOutlined, ReloadOutlined, StopOutlined } from '@ant-design/icons';
import { get2FASetup, verify2FASetup, get2FAStatus, disable2FA, regenerate2FABackupCodes } from '../api';
import { getErrorMessage } from '../utils/errorHandler';

const { Title, Text, Paragraph } = Typography;

interface TwoFactorAuthSettingsProps {
  visible: boolean;
  onClose: () => void;
}

const TwoFactorAuthSettings: React.FC<TwoFactorAuthSettingsProps> = ({ visible, onClose }) => {
  const [loading, setLoading] = useState(false);
  const [statusLoading, setStatusLoading] = useState(true);
  const [enabled, setEnabled] = useState(false);
  const [setupData, setSetupData] = useState<any>(null);
  const [verificationCode, setVerificationCode] = useState('');
  const [showDisableModal, setShowDisableModal] = useState(false);
  const [disablePassword, setDisablePassword] = useState('');
  const [disableTotpCode, setDisableTotpCode] = useState('');
  const [backupCodes, setBackupCodes] = useState<string[]>([]);
  const [showBackupCodes, setShowBackupCodes] = useState(false);

  // 加载 2FA 状态
  useEffect(() => {
    if (visible) {
      load2FAStatus();
    }
  }, [visible]);

  const load2FAStatus = async () => {
    setStatusLoading(true);
    try {
      const status = await get2FAStatus();
      setEnabled(status.enabled || false);
      
      // 如果未启用，获取设置信息
      if (!status.enabled) {
        await loadSetupData();
      }
    } catch (error) {
      message.error('加载 2FA 状态失败: ' + getErrorMessage(error));
    } finally {
      setStatusLoading(false);
    }
  };

  const loadSetupData = async () => {
    try {
      const data = await get2FASetup();
      setSetupData(data);
    } catch (error) {
      message.error('获取 2FA 设置信息失败: ' + getErrorMessage(error));
    }
  };

  const handleVerifySetup = async () => {
    if (!verificationCode || verificationCode.length !== 6 || !/^\d+$/.test(verificationCode)) {
      message.error('请输入 6 位数字验证码');
      return;
    }

    if (!setupData?.secret) {
      message.error('设置信息无效，请刷新重试');
      return;
    }

    setLoading(true);
    try {
      const result = await verify2FASetup(setupData.secret, verificationCode);
      setEnabled(true);
      setBackupCodes(result.backup_codes || []);
      setShowBackupCodes(true);
      setVerificationCode('');
      setSetupData(null);
      message.success('2FA 已成功启用！');
    } catch (error) {
      message.error('验证失败: ' + getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  };

  const handleDisable = async () => {
    if (!disablePassword && !disableTotpCode && !disableTotpCode) {
      message.error('请输入密码、TOTP 代码或备份代码');
      return;
    }

    setLoading(true);
    try {
      await disable2FA(disablePassword || undefined, disableTotpCode || undefined, undefined);
      setEnabled(false);
      setShowDisableModal(false);
      setDisablePassword('');
      setDisableTotpCode('');
      message.success('2FA 已成功禁用');
      // 重新加载设置信息
      await loadSetupData();
    } catch (error) {
      message.error('禁用失败: ' + getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  };

  const handleRegenerateBackupCodes = async () => {
    setLoading(true);
    try {
      const result = await regenerate2FABackupCodes();
      setBackupCodes(result.backup_codes || []);
      setShowBackupCodes(true);
      message.success('备份代码已重新生成');
    } catch (error) {
      message.error('重新生成备份代码失败: ' + getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Modal
        title={
          <Space>
            <SafetyOutlined />
            <span>双因素认证 (2FA) 设置</span>
          </Space>
        }
        open={visible}
        onCancel={onClose}
        footer={null}
        width={600}
      >
        {statusLoading ? (
          <div style={{ textAlign: 'center', padding: '40px 0' }}>
            <Text>加载中...</Text>
          </div>
        ) : enabled ? (
          <div>
            <Alert
              message="2FA 已启用"
              description="您的账户已启用双因素认证，登录时需要输入验证码。"
              type="success"
              showIcon
              style={{ marginBottom: 24 }}
            />

            <Space direction="vertical" style={{ width: '100%' }} size="large">
              <div>
                <Title level={5}>备份代码</Title>
                <Paragraph type="secondary">
                  如果丢失了 Authenticator 设备，可以使用备份代码登录。请妥善保存这些代码。
                </Paragraph>
                {showBackupCodes && backupCodes.length > 0 ? (
                  <div style={{
                    background: '#f5f5f5',
                    padding: 16,
                    borderRadius: 4,
                    marginTop: 12
                  }}>
                    <div style={{
                      display: 'grid',
                      gridTemplateColumns: 'repeat(2, 1fr)',
                      gap: 8,
                      fontFamily: 'monospace',
                      fontSize: 16
                    }}>
                      {backupCodes.map((code, index) => (
                        <div key={index} style={{ padding: 8, background: '#fff', borderRadius: 4 }}>
                          {code}
                        </div>
                      ))}
                    </div>
                    <Button
                      type="link"
                      onClick={handleRegenerateBackupCodes}
                      loading={loading}
                      style={{ marginTop: 12 }}
                    >
                      <ReloadOutlined /> 重新生成备份代码
                    </Button>
                  </div>
                ) : (
                  <Button
                    onClick={handleRegenerateBackupCodes}
                    loading={loading}
                    style={{ marginTop: 12 }}
                  >
                    <ReloadOutlined /> 生成备份代码
                  </Button>
                )}
              </div>

              <Divider />

              <Button
                danger
                icon={<StopOutlined />}
                onClick={() => setShowDisableModal(true)}
                block
              >
                禁用 2FA
              </Button>
            </Space>
          </div>
        ) : (
          <div>
            <Alert
              message="2FA 未启用"
              description="启用双因素认证可以大大提高账户安全性。"
              type="info"
              showIcon
              style={{ marginBottom: 24 }}
            />

            {setupData ? (
              <Space direction="vertical" style={{ width: '100%' }} size="large">
                <div>
                  <Title level={5}>步骤 1: 扫描 QR 码</Title>
                  <Paragraph type="secondary">
                    使用 Google Authenticator、Microsoft Authenticator 或其他 TOTP 应用扫描以下 QR 码：
                  </Paragraph>
                  <div style={{ textAlign: 'center', margin: '20px 0' }}>
                    <img
                      src={setupData.qr_code}
                      alt="2FA QR Code"
                      style={{
                        maxWidth: '100%',
                        border: '1px solid #d9d9d9',
                        borderRadius: 4,
                        padding: 8
                      }}
                    />
                  </div>
                </div>

                <div>
                  <Title level={5}>步骤 2: 手动输入密钥（可选）</Title>
                  <Paragraph type="secondary">
                    如果无法扫描 QR 码，可以手动输入以下密钥：
                  </Paragraph>
                  <Input
                    value={setupData.secret}
                    readOnly
                    style={{ fontFamily: 'monospace' }}
                  />
                </div>

                <Divider />

                <div>
                  <Title level={5}>步骤 3: 验证设置</Title>
                  <Paragraph type="secondary">
                    在 Authenticator 应用中输入 6 位验证码以确认设置：
                  </Paragraph>
                  <Input
                    prefix={<QrcodeOutlined />}
                    placeholder="000000"
                    maxLength={6}
                    value={verificationCode}
                    onChange={(e) => {
                      const value = e.target.value.replace(/\D/g, '');
                      setVerificationCode(value);
                    }}
                    style={{
                      fontSize: 20,
                      textAlign: 'center',
                      letterSpacing: 8,
                      fontFamily: 'monospace',
                      marginTop: 12
                    }}
                  />
                  <Button
                    type="primary"
                    block
                    onClick={handleVerifySetup}
                    loading={loading}
                    disabled={verificationCode.length !== 6}
                    style={{ marginTop: 16 }}
                  >
                    验证并启用 2FA
                  </Button>
                </div>
              </Space>
            ) : (
              <Button
                type="primary"
                icon={<SafetyOutlined />}
                onClick={loadSetupData}
                block
              >
                开始设置 2FA
              </Button>
            )}
          </div>
        )}
      </Modal>

      {/* 禁用 2FA 确认对话框 */}
      <Modal
        title="禁用 2FA"
        open={showDisableModal}
        onCancel={() => {
          setShowDisableModal(false);
          setDisablePassword('');
          setDisableTotpCode('');
        }}
        onOk={handleDisable}
        confirmLoading={loading}
        okText="确认禁用"
        okButtonProps={{ danger: true }}
      >
        <Alert
          message="警告"
          description="禁用 2FA 会降低账户安全性。请使用以下任一方式验证身份："
          type="warning"
          showIcon
          style={{ marginBottom: 16 }}
        />
        <Space direction="vertical" style={{ width: '100%' }} size="middle">
          <div>
            <Text strong>方式 1: 使用密码</Text>
            <Input.Password
              placeholder="请输入密码"
              value={disablePassword}
              onChange={(e) => setDisablePassword(e.target.value)}
              style={{ marginTop: 8 }}
            />
          </div>
          <div>
            <Text strong>方式 2: 使用 TOTP 代码</Text>
            <Input
              placeholder="请输入 6 位验证码"
              maxLength={6}
              value={disableTotpCode}
              onChange={(e) => {
                const value = e.target.value.replace(/\D/g, '');
                setDisableTotpCode(value);
              }}
              style={{
                marginTop: 8,
                fontFamily: 'monospace',
                textAlign: 'center',
                fontSize: 18,
                letterSpacing: 4
              }}
            />
          </div>
        </Space>
      </Modal>
    </>
  );
};

export default TwoFactorAuthSettings;
