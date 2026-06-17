import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// 通途 Web 组件库（React + MUI）开发/构建配置。
export default defineConfig({
  plugins: [react()],
});
