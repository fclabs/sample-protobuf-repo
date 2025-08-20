FROM node:18-slim

# Build arguments for configurable versions
ARG NODE_VERSION=20
ARG GRPC_VERSION=1.9.4
ARG PROTOC_VERSION=25.1
ARG GENERATE_GRPC=false
ARG GENERATE_GRPC_WEB=false

# Install system dependencies
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*


# Set working directory
WORKDIR /workspace

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

# Install protoc plugins
RUN npm install -g \
    protoc-gen-js \
    protoc-gen-ts

# Create output directory
RUN mkdir -p /workspace/generated

# Set permissions
RUN chmod -R 755 /workspace/generated

# Default command
CMD ["bash"]
