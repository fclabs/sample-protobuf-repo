# Container Build Environment

This directory contains Docker containers for building protobuf modules in different programming languages.

## Structure

```
containers/
├── python/                    # Python build environment
│   └── Dockerfile            # Python 3.11 with protobuf tools
├── typescript/                # TypeScript/JavaScript build environment
│   └── Dockerfile            # Node.js 18 with protobuf tools
├── docker-compose.yml         # Docker Compose configuration
└── README.md                  # This file
```

## Available Containers

### Python Builder (`containers/python/`)

- **Base Image**: `python:3.11-slim`
- **Tools**: protoc, grpcio, grpcio-tools, mypy-protobuf
- **Code Quality**: black (formatter), isort (import sorter)
- **Output**: Python modules with proper package structure

### TypeScript Builder (`containers/typescript/`)

- **Base Image**: `node:18-slim`
- **Tools**: protoc, protobufjs, grpc-tools, typescript
- **Code Quality**: prettier (formatter), eslint (linter)
- **Output**: TypeScript/JavaScript modules with npm package structure
- **Optional**: gRPC and gRPC-Web code generation

## Build Arguments

### Python Container

- `PYTHON_VERSION`: Python version (default: 3.11)
- `GRPC_VERSION`: gRPC version (default: 1.59.0)
- `PROTOC_VERSION`: Protobuf compiler version (default: 25.1)

### TypeScript Container

- `NODE_VERSION`: Node.js version (default: 18)
- `GRPC_VERSION`: gRPC version (default: 1.9.4)
- `PROTOC_VERSION`: Protobuf compiler version (default: 25.1)
- `GENERATE_GRPC`: Enable gRPC code generation (default: false)
- `GENERATE_GRPC_WEB`: Enable gRPC-Web code generation (default: false)

## Usage

### Using Docker Compose

```bash
# Build containers
docker-compose build

# Start containers (they will run with sleep infinity)
docker-compose --profile python up -d python-builder
docker-compose --profile typescript up -d typescript-builder
docker-compose --profile typescript-grpc up -d typescript-grpc-builder
docker-compose --profile all up -d

# Execute commands in running containers
docker-compose exec python-builder bash
docker-compose exec typescript-builder bash

# Stop containers
docker-compose down
```

### Using Docker Directly

```bash
# Build Python container
docker build \
  --build-arg PYTHON_VERSION=3.12 \
  --build-arg GRPC_VERSION=1.60.0 \
  -f containers/python/Dockerfile \
  -t protobuf-python-builder .

# Build TypeScript container with gRPC
docker build \
  --build-arg NODE_VERSION=20 \
  --build-arg GENERATE_GRPC=true \
  -f containers/typescript/Dockerfile \
  -t protobuf-typescript-grpc-builder .
```

### Using Build Scripts

The build scripts automatically use these containers:

```bash
# Generate Python modules
./scripts/build/generate-python.sh

# Generate TypeScript modules
./scripts/build/generate-js.sh

# Generate all modules
./scripts/build/generate-all.sh
```

## Container Features

### Python Container

- ✅ Protocol Buffer compiler (protoc)
- ✅ gRPC Python tools
- ✅ Code formatting (black)
- ✅ Import sorting (isort)
- ✅ Type checking support (mypy-protobuf)
- ✅ Package structure generation

### TypeScript Container

- ✅ Protocol Buffer compiler (protoc)
- ✅ ProtobufJS library
- ✅ TypeScript compiler
- ✅ Code formatting (prettier)
- ✅ Optional gRPC support
- ✅ Optional gRPC-Web support
- ✅ npm package generation

## Build Process

The containers are designed to run continuously with `sleep infinity` and execute build commands via `docker-compose exec`. This approach provides several benefits:

- **Persistent containers**: No need to rebuild containers for each build
- **Faster builds**: Containers stay warm between builds
- **Better debugging**: Can inspect running containers
- **Resource efficiency**: Reuse container instances
- **CI/CD friendly**: Containers can be pre-started and reused

### Build Flow

1. **Container Startup**: Containers start with `sleep infinity` command
2. **Build Execution**: Scripts use `docker-compose exec` to run build commands
3. **Code Generation**: Protobuf compilation and code formatting happen in running containers
4. **Cleanup**: Containers are stopped and removed after build completion

## Customization

### Adding New Language Support

1. Create a new directory: `containers/<language>/`
2. Add a `Dockerfile` with the build environment
3. Update `docker-compose.yml` with the new service
4. Create a build script in `scripts/build/`

### Modifying Existing Containers

1. Edit the Dockerfile in the appropriate container directory
2. Update build arguments if needed
3. Rebuild the container: `docker-compose build <service-name>`

## Troubleshooting

### Common Issues

1. **Container build fails**: Check that all build arguments are valid
2. **Permission denied**: Ensure Docker has access to the project directory
3. **Out of memory**: Increase Docker memory limits in Docker Desktop
4. **Network issues**: Check that Docker network is accessible

### Debugging

```bash
# Run container interactively
docker run -it --rm protobuf-python-builder bash

# Check container logs
docker-compose logs python-builder

# Inspect container
docker inspect protobuf-python-builder
```

## Best Practices

1. **Version Pinning**: Always specify exact versions for reproducible builds
2. **Multi-stage Builds**: Consider using multi-stage builds for smaller images
3. **Layer Caching**: Order Dockerfile commands to maximize cache usage
4. **Security**: Use minimal base images and remove unnecessary packages
5. **Documentation**: Keep Dockerfiles and build arguments well-documented
