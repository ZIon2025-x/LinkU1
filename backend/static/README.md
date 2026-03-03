# 后端 /static 静态资源

客服/管理端请求头像等时会请求 API 域名下的 `/static/avatar1.png`、`/static/service.png` 等。

- 若此处存在对应文件，则直接返回文件。
- 若不存在，则返回 1x1 透明占位图，避免 404。

可选：将 `avatar1.png`～`avatar5.png`、`service.png` 等放入此目录（可从 frontend 或设计稿复制），以显示真实头像/图标。
