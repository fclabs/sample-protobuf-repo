# Protos Repository

This repository contains Protocol Buffer (protobuf) definitions and tools to generate client libraries in multiple programming languages.

## Repository Structure

```
protos/
├── config/                 # Configuration files
├── containers/            # Docker containers for code generation
│   ├── docker-compose.yml # Docker Compose configuration
│   ├── python/           # Python builder container
│   └── typescript/       # TypeScript builder container
├── generated/             # Generated code output directory
├── packages/              # Language-specific packages
│   └── python/           # Python package with generated code
├── scripts/               # Build and generation scripts
│   └── build/            # Code generation scripts
│       ├── generate-python.sh    # Python code generation
│       └── generate-js.sh        # JavaScript/TypeScript

```

## Prerequisites

Before generating Python code, ensure you have the following installed:

- **Docker**: Required for running the build containers

## Generating Python Code

The repository provides a comprehensive script to generate Python code from protobuf definitions.

### Quick Start

```bash
# Generate Python code with default settings
./scripts/build/generate-python.sh

# Clean build (removes existing generated files)
./scripts/build/generate-python.sh --clean

# Verbose output
./scripts/build/generate-python.sh --verbose
```

### Available Options

| Option             | Description                                   | Default |
| ------------------ | --------------------------------------------- | ------- |
| `--clean`          | Clean build (remove existing generated files) | false   |
| `--verbose`        | Enable verbose output                         | false   |
| `--python-version` | Python version to use                         | 3.11    |
| `--grpc-version`   | gRPC version to use                           | 1.59.0  |
| `--protoc-version` | Protobuf compiler version                     | 25.1    |
| `--help`           | Show help message                             | -       |

### Examples

```bash
# Use Python 3.12
./scripts/build/generate-python.sh --python-version 3.12

# Use specific gRPC version
./scripts/build/generate-python.sh --grpc-version 1.60.0

# Clean build with verbose output
./scripts/build/generate-python.sh --clean --verbose
```

## What Gets Generated

The script generates the following Python files:

1. **Protobuf Messages**: `*_pb2.py` files containing message classes
2. **gRPC Services**: `*_pb2_grpc.py` files containing service stubs
3. **Type Hints**: `*_pb2.pyi` files for better IDE support
4. **Package Structure**: Proper `__init__.py` files and import organization
5. **Python Package**: Complete package with `pyproject.toml` and wheel distribution

### Generated Package Structure

```
packages/python/
├── pyproject.toml         # Package configuration
├── README.md              # Package documentation
├── dist/                  # Built wheel distribution
└── protos-python/         # Generated Python module
    ├── __init__.py
    └── api/
        └── v1/
            ├── __init__.py
            ├── helloworld_pb2.py
            ├── helloworld_pb2_grpc.py
            └── helloworld_pb2.pyi
```

## How It Works

### 1. Docker Container Setup

- Builds a custom Docker image with Python, protoc, and gRPC tools
- Mounts the source protobuf files and output directory
- Supports multiple Python versions and gRPC versions

### 2. Code Generation Process

- Scans `src/` directory for `.proto` files
- Generates Python code using `grpc_tools.protoc`
- Creates both protobuf and gRPC service files
- Generates type hint files for better IDE support

### 3. Code Quality

- Formats generated code using `black`
- Sorts imports using `isort`
- Fixes import statements for proper package structure
- Sets appropriate file permissions

### 4. Package Creation

- Creates a proper Python package structure
- Generates `pyproject.toml` with dependencies
- Builds wheel distribution using `uv` (if available)
- Places output in `packages/python/dist/`

## Using Generated Code

After generation, you can use the Python package:

```python
# Import generated protobuf messages
from protos_python.api.v1 import helloworld_pb2

# Import generated gRPC service
from protos_python.api.v1 import helloworld_pb2_grpc

# Create a request message
request = helloworld_pb2.HelloRequest(name="World")

# Use with gRPC client
channel = grpc.insecure_channel('localhost:50051')
stub = helloworld_pb2_grpc.GreeterStub(channel)
response = stub.SayHello(request)
```

## Dependencies

The generated package includes these dependencies:

- `grpcio>=1.59.0` - gRPC Python implementation
- `grpcio-tools>=1.59.0` - gRPC Python tools
- `protobuf>=4.0.0` - Protocol Buffers runtime

## Troubleshooting

### Common Issues

1. **Docker not running**: Ensure Docker is started before running the script
2. **Permission errors**: The script handles permissions automatically
3. **Missing uv**: Install uv for wheel building, or the script will skip that step
4. **Port conflicts**: The script uses Docker Compose profiles to avoid conflicts

### Clean Build

If you encounter issues, try a clean build:

```bash
./scripts/build/generate-python.sh --clean --verbose
```

This will remove all generated files and rebuild from scratch.

## Contributing

When adding new protobuf files:

1. Place them in the appropriate directory under `src/api/`
2. Follow the existing naming conventions
3. Run the generation script to update Python code
4. Test the generated code works as expected

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.
