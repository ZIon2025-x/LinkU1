CREATE TABLE IF NOT EXISTS questions (
    id SERIAL PRIMARY KEY,
    target_type VARCHAR(20) NOT NULL,
    target_id INTEGER NOT NULL,
    asker_id VARCHAR(8) NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    reply TEXT,
    reply_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_questions_target ON questions(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_questions_asker ON questions(asker_id);
