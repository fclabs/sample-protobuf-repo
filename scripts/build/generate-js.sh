#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/generated/js"
PROTO_DIR="$PROJECT_ROOT/src"
CONTAINER_NAME="protobuf-typescript-builder"

# Default values
NODE_VERSION="18"
GRPC_VERSION="1.9.4"
PROTOC_VERSION="25.1"
CLEAN_BUILD=false
VERBOSE=false
GENERATE_GRPC=false
GENERATE_GRPC_WEB=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate TypeScript/JavaScript modules from protobuf files using containers.

OPTIONS:
    -v, --verbose       Enable verbose output
    -c, --clean         Clean build (remove existing generated files)
    --node-version      Node.js version to use (default: 18)
    --grpc-version      gRPC version to use (default: 1.9.4)
    --protoc-version    Protobuf compiler version (default: 25.1)
    --grpc              Generate gRPC code (default: false)
    --grpc-web          Generate gRPC-Web code (default: false)
    -h, --help          Show this help message

EXAMPLES:
    $0                    # Generate with default settings
    $0 --clean           # Clean build
    $0 --verbose         # Verbose output
    $0 --grpc            # Generate gRPC code
    $0 --grpc-web        # Generate gRPC-Web code
    $0 --node-version 20 # Use Node.js 20
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        --node-version)
            NODE_VERSION="$2"
            shift 2
            ;;
        --grpc-version)
            GRPC_VERSION="$2"
            shift 2
            ;;
        --protoc-version)
            PROTOC_VERSION="$2"
            shift 2
            ;;
        --grpc)
            GENERATE_GRPC=true
            shift
            ;;
        --grpc-web)
            GENERATE_GRPC_WEB=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to clean previous build
clean_build() {
    if [[ "$CLEAN_BUILD" == true ]]; then
        print_status "Cleaning previous build..."
        if [[ -d "$OUTPUT_DIR" ]]; then
            rm -rf "$OUTPUT_DIR"
            print_success "Cleaned output directory"
        fi
    fi
}

# Function to create output directory
create_output_dir() {
    mkdir -p "$OUTPUT_DIR"
    print_success "Created output directory: $OUTPUT_DIR"
}

# Function to build Docker image
build_docker_image() {
    print_status "Building Docker image for Node.js $NODE_VERSION..."
    
    cat > "$PROJECT_ROOT/Dockerfile.typescript" << EOF
FROM node:${NODE_VERSION}-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    unzip \\
    build-essential \\
    && rm -rf /var/lib/apt/lists/*

# Install protoc compiler
RUN curl -L -o /tmp/protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip \\
    && unzip /tmp/protoc.zip -d /usr/local \\
    && rm /tmp/protoc.zip

# Set working directory
WORKDIR /workspace

# Copy package files
COPY package.json package-lock.json* ./

# Install Node.js dependencies
RUN npm ci --only=production

# Install global tools
RUN npm install -g \\
    protobufjs \\
    @grpc/proto-loader \\
    @grpc/grpc-js \\
    grpc-tools \\
    typescript \\
    @types/node \\
    prettier \\
    eslint

# Copy protobuf files
COPY src/ /workspace/src/

# Create output directory
RUN mkdir -p /workspace/generated

# Generate JavaScript/TypeScript code
RUN npx pbjs \\
    --target static-module \\
    --wrap commonjs \\
    --out /workspace/generated/protobuf.js \\
    /workspace/src/**/*.proto

# Generate TypeScript definitions
RUN npx pbts \\
    --out /workspace/generated/protobuf.d.ts \\
    /workspace/generated/protobuf.js

EOF

    # Add gRPC generation if requested
    if [[ "$GENERATE_GRPC" == true ]]; then
        cat >> "$PROJECT_ROOT/Dockerfile.typescript" << EOF

# Generate gRPC code
RUN npx grpc_tools_node_protoc \\
    --js_out=import_style=commonjs,binary:/workspace/generated \\
    --grpc_out=grpc_js:/workspace/generated \\
    --proto_path=/workspace/src \\
    --proto_path=/usr/local/include \\
    /workspace/src/**/*.proto
EOF
    fi

    # Add gRPC-Web generation if requested
    if [[ "$GENERATE_GRPC_WEB" == true ]]; then
        cat >> "$PROJECT_ROOT/Dockerfile.typescript" << EOF

# Generate gRPC-Web code
RUN npx grpc_tools_node_protoc \\
    --js_out=import_style=commonjs,binary:/workspace/generated \\
    --grpc-web_out=import_style=typescript,mode=grpcwebtext:/workspace/generated \\
    --proto_path=/workspace/src \\
    --proto_path=/usr/local/include \\
    /workspace/src/**/*.proto
EOF
    fi

    cat >> "$PROJECT_ROOT/Dockerfile.typescript" << EOF

# Create package structure
RUN mkdir -p /workspace/generated/src \\
    && mv /workspace/generated/*.js /workspace/generated/src/ \\
    && mv /workspace/generated/*.ts /workspace/generated/src/ \\
    && mv /workspace/generated/*.d.ts /workspace/generated/src/

# Create index files
RUN echo "export * from './src/protobuf';" > /workspace/generated/index.js \\
    && echo "export * from './src/protobuf';" > /workspace/generated/index.d.ts

# Format generated code
RUN find /workspace/generated -name "*.ts" -o -name "*.js" | xargs npx prettier --write

# Set permissions
RUN chmod -R 755 /workspace/generated
EOF

    if [[ "$VERBOSE" == true ]]; then
        docker build -f "$PROJECT_ROOT/Dockerfile.typescript" -t "$CONTAINER_NAME" "$PROJECT_ROOT"
    else
        docker build -f "$PROJECT_ROOT/Dockerfile.typescript" -t "$CONTAINER_NAME" "$PROJECT_ROOT" > /dev/null
    fi
    
    print_success "Docker image built successfully"
}

# Function to run container and generate code
generate_code() {
    print_status "Generating TypeScript/JavaScript code..."
    
    # Run container and copy generated files
    docker run --rm \
        -v "$PROJECT_ROOT:/workspace" \
        "$CONTAINER_NAME" \
        bash -c "cp -r /workspace/generated/* /workspace/generated/"
    
    print_success "TypeScript/JavaScript code generated successfully"
}

# Function to create package.json
create_package_json() {
    print_status "Creating package.json for TypeScript package..."
    
    cat > "$OUTPUT_DIR/package.json" << EOF
{
  "name": "protos-typescript",
  "version": "0.1.0",
  "description": "TypeScript client library generated from protobuf definitions",
  "main": "index.js",
  "types": "index.d.ts",
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch",
    "clean": "rm -rf dist",
    "lint": "eslint src --ext .ts,.js",
    "format": "prettier --write src/**/*.{ts,js}",
    "test": "jest"
  },
  "keywords": [
    "protobuf",
    "grpc",
    "typescript",
    "javascript",
    "api",
    "client"
  ],
  "author": "Your Organization",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/yourorg/protos"
  },
  "dependencies": {
    "protobufjs": "^7.2.0",
    "@grpc/grpc-js": "^${GRPC_VERSION}",
    "@grpc/proto-loader": "^0.7.0"
  },
  "devDependencies": {
    "@types/node": "^18.0.0",
    "typescript": "^5.0.0",
    "prettier": "^3.0.0",
    "eslint": "^8.0.0",
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0"
  },
  "engines": {
    "node": ">=${NODE_VERSION}.0.0"
  }
}
EOF

    print_success "package.json created"
}

# Function to create tsconfig.json
create_tsconfig_json() {
    print_status "Creating tsconfig.json..."
    
    cat > "$OUTPUT_DIR/tsconfig.json" << EOF
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "declaration": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "node",
    "allowSyntheticDefaultImports": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  },
  "include": [
    "src/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
EOF

    print_success "tsconfig.json created"
}

# Function to create README
create_readme() {
    print_status "Creating README.md..."
    
    cat > "$OUTPUT_DIR/README.md" << EOF
# Protos TypeScript Package

This package contains TypeScript/JavaScript client libraries generated from protobuf definitions.

## Installation

\`\`\`bash
npm install
\`\`\`

## Usage

\`\`\`typescript
import { User, UserService } from './src/protobuf';

// Use the generated protobuf classes
const user = new User();
user.setEmail('user@example.com');
\`\`\`

## Development

\`\`\`bash
npm run dev      # Watch mode compilation
npm run build    # Build for production
npm run lint     # Run ESLint
npm run format   # Format with Prettier
npm test         # Run tests
\`\`\`

## Generated from

- Protocol Buffers version: ${PROTOC_VERSION}
- gRPC version: ${GRPC_VERSION}
- Node.js version: ${NODE_VERSION}
- gRPC generation: ${GENERATE_GRPC}
- gRPC-Web generation: ${GENERATE_GRPC_WEB}
EOF

    print_success "README.md created"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up..."
    
    # Remove Docker image
    docker rmi "$CONTAINER_NAME" > /dev/null 2>&1 || true
    
    # Remove Dockerfile
    rm -f "$PROJECT_ROOT/Dockerfile.typescript"
    
    print_success "Cleanup completed"
}

# Main execution
main() {
    print_status "Starting TypeScript/JavaScript module generation..."
    print_status "Node.js version: $NODE_VERSION"
    print_status "gRPC version: $GRPC_VERSION"
    print_status "Protoc version: $PROTOC_VERSION"
    print_status "Generate gRPC: $GENERATE_GRPC"
    print_status "Generate gRPC-Web: $GENERATE_GRPC_WEB"
    
    # Check prerequisites
    check_docker
    
    # Execute build steps
    clean_build
    create_output_dir
    build_docker_image
    generate_code
    create_package_json
    create_tsconfig_json
    create_readme
    cleanup
    
    print_success "TypeScript/JavaScript module generation completed successfully!"
    print_status "Generated files are available in: $OUTPUT_DIR"
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
