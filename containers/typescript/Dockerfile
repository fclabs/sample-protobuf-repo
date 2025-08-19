FROM node:18-slim

# Build arguments for configurable versions
ARG NODE_VERSION=18
ARG GRPC_VERSION=1.9.4
ARG PROTOC_VERSION=25.1
ARG GENERATE_GRPC=false
ARG GENERATE_GRPC_WEB=false

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install protoc compiler
RUN curl -L -o /tmp/protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip \
    && unzip /tmp/protoc.zip -d /usr/local \
    && rm /tmp/protoc.zip

# Set working directory
WORKDIR /workspace

# Copy package files if they exist
COPY package.json package-lock.json* ./

# Install Node.js dependencies (if package.json exists)
RUN if [ -f package.json ]; then npm ci --only=production; fi

# Install global tools
RUN npm install -g \
    protobufjs \
    @grpc/proto-loader \
    @grpc/grpc-js \
    grpc-tools \
    typescript \
    @types/node \
    prettier \
    eslint

# Copy protobuf files
COPY src/ /workspace/src/

# Create output directory
RUN mkdir -p /workspace/generated

# Set permissions
RUN chmod -R 755 /workspace/generated

# Default command
CMD ["bash"]
