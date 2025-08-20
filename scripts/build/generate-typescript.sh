#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
# Find the repo root by looking for .git directory
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
CODE_OUTPUT_DIR="generated/code/typescript"
OUTPUT_DIR="$PROJECT_ROOT/${CODE_OUTPUT_DIR}"
PROTO_DIR="$PROJECT_ROOT/src"
CONTAINER_NAME="protobuf-typescript-builder"
TARGET_DIR="$PROJECT_ROOT/generated/packages/typescript"
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/typescript"
PACKAGE_NAME="protos-typescript"

# Default values
NODE_VERSION="20"
GRPC_VERSION="1.9.4"
PROTOC_VERSION="25.1"
CLEAN_BUILD=false
VERBOSE=false
GENERATE_GRPC=false
GENERATE_GRPC_WEB=false

# Function to detect protoc platform
detect_protoc_platform() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "linux-x86_64"
            ;;
        aarch64|arm64)
            echo "linux-aarch_64"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

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
        if [[ -d "$TARGET_DIR" ]]; then
            rm -rf "$TARGET_DIR"
            print_success "Cleaned target directory"
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
    
    local dockerfile_path="$PROJECT_ROOT/containers/typescript/Dockerfile"
    
    if [[ ! -f "$dockerfile_path" ]]; then
        print_error "Dockerfile not found at: $dockerfile_path"
        exit 1
    fi
    
    # Detect protoc platform
    local protoc_platform=$(detect_protoc_platform)
    print_status "Detected platform: $(uname -m) -> protoc platform: $protoc_platform"
    
    if [[ "$VERBOSE" == true ]]; then
        docker build \
            --build-arg NODE_VERSION="$NODE_VERSION" \
            --build-arg GRPC_VERSION="$GRPC_VERSION" \
            --build-arg PROTOC_VERSION="$PROTOC_VERSION" \
            --build-arg PROTOC_PLATFORM="$protoc_platform" \
            -f "$dockerfile_path" \
            -t "$CONTAINER_NAME" \
            "$PROJECT_ROOT"
    else
        docker build \
            --build-arg NODE_VERSION="$NODE_VERSION" \
            --build-arg GRPC_VERSION="$GRPC_VERSION" \
            --build-arg PROTOC_VERSION="$PROTOC_VERSION" \
            --build-arg PROTOC_PLATFORM="$protoc_platform" \
            -f "$dockerfile_path" \
            -t "$CONTAINER_NAME" \
            "$PROJECT_ROOT" > /dev/null
    fi
    
    print_success "Docker image built successfully"
}

# Function to run container and generate code
generate_code() {
    print_status "Generating TypeScript/JavaScript code..."
    
    # Start container if not running
    if ! docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" ps typescript-builder | grep -q "Up"; then
        print_status "Starting TypeScript builder container..."
        docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" --profile typescript up -d typescript-builder
        sleep 2  # Wait for container to be ready
    fi
    
    # Generate TypeScript/JavaScript code using docker-compose exec
    docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" exec -T typescript-builder bash -c "
        # Find all proto files and generate TypeScript/JavaScript code
        find /workspace/src -name '*.proto' -exec /usr/bin/protoc \\
            --js_out=import_style=commonjs,binary:/workspace/${CODE_OUTPUT_DIR} \\
            --ts_out=/workspace/${CODE_OUTPUT_DIR} \\
            --proto_path=/workspace/src \\
            --proto_path=/usr/local/include \\
            {} \\;"
    
    # Generate gRPC code if requested
    if [[ "$GENERATE_GRPC" == true ]]; then
        docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" exec -T typescript-builder bash -c "
            find /workspace/src -name '*.proto' -exec npx grpc_tools_node_protoc \\
                --js_out=import_style=commonjs,binary:/workspace/${CODE_OUTPUT_DIR} \\
                --grpc_out=grpc_js:/workspace/${CODE_OUTPUT_DIR} \\
                --proto_path=/workspace/src \\
                --proto_path=/usr/local/include \\
                {} \\;"
    fi
    
    # Generate gRPC-Web code if requested
    if [[ "$GENERATE_GRPC_WEB" == true ]]; then
        docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" exec -T typescript-builder bash -c "
            find /workspace/src -name '*.proto' -exec npx grpc_tools_node_protoc \\
                --js_out=import_style=commonjs,binary:/workspace/${CODE_OUTPUT_DIR} \\
                --grpc-web_out=import_style=typescript,mode=grpcwebtext:/workspace/${CODE_OUTPUT_DIR} \\
                --proto_path=/workspace/src \\
                --proto_path=/usr/local/include \\
                {} \\;"
    fi
    
    # Post-process generated files
    docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" exec -T typescript-builder bash -c "
        # Create package structure - move all generated files to src directory
        mkdir -p /workspace/${CODE_OUTPUT_DIR}/src
        find /workspace/${CODE_OUTPUT_DIR} -maxdepth 1 -name '*.js' -exec mv {} /workspace/${CODE_OUTPUT_DIR}/src/ \; 2>/dev/null || true
        find /workspace/${CODE_OUTPUT_DIR} -maxdepth 1 -name '*.ts' -exec mv {} /workspace/${CODE_OUTPUT_DIR}/src/ \; 2>/dev/null || true
        find /workspace/${CODE_OUTPUT_DIR} -maxdepth 1 -name '*.d.ts' -exec mv {} /workspace/${CODE_OUTPUT_DIR}/src/ \; 2>/dev/null || true
        
        # Move the api directory to src
        if [ -d '/workspace/${CODE_OUTPUT_DIR}/api' ]; then
            mv /workspace/${CODE_OUTPUT_DIR}/api /workspace/${CODE_OUTPUT_DIR}/src/
        fi
        
        # Create index files
        echo 'export * from '\''./src/api/v1/helloworld'\'';' > /workspace/${CODE_OUTPUT_DIR}/index.js
        echo 'export * from '\''./src/api/v1/helloworld'\'';' > /workspace/${CODE_OUTPUT_DIR}/index.d.ts
        
        # Format generated code
        find /workspace/${CODE_OUTPUT_DIR} \( -name '*.ts' -o -name '*.js' \) | xargs npx prettier --write 2>/dev/null || true
        
        # Set permissions
        chmod -R 755 /workspace/${CODE_OUTPUT_DIR}
    "
    
    print_success "TypeScript/JavaScript code generated successfully"
}

# Function to create package using npm and build
create_package_with_npm() {
    print_status "Creating package using npm and building..."
    
    # Create package directory
    mkdir -p "${TARGET_DIR}/${PACKAGE_NAME}"
    
    # Create package.json
    cat > "$TARGET_DIR/package.json" << EOF
{
  "name": "${PACKAGE_NAME}",
  "version": "0.1.0",
  "description": "TypeScript client library generated from protobuf definitions",
  "main": "index.js",
  "types": "index.d.ts",
  "scripts": {
    "build": "tsc"
  },
  "dependencies": {
    "protobufjs": "^7.2.0",
    "@grpc/grpc-js": "^${GRPC_VERSION}",
    "@grpc/proto-loader": "^0.7.0",
    "google-protobuf": "^3.21.2"
  },
  "engines": {
    "node": ">=${NODE_VERSION}.0.0"
  }
}
EOF

    # Create tsconfig.json
    cat > "$TARGET_DIR/tsconfig.json" << EOF
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

    # Create README.md
    cat > "$TARGET_DIR/README.md" << EOF
# Protos TypeScript Package

This package contains TypeScript/JavaScript client libraries generated from protobuf definitions.

## Generated from

- Protocol Buffers version: ${PROTOC_VERSION}
- gRPC version: ${GRPC_VERSION}
- Node.js version: ${NODE_VERSION}
- gRPC generation: ${GENERATE_GRPC}
- gRPC-Web generation: ${GENERATE_GRPC_WEB}
EOF

    # Copy the module files to the target directory
    cp -r "$OUTPUT_DIR"/* "${TARGET_DIR}/"
    
    # Create dist directory
    mkdir -p "${TARGET_DIR}/dist"
    
    # Use npm to build the package
    print_status "Building package using npm..."
    cd "${TARGET_DIR}"
    npm install
    npm install --save-dev typescript @types/google-protobuf
    npm run build
    print_success "Package built successfully in dist directory"
    
    # Create npm package tarball for artifact repository
    print_status "Creating npm package tarball..."
    npm pack
    
    # Move the tarball to a packages directory for easy access
    mkdir -p "${ARTIFACT_DIR}"
    mv *.tgz "${ARTIFACT_DIR}/"
    
    print_success "npm package tarball created and moved to ${ARTIFACT_DIR} directory"
    print_success "Package creation and building completed"
}

# Function to copy generated code to target directory
copy_generated_code() {
    print_status "Copying generated code to target directory..."
    
    # Create target directory if it doesn't exist
    mkdir -p "$TARGET_DIR"
    
    # Copy all generated files from output directory to target directory
    if [ -d "$OUTPUT_DIR" ]; then
        cp -r "$OUTPUT_DIR"/* "$TARGET_DIR/"
        print_success "Generated code copied to: $TARGET_DIR"
    else
        print_error "Output directory not found: $OUTPUT_DIR"
        return 1
    fi
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up..."
    
    # Stop and remove container
    docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" stop typescript-builder > /dev/null 2>&1 || true
    docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" rm -f typescript-builder > /dev/null 2>&1 || true
    
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
    create_package_with_npm
    cleanup
    
    print_success "TypeScript/JavaScript module generation completed successfully!"
    print_status "Generated files are available in: $OUTPUT_DIR"
    print_status "Built package is available in: $TARGET_DIR"
    print_status "npm package tarball is available in: $ARTIFACT_DIR"
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
