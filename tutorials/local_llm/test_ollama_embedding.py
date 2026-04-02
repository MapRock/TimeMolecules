import ollama
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

# ================== CONFIG ==================
EMBEDDING_MODEL = "nomic-embed-text"   # Good balance of speed & quality

# Your sample documents (replace with your own writing)
documents = [
    "I believe the open source AI path is the only way the US can stay competitive against China.",
    "Brian Roemmele and others talks about how closed SaaS AI models will die because of open source.",
    "Local models running on my laptop give me complete privacy and no usage limits.",
    "I want to build a personal knowledge base from all my writing about AI and technology.",
    "Running Qwen3 locally feels slow sometimes, but the privacy is worth it."
]

# ================== FUNCTIONS ==================
def get_embedding(text: str):
    """Generate embedding for a single piece of text"""
    response = ollama.embeddings(
        model=EMBEDDING_MODEL,
        prompt=text
    )
    return response['embedding']

def search_documents(query: str, documents: list, top_k: int = 3):
    """Find the most relevant documents to the query"""
    print(f"🔍 Searching for: '{query}'\n")
    
    # Get embedding for the query
    query_embedding = get_embedding(query)
    
    # Get embeddings for all documents
    doc_embeddings = [get_embedding(doc) for doc in documents]
    
    # Calculate similarity
    similarities = cosine_similarity([query_embedding], doc_embeddings)[0]
    
    # Get top results
    top_indices = np.argsort(similarities)[::-1][:top_k]
    
    for i, idx in enumerate(top_indices):
        print(f"{i+1}. Score: {similarities[idx]:.4f}")
        print(f"   {documents[idx]}\n")

# ================== MAIN ==================
if __name__ == "__main__":
    print("Ollama Embeddings Demo\n")
    
    # Example 1: Simple embedding
    test_text = "Open source AI is the future"
    embedding = get_embedding(test_text)
    print(f"Embedding generated! Dimension: {len(embedding)}\n")
    
    # Example 2: Semantic search on your documents
    query = [
        "What does Brian Roemmele think about open source AI?",
        "Why do some people prefer local AI models?",
        "How can I use my writing to build a knowledge base?"
        ]
    for q in query:
        search_documents(q, documents)
