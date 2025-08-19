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
OUTPUT_DIR="$PROJECT_ROOT/generated/python"
PROTO_DIR="$PROJECT_ROOT/src"
CONTAINER_NAME="protobuf-python-builder"

# Default values
PYTHON_VERSION="3.11"
GRPC_VERSION="1.59.0"
PROTOC_VERSION="25.1"
CLEAN_BUILD=false
VERBOSE=false

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

Generate Python modules from protobuf files using containers.

OPTIONS:
    -v, --verbose       Enable verbose output
    -c, --clean         Clean build (remove existing generated files)
    --python-version    Python version to use (default: 3.11)
    --grpc-version      gRPC version to use (default: 1.59.0)
    --protoc-version    Protobuf compiler version (default: 25.1)
    -h, --help          Show this help message

EXAMPLES:
    $0                    # Generate with default settings
    $0 --clean           # Clean build
    $0 --verbose         # Verbose output
    $0 --python-version 3.12  # Use Python 3.12
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
        --python-version)
            PYTHON_VERSION="$2"
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
    print_status "Building Docker image for Python $PYTHON_VERSION..."
    
    local dockerfile_path="$PROJECT_ROOT/containers/python/Dockerfile"
    
    if [[ ! -f "$dockerfile_path" ]]; then
        print_error "Dockerfile not found at: $dockerfile_path"
        exit 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        docker build \
            --build-arg PYTHON_VERSION="$PYTHON_VERSION" \
            --build-arg GRPC_VERSION="$GRPC_VERSION" \
            --build-arg PROTOC_VERSION="$PROTOC_VERSION" \
            -f "$dockerfile_path" \
            -t "$CONTAINER_NAME" \
            "$PROJECT_ROOT"
    else
        docker build \
            --build-arg PYTHON_VERSION="$PYTHON_VERSION" \
            --build-arg GRPC_VERSION="$GRPC_VERSION" \
            --build-arg PROTOC_VERSION="$PROTOC_VERSION" \
            -f "$dockerfile_path" \
            -t "$CONTAINER_NAME" \
            "$PROJECT_ROOT" > /dev/null
    fi
    
    print_success "Docker image built successfully"
}

# Function to run container and generate code
generate_code() {
    print_status "Generating Python code..."
    
    # Start container if not running
    if ! docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" ps python-builder | grep -q "Up"; then
        print_status "Starting Python builder container..."
        docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" --profile python up -d python-builder
        sleep 2  # Wait for container to be ready
    fi
    
    # Generate Python code using docker-compose exec
    docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" exec -T python-builder bash -c "
        # Generate Python code
        python -m grpc_tools.protoc \\
            --python_out=/workspace/generated \\
            --grpc_python_out=/workspace/generated \\
            --proto_path=/workspace/src \\
            --proto_path=/usr/local/include \\
            /workspace/src/**/*.proto
        
        # Fix imports for Python packages
        find /workspace/generated -name '*.py' -exec sed -i 's/^import /from . import /g' {} \;
        
        # Format generated code
        find /workspace/generated -name '*.py' -exec black --line-length=88 --target-version=py${PYTHON_VERSION} {} \;
        
        # Sort imports
        find /workspace/generated -name '*.py' -exec isort {} \;
        
        # Create __init__.py files
        find /workspace/generated -type d -exec touch {}/__init__.py \;
        
        # Set permissions
        chmod -R 755 /workspace/generated
    "
    
    print_success "Python code generated successfully"
}

# Function to create setup.py
create_setup_py() {
    print_status "Creating setup.py for Python package..."
    
    cat > "$OUTPUT_DIR/setup.py" << EOF
#!/usr/bin/env python3
"""
Generated Python package from protobuf definitions.
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="protos-python",
    version="0.1.0",
    author="Your Organization",
    author_email="dev@yourorg.com",
    description="Python client library generated from protobuf definitions",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourorg/protos",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.8",
    install_requires=[
        "grpcio>=${GRPC_VERSION}",
        "grpcio-tools>=${GRPC_VERSION}",
        "protobuf>=4.0.0",
    ],
    extras_require={
        "dev": [
            "black",
            "isort",
            "mypy",
            "pytest",
            "pytest-asyncio",
        ],
    },
)
EOF

    print_success "setup.py created"
}

# Function to create requirements.txt
create_requirements_txt() {
    print_status "Creating requirements.txt..."
    
    cat > "$OUTPUT_DIR/requirements.txt" << EOF
# Generated requirements for protos-python package
grpcio>=${GRPC_VERSION}
grpcio-tools>=${GRPC_VERSION}
protobuf>=4.0.0
EOF

    print_success "requirements.txt created"
}

# Function to create README
create_readme() {
    print_status "Creating README.md..."
    
    cat > "$OUTPUT_DIR/README.md" << EOF
# Protos Python Package

This package contains Python client libraries generated from protobuf definitions.

## Installation

\`\`\`bash
pip install -r requirements.txt
\`\`\`

## Usage

\`\`\`python
from api.v1 import user_pb2
from api.v1 import user_pb2_grpc

# Use the generated protobuf classes
user = user_pb2.User()
user.email = "user@example.com"
\`\`\`

## Development

\`\`\`bash
pip install -e .[dev]
\`\`\`

## Generated from

- Protocol Buffers version: ${PROTOC_VERSION}
- gRPC version: ${GRPC_VERSION}
- Python version: ${PYTHON_VERSION}
EOF

    print_success "README.md created"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up..."
    
    # Stop and remove container
    docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" stop python-builder > /dev/null 2>&1 || true
    docker-compose -f "$PROJECT_ROOT/containers/docker-compose.yml" rm -f python-builder > /dev/null 2>&1 || true
    
    print_success "Cleanup completed"
}

# Main execution
main() {
    print_status "Starting Python module generation..."
    print_status "Python version: $PYTHON_VERSION"
    print_status "gRPC version: $GRPC_VERSION"
    print_status "Protoc version: $PROTOC_VERSION"
    
    # Check prerequisites
    check_docker
    
    # Execute build steps
    clean_build
    create_output_dir
    build_docker_image
    generate_code
    create_setup_py
    create_requirements_txt
    create_readme
    cleanup
    
    print_success "Python module generation completed successfully!"
    print_status "Generated files are available in: $OUTPUT_DIR"
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
