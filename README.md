# 志愿者互助社区

面向社区居民和志愿者的需求发布、接单、积分与兑换平台。

## 快速启动（Docker Compose）

```bash
cp .env.example .env
docker compose up -d --build
```

启动后访问：

- 前端：http://localhost:8233
- 后端健康检查：http://localhost:3233/api/health
- 数据库端口：localhost:5733

停止并清理容器、网络和数据卷：

```bash
docker compose down -v --remove-orphans
```

## 主要功能

- 居民互助需求发布
- 志愿者接单与服务记录
- 积分排行、礼品兑换与消息沟通

## 本地开发

前端：

```bash
cd frontend
npm install
npm run dev
```

后端：

```bash
cd backend
npm install
npm run dev
```

数据库可通过根目录的 Docker Compose 单独启动：

```bash
docker compose up -d db
```

## 技术栈

| 层级 | 技术 |
| --- | --- |
| 前端 | Vue + Vite |
| 后端 | Express |
| 数据库 | MySQL |
| 部署 | Docker Compose + Nginx |

## 项目目录结构

```text
.
├── docker-compose.yml
├── .env.example
├── .env
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── ...
├── backend/
│   ├── Dockerfile
│   └── ...
└── database/
    └── ...
```

## 环境变量

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| COMPOSE_PROJECT_NAME | Compose 项目名，避免中文目录名导致项目名为空 | gb-133 |
| DB_NAME | 数据库名称 | volunteer_db |
| DB_USER | 数据库用户 | volunteer |
| DB_PASSWORD | 数据库密码 | volunteer_pwd |
| DB_ROOT_PASSWORD | 数据库 root/superuser 密码 | volunteer_root_pwd |
| JWT_SECRET | 后端签名密钥 | volunteer_secret_key_2026 |
| FRONTEND_PORT | 前端宿主机端口 | 8233 |
| BACKEND_PORT | 后端宿主机端口 | 3233 |
| DB_PORT | 数据库宿主机端口 | 5733 |

## Docker 部署说明

- `docker-compose.yml` 顶层已声明 `name: gb-133`，可以在中文目录名下直接运行。
- 数据库使用 Docker 命名卷 `db_data` 持久化，不绑定到宿主中文路径。
- 前端容器使用 Nginx 托管静态资源，并将 `/api` 反向代理到后端服务名 `backend`。
- 后端会等待数据库健康后再启动，前端会等待后端健康后再启动。
- 如本机端口冲突，修改根目录 `.env` 中的 `FRONTEND_PORT`、`BACKEND_PORT` 或 `DB_PORT`。

## License

MIT
