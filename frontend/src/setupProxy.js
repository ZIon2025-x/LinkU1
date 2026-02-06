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
      cookieDomainRewrite: 'localhost',  // 重写Cookie域名为localhost
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