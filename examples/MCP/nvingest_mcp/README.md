# NV-Ingest + NeMo Agent Toolkit (NAT) Integration

Expose NV-Ingest document processing as MCP tools for AI agents.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              3 MODES OF OPERATION                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  MODE 1: Direct Agent              MODE 2: MCP Server    MODE 3: MCP Client │
│  (nvingest_agent_direct.yml)       (nvingest_mcp_server) (nvingest_mcp_client)
│                                                                             │
│  ┌──────────────┐                  ┌──────────────┐      ┌──────────────┐  │
│  │  NAT Agent   │                  │  MCP Server  │◄────►│  MCP Client  │  │
│  │  + Tools     │                  │  port 9901   │      │  (any app)   │  │
│  └──────┬───────┘                  └──────┬───────┘      └──────────────┘  │
│         │                                 │                                 │
│         ▼                                 ▼                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         SHARED BACKEND SERVICES                       │  │
│  │  NV-Ingest (7670)  │  Milvus (19530)  │  Embedding (8012)  │  MinIO   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

Your NV-Ingest stack must be running:
- NV-Ingest microservice on port 7670
- Milvus on port 19530  
- Embedding service on port 8012
- MinIO on port 9000

Set your API key:
```bash
export NVIDIA_API_KEY=<your_key>
```

## Installation

### Option A: Using Docker (Recommended)

```bash
cd examples/nvingest_mcp

# Build container with all dependencies
docker compose build

# Start container (runs in background)
docker compose up -d

# Get a shell inside the container
docker compose exec nat bash

# Now run NAT commands inside...
```

### Option B: Local Install

```bash
# Install NAT with MCP support
cd /path/to/NeMo-Agent-Toolkit
uv venv --seed .venv && source .venv/bin/activate
uv pip install -e '.[mcp,langchain]'

# Install this example
cd /path/to/nv-ingest-lib-mode/examples/nvingest_mcp
pip install -e .
```

---

## Mode 1: Direct Agent (Simplest)

Tools defined directly in YAML. Lowest latency, single process.

### Run the Workflow

```bash
# Inside Docker container (working dir is /app/nat-mcp)
nat run \
    --config_file /app/nvingest_mcp/configs/nvingest_agent_direct.yml \
    --input "Ingest /app/nv-ingest-lib-mode/embedded_table.pdf into the vector database"
```

### Example Queries

```bash
# Ingest a document
nat run --config_file /app/nvingest_mcp/configs/nvingest_agent_direct.yml \
    --input "Ingest /app/nv-ingest-lib-mode/multimodal_test.pdf into the vector database"

# Search the knowledge base
nat run --config_file /app/nvingest_mcp/configs/nvingest_agent_direct.yml \
    --input "Search for information about tables and charts"

# Combined workflow
nat run --config_file /app/nvingest_mcp/configs/nvingest_agent_direct.yml \
    --input "What animals are mentioned in the documents?"
```

---

## Mode 2: MCP Server

Expose tools as MCP endpoints for external clients.

### Start the Server

```bash
# Inside Docker container
nat mcp serve \
    --config_file /app/nvingest_mcp/configs/nvingest_mcp_server.yml \
    --host 0.0.0.0 \
    --port 9901
```

Server will be available at: `http://localhost:9901/mcp`

### Verify Server is Running

```bash
# Check health
curl http://localhost:9901/health

# List available tools
curl http://localhost:9901/debug/tools/list | jq

# Ping via MCP protocol
nat mcp client ping --url http://localhost:9901/mcp

# List tools via MCP protocol  
nat mcp client tool list --url http://localhost:9901/mcp
```

### Call Tools Directly (No LLM)

```bash
# Call semantic_search tool
nat mcp client tool call semantic_search \
    --url http://localhost:9901/mcp \
    --json-args '{"query": "What is the dog doing?"}'

# Call document_ingest_vdb tool
nat mcp client tool call document_ingest_vdb \
    --url http://localhost:9901/mcp \
    --json-args '{"file_path": "/path/to/document.pdf"}'
```

---

## Mode 3: MCP Client

Connect to the MCP server from another workflow.

### Step 1: Start the MCP Server (Terminal 1)

```bash
# Inside Docker container
nat mcp serve \
    --config_file /app/nvingest_mcp/configs/nvingest_mcp_server.yml \
    --host 0.0.0.0
```

### Step 2: Run the MCP Client Workflow (Terminal 2)

```bash
# Inside Docker container (new terminal)
nat run \
    --config_file /app/nvingest_mcp/configs/nvingest_mcp_client.yml \
    --input "Search for information about animals"
```

### Example Queries via MCP Client

```bash
# Search via MCP
nat run --config_file /app/nvingest_mcp/configs/nvingest_mcp_client.yml \
    --input "What tables are in the knowledge base?"

# Ingest via MCP
nat run --config_file /app/nvingest_mcp/configs/nvingest_mcp_client.yml \
    --input "Ingest /app/nv-ingest-lib-mode/multimodal_test.pdf into the database"
```

---

## File Structure

```
nvingest_mcp/
├── configs/
│   ├── nvingest_agent_direct.yml   # Mode 1: Direct agent with tools
│   ├── nvingest_mcp_server.yml     # Mode 2: MCP server exposing tools
│   └── nvingest_mcp_client.yml     # Mode 3: MCP client consuming tools
├── src/nvingest_mcp/
│   └── register.py                  # Custom NAT functions (the core code)
├── Dockerfile                       # Container with NAT + dependencies
├── docker-compose.yml               # Container runtime config
├── run.sh                           # Helper script (optional)
└── pyproject.toml                   # Package definition
```

## Capabilities

This integration enables AI agents to:

- **Ingest documents**: Process PDFs, extract text, tables, charts, and images
- **Build knowledge bases**: Automatically embed and store documents in Milvus VDB
- **Semantic search**: Query the knowledge base using natural language
- **RAG workflows**: Combine retrieval with LLM reasoning for document Q&A

### Extraction Options

Configure what to extract from documents:

| Option | Description | NIM Service Used |
|--------|-------------|------------------|
| `extract_text` | Plain text content | Built-in |
| `extract_tables` | Structured table data | table-structure (port 8006) |
| `extract_charts` | Chart/graphic descriptions | graphic-elements (port 8003) |
| `extract_images` | Image content | page-elements (port 8000) |

Set these in your config YAML:

```yaml
document_ingest_vdb:
  extract_text: true
  extract_tables: true    # Enable table extraction
  extract_charts: true    # Enable chart extraction
  extract_images: false   # Disable image extraction
```

---

## Available Tools

### 1. `document_ingest` - Extract Content (No VDB)

Extracts content from documents and returns it directly. Use for inspection or custom processing.

**Input:**
- `file_path`: Path to the document (PDF, DOCX, etc.)

**Output:** Extracted text/tables/charts as formatted string

**Example:**
```bash
nat mcp client tool call document_ingest \
    --url http://localhost:9901/mcp \
    --json-args '{"file_path": "/app/nv-ingest-lib-mode/multimodal_test.pdf"}'
```

---

### 2. `document_ingest_vdb` - Extract + Embed + Upload

Full pipeline: extracts content, generates embeddings, uploads to Milvus. Use to build your knowledge base.

**Input:**
- `file_path`: Path to the document

**Output:** Status message with chunk count and collection name

**Config options:**
```yaml
document_ingest_vdb:
  _type: nvingest_document_ingest_vdb
  nvingest_host: localhost
  nvingest_port: 7670
  # Extraction
  extract_text: true
  extract_tables: true
  extract_charts: true
  extract_images: false
  text_depth: page
  # VDB
  milvus_uri: http://localhost:19530
  collection_name: my_collection
  # Embedding
  embedding_url: http://nv-ingest-embedding-1:8000/v1
  embedding_model: nvidia/llama-3.2-nv-embedqa-1b-v2
```

**Example:**
```bash
nat mcp client tool call document_ingest_vdb \
    --url http://localhost:9901/mcp \
    --json-args '{"file_path": "/app/nv-ingest-lib-mode/embedded_table.pdf"}'
```

---

### 3. `semantic_search` - Query Knowledge Base

Searches Milvus for documents relevant to a natural language query.

**Input:**
- `query`: Natural language search query

**Output:** Top-K relevant document chunks

**Config options:**
```yaml
semantic_search:
  _type: milvus_semantic_search
  milvus_uri: http://localhost:19530
  collection_name: my_collection
  embedding_url: http://localhost:8012/v1
  embedding_model: nvidia/llama-3.2-nv-embedqa-1b-v2
  top_k: 5
```

**Example:**
```bash
nat mcp client tool call semantic_search \
    --url http://localhost:9901/mcp \
    --json-args '{"query": "What tables are in the documents?"}'
```

## Configuration Reference

### Direct Mode (`nvingest_agent_direct.yml`)

```yaml
functions:
  document_ingest_vdb:
    _type: nvingest_document_ingest_vdb
    nvingest_host: localhost
    nvingest_port: 7670
    milvus_uri: http://localhost:19530
    collection_name: nv_ingest_collection
    embedding_url: http://nv-ingest-embedding-1:8000/v1
    embedding_model: nvidia/llama-3.2-nv-embedqa-1b-v2

workflow:
  _type: react_agent
  tool_names: [document_ingest, document_ingest_vdb, semantic_search]
  llm_name: nim_llm
```

### MCP Client Mode (`nvingest_mcp_client.yml`)

```yaml
function_groups:
  nvingest_tools:
    _type: mcp_client
    server:
      transport: streamable-http
      url: "http://localhost:9901/mcp"
    include:
      - document_ingest_vdb
      - semantic_search

workflow:
  _type: react_agent
  tool_names: [nvingest_tools]
```

## Troubleshooting

```bash
# Test NV-Ingest connection
curl http://localhost:7670/health

# Test Milvus connection
curl http://localhost:19530/health

# Test embedding service
curl http://localhost:8012/v1/models

# Test MCP server
curl http://localhost:9901/health
```

## How It Works

1. **`register.py`** defines 3 custom NAT functions using `@register_function`
2. **`pyproject.toml`** entry-point makes NAT auto-discover these functions
3. **Config YAMLs** wire the functions into workflows with different architectures
4. **Docker** provides isolated environment with all dependencies
