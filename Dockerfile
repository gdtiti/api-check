# 阶段1：基础镜像准备
FROM node:18-alpine AS base

# 设置工作目录
WORKDIR /app

# 更新系统包并安装必要依赖（保留证书更新，移除镜像源配置）
RUN apk update && \
    apk add --no-cache \
      ca-certificates \
      tzdata && \
    # 设置时区（可选，根据需求保留）
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    # 更新CA证书（关键：确保SSL证书验证有效）
    update-ca-certificates && \
    # 清理缓存
    rm -rf /var/cache/apk/*

# 阶段2：构建应用程序
FROM base AS builder

WORKDIR /app

# 复制依赖描述文件
COPY package.json yarn.lock ./

# 使用官方镜像源安装依赖（移除国内镜像配置）
RUN yarn install --network-timeout 1000000

# 复制项目源代码
COPY . .

# 执行构建（根据项目实际情况修改）
RUN yarn build

# 删除开发阶段的 node_modules（减少镜像体积）
RUN rm -rf node_modules

# 设置生产环境变量
ENV NODE_ENV=production

# 安装生产依赖（可选：根据需要保留或移除 --ignore-scripts）
RUN yarn install --production --prefer-offline --network-timeout 1000000

# 清理Yarn缓存
RUN yarn cache clean --all

# 阶段3：构建最终生产镜像
FROM node:18-alpine

# 设置工作目录
WORKDIR /app

# 创建非root用户（安全最佳实践）
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

# 复制构建好的应用文件（从builder阶段拷贝）
COPY --from=builder /app/server.js /app/server.js
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/api /app/api
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/package.json /app/package.json

# 修改文件权限
RUN chown -R appuser:appgroup /app

# 设置运行时环境变量
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=13000
ENV NODE_OPTIONS="--dns-result-order=ipv4first --use-openssl-ca"

# 暴露端口
EXPOSE 13000

# 切换为非root用户运行
USER appuser

# 启动命令
CMD ["node", "server.js"]
