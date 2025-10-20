import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import Footer from '../components/Footer';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';

const FAQ: React.FC = () => {
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const L = (zh: string, en: string) => (language === 'zh' ? zh : en);

  const [user, setUser] = React.useState<any>(null);
  const [unreadCount, setUnreadCount] = React.useState<number>(0);
  const [showNotifications, setShowNotifications] = React.useState(false);
  const [showLoginModal, setShowLoginModal] = React.useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = React.useState(false);
  const [systemSettings, setSystemSettings] = React.useState<any>({ vip_button_visible: false });

  return (
    <div>
      {/* 顶部导航栏 - 与其他页面风格一致 */}
      <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
        <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          {/* Logo */}
          <div 
            style={{fontWeight: 'bold', fontSize: 24, background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', cursor: 'pointer'}}
            onClick={() => navigate('/')}
          >
            Link²Ur
          </div>

          {/* 语言切换、通知、菜单 */}
          <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
            <LanguageSwitcher />
            <NotificationButton
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => setShowNotifications(prev => !prev)}
            />
            <HamburgerMenu
              user={user}
              onLogout={async () => { try { /* await logout(); */ } catch (e) {} window.location.reload(); }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
            />
          </div>
        </div>
      </header>
      <div style={{height: 60}} />

      {/* 通知面板 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={[]}
        unreadCount={unreadCount}
        onMarkAsRead={() => {}}
        onMarkAllRead={() => {}}
      />

      {/* FAQ 主体 */}
      <main style={{maxWidth: 900, margin: '0 auto', padding: '24px'}}>
        <h1 style={{fontSize: 28, fontWeight: 800, marginBottom: 16, background: 'linear-gradient(135deg, #2563eb, #7c3aed)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent'}}>
          {L('常见问题（FAQ）', 'Frequently Asked Questions (FAQ)')}
        </h1>
        <p style={{color: '#64748b', marginBottom: 24}}>
          {L('我们根据近期用户反馈整理了常见问题与答案，帮助你更快上手平台。', 'We compiled common questions and answers to help you get started quickly.')}
        </p>

        <div style={{display: 'flex', flexDirection: 'column', gap: 16}}>
          {/* 任务流程 / Task Flow */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('任务流程', 'Task Flow')}</h2>
            <details open>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('平台上的任务基本流程是什么？', 'What is the basic task flow?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '1) 发布方创建任务（填写标题、预算、时间/地点等）→ 2) 服务方浏览并沟通 → 3) 双方确认细节并开始执行 → 4) 完成后进行评价与结算。',
                  '1) Poster creates a task (title, budget, time/location, etc.) → 2) Taker browses and contacts → 3) Confirm details and start → 4) Complete, review and settle.'
                )}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('如何提高匹配与成交率？', 'How to improve matching and success rate?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '尽量提供清晰需求、合理预算与可行时间窗口；及时回复消息并保持礼貌沟通；必要时补充图片或示例。',
                  'Provide clear requirements, reasonable budget and feasible time windows; reply promptly and communicate politely; add images/examples if helpful.'
                )}
              </div>
            </details>
          </section>

          {/* 取消任务 / Cancel Task */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('取消任务', 'Cancel Task')}</h2>
            <details open>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('可以取消已发布/已接的任务吗？', 'Can I cancel a posted/accepted task?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '在任务未执行或双方尚未产生实际成本前，通常可经沟通取消。请在“我的任务”中操作或与对方协商一致后取消。',
                  'Before execution or actual costs incurred, cancellation is generally allowed upon mutual agreement. Use "My Tasks" or communicate with the counterparty to cancel.'
                )}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('进行中的任务如何取消？是否需要客服审核？', 'How to cancel an in‑progress task? Is support review required?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '当任务状态为“已被接受/进行中”时（taken/in_progress），取消将进入“客服审核”。系统会为该任务创建一条“取消请求”（pending），客服审核后会“通过/驳回”。通过后任务状态将变为“已取消”。如已存在待审请求，将无法重复提交。',
                  'When a task is taken or in_progress, cancellation requires support review. The system creates a pending cancel request which will be approved/rejected by support. Upon approval, the task becomes cancelled. If a pending request already exists, duplicate submissions are blocked.'
                )}
              </div>
              <ul style={{marginTop: 8, color: '#334155', paddingLeft: 18}}>
                <li>{L('如何跟进：在消息中与对方沟通，并留意平台通知（取消请求结果会以通知形式发送）。', 'Follow‑up: communicate in Messages and watch platform notifications for the review result.')}</li>
                <li>{L('结果处理：若“通过”，双方都会收到任务取消通知；若“驳回”，可补充理由再次申请或联系邮箱 support@link2ur.com。', 'Outcomes: if approved, both parties receive cancellation notifications; if rejected, add more context and resubmit, or email support@link2ur.com.')}</li>
              </ul>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('取消是否会影响信用或评价？', 'Will cancellation affect my reputation?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '频繁或临近执行才取消可能影响评价。建议尽早沟通与说明理由，减少对方损失。',
                  'Frequent or last‑minute cancellations may affect reviews. Communicate early with reasons to minimize impact.'
                )}
              </div>
            </details>
          </section>

          {/* 任务确认与争议 / Confirmation & Disputes */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('任务确认与争议', 'Confirmation & Disputes')}</h2>
            <details open>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('对方一直未标记“同意/确认完成”怎么办？', 'What if the other party never confirms completion?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '当接受方标记“完成”后，任务进入“待确认”状态（pending_confirmation），由发布方确认。若长时间未确认，请先在消息中沟通，必要时提供完成证据（图片/聊天记录等）。若仍无结果，可联系 support@link2ur.com 由客服介入。',
                  'After the taker marks completion, the task enters pending_confirmation for the poster to confirm. If confirmation is delayed, communicate via Messages and provide evidence (photos/chat logs). If unresolved, email support@link2ur.com for assistance.'
                )}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('发布方/接受方拒绝确认怎么办？', 'What if poster/taker refuses to confirm?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '请在平台内保持沟通并尽可能收集证据；如涉及质量争议、逾期或费用变更，请详细说明。客服会基于双方信息进行裁定。',
                  'Keep communication on the platform and collect evidence. Clearly describe quality issues, delays, or pricing changes. Support will adjudicate based on both sides’ information.'
                )}
              </div>
            </details>
          </section>

          {/* 举报与安全 / Report & Safety */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('举报与安全', 'Report & Safety')}</h2>
            <details open>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('有人发布不实/违法信息怎么办？', 'What if someone posts false/illegal content?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '请截图保留证据，并通过任务页或消息界面中的反馈入口进行举报；也可发送详情至 support@link2ur.com。我们会尽快核查并处理。',
                  'Please take screenshots as evidence and report via the task page or messaging feedback entry; or email details to support@link2ur.com. We will investigate promptly.'
                )}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('遇到疑似诈骗如何处理？', 'How to handle suspected fraud?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '切勿私下转账，务必在平台内沟通与记录；发现异常立即停止交互并举报。必要时向警方报案，并向我们提供证据协助处置。',
                  'Do not transfer money privately; keep communication on‑platform. Stop interactions and report immediately if suspicious. If needed, file a police report and share evidence with us.'
                )}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('如何更好地保护自身安全？', 'How to better protect yourself?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '避免分享敏感隐私与账户信息；线下见面请选择公共场所并告知熟人；对非正常价格与要求提高警惕。',
                  'Avoid sharing sensitive personal/account info; choose public places for offline meetings and inform someone you trust; be cautious of abnormal prices and requests.'
                )}
              </div>
            </details>
          </section>
          {/* 账户与登录 / Account & Login */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('账户与登录', 'Account & Login')}</h2>
            <details open>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('无法登录/忘记密码怎么办？', 'Can’t log in / forgot password?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('请在登录弹窗选择“忘记密码”，或联系邮箱 support@link2ur.com。若浏览器禁用第三方 Cookie，可能影响登录状态，请开启或改用同一域名访问。', 'Use "Forgot password" in the login dialog, or email support@link2ur.com. If third‑party cookies are blocked, login may fail; enable cookies or access via the same site domain.')}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('为什么登录后偶尔会掉线？', 'Why do I sometimes get signed out?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('为提升安全性，我们使用短期会话与刷新机制。若频繁失效，请检查浏览器的 Cookie/隐私设置，或清理缓存后重试。', 'For security, we use short‑lived sessions with refresh. If this happens often, check your browser’s cookie/privacy settings or clear cache and try again.')}
              </div>
            </details>
          </section>

          {/* 任务发布与接单 / Task Posting & Taking */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('任务发布与接单', 'Task Posting & Taking')}</h2>
            <details open>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('如何高效发布任务？', 'How to post a task effectively?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('请完善任务标题、预算、时间范围与地点，尽量提供清晰描述；必要时添加照片或补充说明，能显著提升接单率。', 'Provide clear title, budget, time window, and location. Add photos or extra details when necessary to significantly increase responses.')}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('为何任务未获得响应？', 'Why am I not getting responses?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('尝试：适度提高预算、放宽时间窗口、完善描述与图片；同时确保联系方式可用。也可在“消息”与潜在服务者沟通。', 'Try increasing budget, widening the time window, improving description/photos, and make sure your contact works. You can also reach out via Messages.')}
              </div>
            </details>
          </section>

          {/* 消息与客服 / Messaging & Support */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('消息与客服', 'Messaging & Support')}</h2>
            <details open>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('客服在线时间与响应规则？', 'Support availability and response?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('测试阶段客服在线时段不固定。若遇紧急问题，请先在 FAQ 中查找，或发送邮件至 support@link2ur.com。', 'During testing, support hours are irregular. For urgent issues, check this FAQ first or email support@link2ur.com.')}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('消息未送达/通知不显示怎么办？', 'Messages not delivered / no notifications?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('请确认已登录且网络稳定；若浏览器屏蔽通知或 Cookie，可能导致未读数异常。刷新页面或重新登录通常可恢复。', 'Ensure you are logged in and the network is stable. Blocking notifications or cookies can affect unread counts. Refresh or re-login usually resolves it.')}
              </div>
            </details>
          </section>

          {/* 隐私与安全 / Privacy & Security */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('隐私与安全', 'Privacy & Security')}</h2>
            <details open>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('平台如何保护账户安全？', 'How do you protect account security?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('我们采用服务端会话与刷新令牌机制，并提供多重风控校验。敏感操作会进行登录状态检查与权限限制。', 'We use server sessions with refresh tokens and multi-layer risk controls. Sensitive operations require session checks and permissions.')}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('我的数据如何被使用？', 'How is my data used?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('详见《隐私政策》。我们遵循最小化收集原则，仅为提供与改进服务所必需的场景使用。', 'See the Privacy Policy. We follow data minimization and use data only to provide and improve the service.')}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('为什么我的账户被封禁或暂停？如何申诉？', 'Why is my account banned or suspended? How to appeal?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L(
                  '管理员可因违规、涉嫌诈骗、滥用平台等原因对账户执行“暂停（可设恢复时间）”或“封禁”。被暂停/封禁的账户将无法登录或受限使用。若认为处理有误，请邮件至 support@link2ur.com，附上账户信息与相关说明以便人工复核。',
                  'Admins may suspend (with optional resume time) or ban accounts for violations, suspected fraud, or abuse. Suspended/banned accounts cannot log in or are restricted. If you believe this is a mistake, email support@link2ur.com with your account info and details for manual review.'
                )}
              </div>
            </details>
          </section>

          {/* 其他 / Others */}
          <section style={{background: '#fff', borderRadius: 12, boxShadow: '0 6px 20px rgba(43,108,176,0.12)', padding: 20, border: '1px solid #e6f7ff'}}>
            <h2 style={{fontSize: 20, fontWeight: 700, marginBottom: 12}}>{L('其他', 'Others')}</h2>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('是否支持移动端？', 'Is mobile supported?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('已对移动端进行适配，建议使用现代浏览器获得更佳体验。', 'Yes. The site is mobile‑friendly; use a modern browser for best experience.')}
              </div>
            </details>
            <details>
              <summary style={{cursor: 'pointer', fontWeight: 600}}>{L('如何成为平台专家/合作方？', 'How to become an expert/partner?')}</summary>
              <div style={{marginTop: 8, color: '#334155'}}>
                {L('可通过页脚的“合作与伙伴”相关入口提交信息，或邮件联系我们。', 'Use the links in the footer (Partners / Task Experts) to submit info, or email us.')}
              </div>
            </details>
          </section>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default FAQ;


