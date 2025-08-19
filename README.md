# Protos Repository

## Overview

This repository stores the Protocol Buffer (protobuf) `.proto` source files that define the data structures and service interfaces used across our software ecosystem. These `.proto` files serve as the single source of truth for data schemas and API contracts.

The CI/CD pipeline automatically builds and generates the necessary software modules (libraries, SDKs, and client code) from these protobuf sources, ensuring consistency and type safety across all consuming applications and services.

## Purpose

- **Centralized Schema Management**: All protobuf definitions are maintained in one location
- **Automated Code Generation**: CI/CD builds generate language-specific bindings and libraries
- **Version Control**: Track changes to data structures and API contracts over time
- **Cross-Platform Compatibility**: Support for multiple programming languages and platforms

## What Gets Built

The CI/CD pipeline processes these `.proto` files to generate:

- Language-specific client libraries
- Type definitions and interfaces
- Serialization/deserialization code
- API client SDKs
- Documentation and examples

## Repository Structure

```
protos/
├── src/                          # Protobuf source files
│   ├── api/                      # API service definitions
│   │   ├── v1/                  # API version 1
│   │   │   ├── user.proto       # User service and messages
│   │   │   ├── product.proto    # Product service and messages
│   │   │   └── order.proto      # Order service and messages
│   │   └── v2/                  # API version 2 (future)
│   ├── common/                   # Shared/common message types
│   │   ├── base.proto           # Base message types
│   │   ├── error.proto          # Error handling types
│   │   └── pagination.proto     # Pagination types
│   └── domain/                   # Domain-specific models
│       ├── user.proto           # User domain models
│       ├── product.proto        # Product domain models
│       └── order.proto          # Order domain models
├── .github/                      # GitHub-specific CI/CD
│   ├── workflows/               # GitHub Actions workflows
│   │   ├── build.yml            # Main build workflow
│   │   ├── release.yml          # Release workflow
│   │   └── test.yml             # Testing workflow
│   └── dependabot.yml           # Dependency updates
├── scripts/                      # CI/CD and utility scripts
│   ├── build/                   # Build-related scripts
│   │   ├── generate-go.sh       # Generate Go code
│   │   ├── generate-js.sh       # Generate JavaScript/TypeScript
│   │   ├── generate-python.sh   # Generate Python code
│   │   └── generate-all.sh      # Generate all languages
│   ├── ci/                      # CI/CD helper scripts
│   │   ├── validate-proto.sh    # Validate protobuf files
│   │   ├── check-breaking.sh    # Check for breaking changes
│   │   └── version-bump.sh      # Version management
│   └── tools/                   # Development tools
│       ├── install-protoc.sh    # Install protoc compiler
│       └── setup-dev.sh         # Development environment setup
├── config/                       # Configuration files
│   ├── buf.yaml                 # Buf configuration
│   ├── buf.gen.yaml             # Code generation config
│   └── buf.work.yaml            # Workspace configuration
├── generated/                    # Generated code (gitignored)
│   ├── js/                      # Generated JavaScript/TypeScript
│   ├── python/                  # Generated Python code
│   └── docs/                    # Generated documentation
├── tests/                        # Protobuf validation tests
│   ├── unit/                    # Unit tests for generated code
│   └── integration/             # Integration tests
├── docs/                         # Documentation
│   ├── api/                     # API documentation
│   ├── examples/                 # Usage examples
│   └── guides/                   # Development guides
├── Makefile                      # Build automation
├── .gitignore                   # Git ignore patterns
├── .bufignore                   # Buf ignore patterns
└── README.md                    # This file
```

### Key Directories Explained

- **`src/`**: Contains all `.proto` files organized by API version and domain
- **`.github/workflows/`**: GitHub Actions CI/CD workflows for automated builds
- **`scripts/`**: Shell scripts for building, testing, and CI/CD operations
- **`config/`**: Buf configuration files for code generation and validation
- **`generated/`**: Output directory for generated code (not committed to git)
- **`tests/`**: Test files to validate protobuf definitions and generated code
