# SPDX-FileCopyrightText: Copyright (c) 2024-2025, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast package management
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Clone NeMo Agent Toolkit
RUN git clone --depth 1 https://github.com/NVIDIA/NeMo-Agent-Toolkit.git /app/nat-mcp

WORKDIR /app/nat-mcp

# Initialize submodules (shallow)
RUN git submodule update --init --recursive --depth 1

# Create virtual environment and install NAT with MCP support
RUN uv venv --seed .venv
ENV PATH="/app/nat-mcp/.venv/bin:$PATH"
ENV VIRTUAL_ENV="/app/nat-mcp/.venv"

# Install NAT with MCP and LangChain support
RUN uv pip install -e '.[mcp,langchain]'

# Install additional dependencies for NV-Ingest integration
# Note: pymilvus[bulk_writer,model] is required for vdb_upload functionality
# - bulk_writer: minio, azure-storage-blob, and other bulk writer deps
# - model: sparse embedding functions (BM25EmbeddingFunction) used by nv-ingest-client
RUN uv pip install \
    nv-ingest-client \
    llama_index \
    llama-index-embeddings-nvidia \
    llama-index-llms-nvidia \
    llama-index-vector-stores-milvus \
    "pymilvus[bulk_writer,model]" \
    minio \
    azure-storage-blob 

# Copy the example package
COPY . /app/nvingest_mcp/
WORKDIR /app/nvingest_mcp

# Install the example package
RUN uv pip install -e .

# Set working directory back to NAT
WORKDIR /app/nat-mcp

# Default command shows help
CMD ["nat", "--help"]

