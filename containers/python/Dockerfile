FROM python:3.11-slim

# Build arguments for configurable versions
ARG PYTHON_VERSION=3.11
ARG GRPC_VERSION=1.59.0
ARG PROTOC_VERSION=25.1
ARG PROTOC_PLATFORM

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install protoc compiler
RUN curl -L -o /tmp/protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-${PROTOC_PLATFORM}.zip \
    && unzip /tmp/protoc.zip -d /usr/local \
    && rm /tmp/protoc.zip

# Install Python dependencies
RUN pip install --no-cache-dir \
    grpcio==${GRPC_VERSION} \
    grpcio-tools==${GRPC_VERSION} \
    mypy-protobuf \
    black \
    isort \
    uv

# Set working directory
WORKDIR /workspace

# Copy protobuf files
COPY src/ /workspace/src/

# Create output directory
RUN mkdir -p /workspace/generated

# Set permissions
RUN chmod -R 755 /workspace/generated

# Default command
CMD ["bash"]
