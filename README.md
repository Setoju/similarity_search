# Semantic Embeddings API

A Ruby on Rails application for semantic document storage and similarity search using vector embeddings. This API allows you to store documents, automatically generate embeddings using Ollama, and perform semantic search to find similar documents based on content meaning rather than exact keyword matching.

## Features

- **Document Storage**: Store text documents with automatic embedding generation
- **Semantic Search**: Find documents based on semantic similarity using cosine similarity
- **Hierarchical Sentence Search**: Three-level search that finds the best document, then best chunk, then best sentences
- **Background Processing**: Document embedding via async jobs with index status tracking
- **Text Chunking**: Automatic splitting of documents into overlapping chunks
- **Sentence Segmentation**: Language-aware sentence detection using pragmatic_segmenter
- **Text Preprocessing**: Automatic text normalization before embedding generation
- **RESTful API**: Clean REST endpoints for all operations
- **Ollama Integration**: Uses Ollama with nomic-embed-text model for embedding generation
- **PostgreSQL Storage**: Efficient storage of documents and vector embeddings
- **RAG (Retrieval-Augmented Generation)**: Answers user questions using retrieved context; falls back to Google Gemini's own knowledge when no similar content exists
- **Automatic Knowledge Persistence**: When Gemini answers from its own knowledge (no matching documents found), the Q&A pair is automatically saved as a new document and scheduled for embedding — making it available as context for future identical queries
- **Deduplication Guard**: Concurrent or repeated identical queries only ever produce one persisted document; a cache lock (1-hour TTL) combined with a DB existence check prevents duplicates even while the embedding pipeline is still running
- **Configurable Similarity Metrics**: Choose between cosine similarity (default) and Euclidean distance on every search endpoint via the `search_type` parameter

## Prerequisites

- Ruby 3.1+
- Rails 8.0+
- PostgreSQL 12+
- Ollama with nomic-embed-text model

## Installation

### 1. Clone the repository

```bash
git clone <repository-url>
cd semantic_embeddings
```

### 2. Install dependencies

```bash
bundle install
```

### 3. Database setup

```bash
rails db:create
rails db:migrate
```

### 4. Environment configuration

Create a `.env` file in the project root:

```bash
DATABASE_USERNAME=your_pg_username
DATABASE_PASSWORD=your_pg_password
GOOGLE_API_KEY=your_google_api_key
```

A Google API key is required for the RAG endpoint. You can obtain one from [Google AI Studio](https://aistudio.google.com/app/apikey).

### 5. Ollama setup

Install and start Ollama:

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
ollama serve

# Pull the embedding model
ollama pull nomic-embed-text
```

## Usage

### Starting the application

```bash
rails server
```

The API will be available at `http://localhost:3000`.

### API Endpoints

#### Create a document

```bash
POST /documents
Content-Type: application/json

{
  "document": {
    "content": "Your document content here"
  }
}
```

#### List all documents

```bash
GET /documents
```

#### Search documents

```bash
POST /documents/search
Content-Type: application/json

{
  "query": "search query text"
}
```

#### Sentence Search (Hierarchical)

Performs a three-level hierarchical search:
1. Finds the most similar **document** based on embedding similarity
2. Within that document, finds the most similar **chunk**
3. Returns the top matching **sentences** from that chunk

```bash
POST /documents/sentence_search
Content-Type: application/json

{
  "query": "search query text"
}
```

Response:
```json
[
  {
    "content": "The matching sentence text.",
    "score": 0.89,
    "document_id": 1,
    "chunk_id": 3,
    "start_char": 150,
    "end_char": 185
  }
]
```

#### Check Index Status

Returns the processing status of all documents:

```bash
GET /documents/index_status
```

Response:
```json
{
  "pending": 2,
  "processing": 1,
  "completed": 10,
  "failed": 0,
  "total": 13,
  "in_progress": 3
}
```

#### RAG — Question Answering

Answers a natural-language question using the stored documents as context. If no sufficiently similar content is found, Google Gemini answers from its own knowledge and the Q&A pair is automatically persisted as a new document for future use.

```bash
POST /documents/rag
Content-Type: application/json

{
  "query": "What is the capital of France?",
  "search_type": "cosine"
}
```

Response when context is found:
```json
{
  "answer": "Paris is the capital of France.",
  "sources": [
    {
      "content": "France is a country in Western Europe. Its capital is Paris.",
      "score": 0.92,
      "document_id": 4,
      "chunk_id": 7,
      "start_char": 0,
      "end_char": 58
    }
  ]
}
```

Response when no context is found (model knowledge used):
```json
{
  "answer": "Paris is the capital of France.",
  "sources": "Internet"
}
```

> **Note**: When `sources` is `"Internet"`, the answer came from Gemini's own knowledge and the Q&A has been queued for indexing so the same question returns a context-backed answer next time.

#### Similarity metric

All search endpoints (`/search`, `/sentence_search`, `/rag`) accept an optional `search_type` parameter:

| Value | Algorithm | Notes |
|---|---|---|
| `cosine` *(default)* | Cosine similarity | Best for comparing directions; scale-invariant |
| `euclidean` | Euclidean distance (inverted) | Considers magnitude; may suit shorter texts |

```bash
# Example: use Euclidean distance
POST /documents/sentence_search
{ "query": "machine learning basics", "search_type": "euclidean" }
```

#### Clear all documents

```bash
DELETE /documents/clear
```

## Architecture

### Models

- **Document**: Stores text content and embedding vectors
  - `content`: Text content of the document
  - `embedding`: Float array representing the document's semantic embedding
  - `index_status`: Processing status (pending, processing, completed, failed)

- **Chunk**: Text segments within a document
  - `document_id`: Reference to parent document
  - `start_char`, `end_char`: Character positions in original document
  - `embedding`: Float array for chunk's semantic embedding

- **Sentence**: Individual sentences within chunks
  - `document_id`: Reference to parent document
  - `chunk_id`: Reference to parent chunk
  - `start_char`, `end_char`: Character positions in original document
  - `embedding`: Float array for sentence's semantic embedding

### Services

- **Embeddings::DocumentEmbedding**: Generates embeddings for documents
- **Embeddings::OllamaClient**: Interface to Ollama embedding API
- **Embeddings::GoogleGeminiClient**: Interface to Google Gemini API for text generation
- **Embeddings::DocumentSearch**: Performs semantic search across documents
- **Embeddings::SentenceSearch**: Hierarchical search (document → chunk → sentence)
- **Preprocessing::Normalizer**: Text preprocessing and normalization
- **Preprocessing::Chunker**: Splits documents into overlapping chunks
- **Preprocessing::Sentencer**: Language-aware sentence segmentation
- **Similarity::Cosine**: Calculates cosine similarity between vectors
- **Similarity::Euclidean**: Calculates Euclidean distance between vectors
- **Similarity::Resolver**: Selects the correct similarity calculator based on the `search_type` parameter
- **Rag::Query**: Orchestrates the full RAG pipeline — retrieves context, calls Gemini, and persists knowledge-based answers

### Jobs

- **DocumentEmbeddingJob**: Background job that processes documents:
  1. Generates document-level embedding
  2. Splits document into chunks and generates chunk embeddings
  3. Segments chunks into sentences and generates sentence embeddings
  4. Updates document index_status on completion

### Controllers

- **DocumentsController**: REST API endpoints for document operations

## Configuration

### Database Configuration

The application uses PostgreSQL with the following environment variables:

- `DATABASE_USERNAME`: PostgreSQL username (default: postgres)
- `DATABASE_PASSWORD`: PostgreSQL password (default: password)
- `RAILS_MAX_THREADS`: Database connection pool size (default: 5)

### Ollama Configuration

The Ollama client connects to:

- **Base URL**: `http://localhost:11434`
- **Model**: `nomic-embed-text`

These settings can be modified in `app/services/embeddings/ollama_client.rb`.

### Google Gemini Configuration

The RAG endpoint uses Google Gemini for answer generation:

- **Model**: `gemma-3-1b-it`
- **API Key**: Set via the `GOOGLE_API_KEY` environment variable

These settings can be modified in `app/services/embeddings/google_gemini_client.rb`.

### Knowledge Persistence & Deduplication

When the RAG pipeline finds no matching context, the generated Q&A is saved as a new document. To prevent duplicate documents from concurrent or repeated identical requests (especially while the embedding job is still running):

- A **cache lock** (`Rails.cache`) is written with a 1-hour TTL keyed on the SHA-256 hash of the normalized query
- A **DB existence check** (`Document.exists?`) acts as a fallback when the cache is cold (e.g. after a restart)

Once a document is fully indexed, future identical queries will find it via semantic search and never reach the persistence path at all.

## Testing

Run the test suite:

```bash
rails test
```

Run specific test files:

```bash
rails test test/models/document_test.rb
rails test test/services/embeddings/
```
