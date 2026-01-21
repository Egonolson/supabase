-- pgvector Extension fuer AI/Embeddings
-- Wird automatisch beim Start aktiviert

-- Extension aktivieren
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- Berechtigungen setzen
GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role;

-- Beispiel-Tabelle fuer Embeddings (optional, kann geloescht werden)
CREATE TABLE IF NOT EXISTS public.documents (
    id BIGSERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    embedding vector(1536), -- OpenAI ada-002 Dimension
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index fuer schnelle Similarity-Suche
CREATE INDEX IF NOT EXISTS documents_embedding_idx ON public.documents
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- RLS aktivieren
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

-- Beispiel-Policy (anpassen nach Bedarf)
CREATE POLICY "Jeder kann Dokumente lesen" ON public.documents
    FOR SELECT USING (true);

CREATE POLICY "Authentifizierte koennen Dokumente erstellen" ON public.documents
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Hilfsfunktion fuer Similarity-Suche
CREATE OR REPLACE FUNCTION public.match_documents(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.78,
    match_count int DEFAULT 10
)
RETURNS TABLE (
    id bigint,
    content text,
    metadata jsonb,
    similarity float
)
LANGUAGE sql STABLE
AS $$
    SELECT
        documents.id,
        documents.content,
        documents.metadata,
        1 - (documents.embedding <=> query_embedding) AS similarity
    FROM public.documents
    WHERE 1 - (documents.embedding <=> query_embedding) > match_threshold
    ORDER BY documents.embedding <=> query_embedding
    LIMIT match_count;
$$;

-- Berechtigungen fuer die Funktion
GRANT EXECUTE ON FUNCTION public.match_documents TO anon, authenticated, service_role;

COMMENT ON EXTENSION vector IS 'pgvector: Vector similarity search for PostgreSQL';
COMMENT ON TABLE public.documents IS 'Beispiel-Tabelle fuer AI Embeddings - kann angepasst oder geloescht werden';
COMMENT ON FUNCTION public.match_documents IS 'Findet aehnliche Dokumente basierend auf Embedding-Vektoren';
