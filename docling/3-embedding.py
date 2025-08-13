import os
from pathlib import Path
from typing import List

import lancedb
from docling.chunking import HybridChunker
from docling.document_converter import DocumentConverter
from dotenv import load_dotenv
from lancedb.embeddings import get_registry
from lancedb.pydantic import LanceModel, Vector
from openai import OpenAI
from utils.tokenizer import OpenAITokenizerWrapper

load_dotenv()

# Initialize OpenAI client (make sure you have OPENAI_API_KEY in your environment variables)
client = OpenAI()


tokenizer = OpenAITokenizerWrapper()  # Load our custom tokenizer for OpenAI
MAX_TOKENS = 8191  # text-embedding-3-large's maximum context length


# --------------------------------------------------------------
# Extract the data
# --------------------------------------------------------------

converter = DocumentConverter()

# Get all PDF files in the docs directory
script_dir = Path(__file__).parent
docs_dir = script_dir / "docs"
pdf_files = list(docs_dir.rglob("*.pdf"))

# --------------------------------------------------------------
# Apply hybrid chunking
# --------------------------------------------------------------

chunker = HybridChunker(
    tokenizer=tokenizer,
    max_tokens=MAX_TOKENS,
    merge_peers=True,
)

# Process all documents and combine their chunks
all_chunks = []
for pdf_file in pdf_files:
    print(f"Processing {os.path.basename(pdf_file)} ...")
    result = converter.convert(str(pdf_file))
    chunk_iter = chunker.chunk(dl_doc=result.document)
    chunks = list(chunk_iter)
    all_chunks.extend(chunks)

chunks = all_chunks

# --------------------------------------------------------------
# Create a LanceDB database and table
# --------------------------------------------------------------

# Create a LanceDB database
db = lancedb.connect("data/lancedb")


# Get the OpenAI embedding function
func = get_registry().get("openai").create(name="text-embedding-3-large")


# Define a simplified metadata schema
class ChunkMetadata(LanceModel):
    """
    You must order the fields in alphabetical order.
    This is a requirement of the Pydantic implementation.
    """

    filename: str | None
    page_numbers: List[int] | None
    title: str | None


# Define the main Schema
class Chunks(LanceModel):
    text: str = func.SourceField()
    vector: Vector(func.ndims()) = func.VectorField()  # type: ignore
    metadata: ChunkMetadata


# Create or get the table
try:
    table = db.open_table("portfolio")
except Exception as e:
    print(f"Creating table:  {e}")
    table = db.create_table("portfolio", schema=Chunks, mode="overwrite")

# --------------------------------------------------------------
# Prepare the chunks for the table
# --------------------------------------------------------------

# Create table with processed chunks
processed_chunks = [
    {
        "text": chunk.text,
        "metadata": {
            "filename": chunk.meta.origin.filename,
            "page_numbers": [
                page_no
                for page_no in sorted(
                    set(
                        prov.page_no
                        for item in chunk.meta.doc_items
                        for prov in item.prov
                    )
                )
            ]
            or None,
            "title": chunk.meta.headings[0] if chunk.meta.headings else None,
        },
    }
    for chunk in chunks
]

# --------------------------------------------------------------
# Add the chunks to the table in batches (to stay under token limits)
# --------------------------------------------------------------

# Batch size to stay under 300k token limit (conservative estimate)
BATCH_SIZE = 100  # Adjust based on average chunk size

for i in range(0, len(processed_chunks), BATCH_SIZE):
    batch = processed_chunks[i : i + BATCH_SIZE]
    print(
        f"Adding batch {i//BATCH_SIZE + 1}/{(len(processed_chunks) + BATCH_SIZE - 1)//BATCH_SIZE} ({len(batch)} chunks)"
    )
    table.add(batch)

# --------------------------------------------------------------
# Load the table
# --------------------------------------------------------------

table.to_pandas()
table.count_rows()
