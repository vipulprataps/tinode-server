# Multi-stage Dockerfile for Tinode server - builds from source

# Build stage
FROM golang:1.24-alpine AS builder

ARG VERSION=latest
ARG TARGET_DB=mongodb

RUN apk add --no-cache git

WORKDIR /go/src/github.com/tinode/chat

# Copy source code
COPY . .

# Build the server and tinode-db with MongoDB backend
RUN go build -tags ${TARGET_DB} -o /go/bin/tinode ./server
RUN go build -tags ${TARGET_DB} -o /go/bin/init-db ./tinode-db
RUN go build -o /go/bin/keygen ./keygen

# Runtime stage
FROM alpine:3.22

ARG TARGET_DB=mongodb
ENV TARGET_DB=$TARGET_DB

LABEL maintainer="Tinode Team <info@tinode.co>"
LABEL name="TinodeChatServer"

# Install runtime dependencies
RUN apk update && \
    apk add --no-cache ca-certificates bash grep netcat-openbsd

WORKDIR /opt/tinode

# Copy binaries from builder
COPY --from=builder /go/bin/tinode ./tinode
COPY --from=builder /go/bin/init-db ./init-db
COPY --from=builder /go/bin/keygen ./keygen

# Copy config and static files
COPY docker/tinode/config.template .
COPY docker/tinode/entrypoint.sh .
COPY tinode-db/credentials.sh .
COPY tinode-db/data.json .
COPY tinode-db/*.jpg .
COPY server/templ ./templ

# Create empty static directory
RUN mkdir -p ./static

# Environment variables
ENV WAIT_FOR=
ENV RESET_DB=false
ENV UPGRADE_DB=false
ENV NO_DB_INIT=false
ENV SAMPLE_DATA=data.json
ENV DEFAULT_COUNTRY_CODE=US

# MongoDB configuration
ENV MONGODB_URI='mongodb://localhost:27017/tinode?replicaSet=rs0'
ENV MONGODB_DATABASE=tinode

# Other environment variables
ENV PLUGIN_PYTHON_CHAT_BOT_ENABLED=false
ENV MEDIA_HANDLER=fs
ENV FS_CORS_ORIGINS='["*"]'
ENV AWS_CORS_ORIGINS='["*"]'
ENV AWS_ACCESS_KEY_ID=
ENV AWS_SECRET_ACCESS_KEY=
ENV AWS_REGION=
ENV AWS_S3_BUCKET=
ENV AWS_S3_ENDPOINT=
ENV SMTP_HOST_URL='http://localhost:6060'
ENV SMTP_SERVER=
ENV SMTP_PORT=
ENV SMTP_SENDER=
ENV SMTP_LOGIN=
ENV SMTP_PASSWORD=
ENV SMTP_AUTH_MECHANISM=
ENV SMTP_HELO_HOST=
ENV EMAIL_VERIFICATION_REQUIRED=
ENV DEBUG_EMAIL_VERIFICATION_CODE=
ENV SMTP_DOMAINS=''
ENV API_KEY_SALT=T713/rYYgW7g4m3vG6zGRh7+FM1t0T8j13koXScOAj4=
ENV AUTH_TOKEN_KEY=wfaY2RgF2S1OQI/ZlK+LSrp1KB2jwAdGAIHQ7JZn+Kc=
ENV UID_ENCRYPTION_KEY=la6YsO+bNX/+XIkOqc5Svw==
ENV TLS_ENABLED=false
ENV TLS_DOMAIN_NAME=
ENV TLS_CONTACT_ADDRESS=
ENV FCM_PUSH_ENABLED=false
ENV FCM_API_KEY=
ENV FCM_APP_ID=
ENV FCM_SENDER_ID=
ENV FCM_PROJECT_ID=
ENV FCM_VAPID_KEY=
ENV FCM_MEASUREMENT_ID=
ENV FCM_INCLUDE_ANDROID_NOTIFICATION=true
ENV TNPG_PUSH_ENABLED=false
ENV TNPG_AUTH_TOKEN=
ENV TNPG_ORG=
ENV WEBRTC_ENABLED=false
ENV ICE_SERVERS_FILE=
ENV STORE_USE_ADAPTER=mongodb
ENV SERVER_STATUS_PATH=''
ENV ACC_GC_ENABLED=false

# Create directory for chatbot data
RUN mkdir -p /botdata

# Make scripts runnable
RUN chmod +x entrypoint.sh credentials.sh

# Healthcheck
HEALTHCHECK --interval=1m --timeout=3s --start-period=30s \
  CMD nc -z localhost 6060 || exit 1

ENTRYPOINT ["./entrypoint.sh"]

EXPOSE 6060 16060 12000-12003