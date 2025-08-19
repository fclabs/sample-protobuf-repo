# Makefile for protobuf module generation
# This Makefile provides convenient targets for building Python and TypeScript modules

.PHONY: help all python typescript clean clean-all test validate

# Default target
help:
	@echo "Available targets:"
	@echo "  all          - Generate all modules (Python + TypeScript)"
	@echo "  python       - Generate Python modules only"
	@echo "  typescript   - Generate TypeScript/JavaScript modules only"
	@echo "  clean        - Clean generated files"
	@echo "  clean-all    - Clean all generated files and Docker images"
	@echo "  test         - Run validation tests on proto files"
	@echo "  validate     - Validate proto file syntax"
	@echo "  help         - Show this help message"

# Generate all modules
all: python typescript
	@echo "All modules generated successfully!"

# Generate Python modules only
python:
	@echo "Generating Python modules..."
	@bash scripts/build/generate-python.sh

# Generate TypeScript modules only
typescript:
	@echo "Generating TypeScript modules..."
	@bash scripts/build/generate-js.sh

# Generate TypeScript with gRPC support
typescript-grpc:
	@echo "Generating TypeScript modules with gRPC support..."
	@bash scripts/build/generate-js.sh --grpc

# Generate TypeScript with gRPC-Web support
typescript-grpc-web:
	@echo "Generating TypeScript modules with gRPC-Web support..."
	@bash scripts/build/generate-js.sh --grpc-web

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -rf generated/
	@echo "Generated files cleaned"

# Clean all generated files and Docker images
clean-all: clean
	@echo "Cleaning Docker images..."
	@docker rmi protobuf-python-builder protobuf-typescript-builder 2>/dev/null || true
	@echo "Docker images cleaned"

# Run validation tests
test:
	@echo "Running proto validation tests..."
	@bash scripts/ci/validate-proto.sh

# Validate proto file syntax
validate:
	@echo "Validating proto file syntax..."
	@bash scripts/ci/validate-proto.sh

# Development helpers
dev-setup:
	@echo "Setting up development environment..."
	@bash scripts/tools/setup-dev.sh

install-protoc:
	@echo "Installing protoc compiler..."
	@bash scripts/tools/install-protoc.sh

# Container management
containers-build:
	@echo "Building all containers..."
	@docker-compose -f containers/docker-compose.yml build

containers-up:
	@echo "Starting all containers..."
	@docker-compose -f containers/docker-compose.yml --profile all up -d

containers-down:
	@echo "Stopping all containers..."
	@docker-compose -f containers/docker-compose.yml down

containers-clean:
	@echo "Cleaning containers..."
	@docker-compose -f containers/docker-compose.yml down --rmi all --volumes --remove-orphans

containers-status:
	@echo "Container status:"
	@docker-compose -f containers/docker-compose.yml ps

containers-logs:
	@echo "Container logs:"
	@docker-compose -f containers/docker-compose.yml logs --tail=50

# CI/CD helpers
ci-build:
	@echo "Running CI build..."
	@bash scripts/build/generate-all.sh --clean --verbose

ci-test:
	@echo "Running CI tests..."
	@bash scripts/ci/validate-proto.sh
	@bash scripts/ci/check-breaking.sh

# Quick development builds
quick-python:
	@echo "Quick Python build..."
	@bash scripts/build/generate-python.sh --clean

quick-typescript:
	@echo "Quick TypeScript build..."
	@bash scripts/build/generate-js.sh --clean

# Show current status
status:
	@echo "Current repository status:"
	@echo "  Proto files: $(shell find src -name "*.proto" | wc -l | tr -d ' ') files"
	@echo "  Generated Python: $(shell if [ -d "generated/python" ]; then echo "✅"; else echo "❌"; fi)"
	@echo "  Generated TypeScript: $(shell if [ -d "generated/js" ]; then echo "✅"; else echo "❌"; fi)"
	@echo "  Docker running: $(shell if docker info >/dev/null 2>&1; then echo "✅"; else echo "❌"; fi)"
