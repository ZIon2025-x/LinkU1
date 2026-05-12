import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // React 单独成 chunk —— 长效缓存（version 不变就不重下）
          react: ['react', 'react-dom'],
          // 内容型 data 模块（剧情/对话/事件文案），改 UI 不动这里就能缓存
          'data-content': [
            './src/data/chatTopics.js',
            './src/data/storylines.js',
            './src/data/dailyAccidents.js',
            './src/data/dailyLife.js',
            './src/data/npcLightInteractions.js',
            './src/data/festivals.js',
            './src/data/link2ur.js',
            './src/data/endings.js',
          ],
        },
      },
    },
  },
  test: {
    environment: 'node',
    globals: false,
    include: ['tests/**/*.test.{js,jsx}'],
    setupFiles: ['./tests/setup.js'],
  },
});
