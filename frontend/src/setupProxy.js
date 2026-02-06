const { createProxyMiddleware } = require('http-proxy-middleware');
module.exports = function(app) {
  // 开发环境代理到远程测试服务器
  // 这样可以避免跨域Cookie问题（特别是无痕模式）
  const target = process.env.REACT_APP_API_URL || 'https://linktest.up.railway.app';
  
  app.use(
    '/api',
    createProxyMiddleware({
      target: target,
      changeOrigin: true,
      secure: true,
      cookieDomainRewrite: '',  // 移除Cookie的domain属性，让浏览器自动使用当前域
      cookiePathRewrite: '/',   // 确保path是根路径
      onProxyRes: function(proxyRes, req, res) {
        // 处理Set-Cookie头，移除Secure标志（因为localhost是http）
        const cookies = proxyRes.headers['set-cookie'];
        if (cookies) {
          proxyRes.headers['set-cookie'] = cookies.map(cookie => {
            return cookie
              .replace(/;\s*Secure/gi, '')  // 移除Secure（localhost没有https）
              .replace(/;\s*SameSite=None/gi, '; SameSite=Lax')  // 改为Lax
              .replace(/;\s*Domain=[^;]*/gi, '');  // 移除Domain
          });
        }
      }
    })
  );
  
  app.use(
    '/ws',
    createProxyMiddleware({
      target: target,
      changeOrigin: true,
      ws: true,
    })
  );
};