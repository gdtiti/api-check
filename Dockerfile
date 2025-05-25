# 阶段1：基础镜像准备（Node.js 20 + 最新 CA 证书）
FROM node:20-alpine AS base
WORKDIR /app

# 系统依赖：仅保留必要的证书更新工具
RUN apk update && \
    apk add --no-cache ca-certificates && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/*

# 阶段2：构建应用程序
FROM base AS builder
WORKDIR /app

# 复制依赖文件
COPY package.json yarn.lock ./

# 使用官方镜像源安装依赖（Yarn 3+ 或 npm）
# 方案1：使用 Yarn 3+（推荐，兼容性更好）
RUN corepack enable && \
    corepack prepare yarn@stable --activate && \
    yarn install --network-timeout 1000000 --immutable

# # 方案2：改用 npm（若 Yarn 仍有问题）
# RUN npm install --production --no-audit --network-timeout 1000000

COPY . .
RUN yarn build  # 或 npm run build

# 清理开发依赖
RUN rm -rf node_modules && \
    yarn install --production --prefer-offline --network-timeout 1000000  # 仅保留生产依赖

# 阶段3：最终生产镜像
FROM node:20-alpine
WORKDIR /app

# 创建非root用户
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 复制构建结果
COPY --from=builder /app .

# 权限设置
RUN chown -R appuser:appgroup /app && \
    chmod -R ug+rX /app && \
    chmod +x /app/server.js

# 运行时配置
ENV NODE_ENV=production
ENV PORT=13000
ENV NODE_OPTIONS="--openssl-legacy-provider"  # 可选：兼容旧版 OpenSSL

USER appuser
EXPOSE 13000
CMD ["node", "server.js"]
