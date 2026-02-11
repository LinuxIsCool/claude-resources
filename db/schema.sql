-- Phase 2: Git History Database Schema
-- SQLite schema for storing commit history across all tracked repos.
-- Used for force-directed graph temporal visualizations.

-- Not yet implemented. This is a skeleton for planning purposes.

CREATE TABLE IF NOT EXISTS repos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    owner TEXT NOT NULL,
    name TEXT NOT NULL,
    url TEXT,
    last_synced_at DATETIME,
    UNIQUE(owner, name)
);

CREATE TABLE IF NOT EXISTS commits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_id INTEGER NOT NULL REFERENCES repos(id),
    sha TEXT NOT NULL,
    author_name TEXT,
    author_email TEXT,
    committed_at DATETIME NOT NULL,
    message TEXT,
    UNIQUE(repo_id, sha)
);

CREATE TABLE IF NOT EXISTS file_changes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commit_id INTEGER NOT NULL REFERENCES commits(id),
    file_path TEXT NOT NULL,
    change_type TEXT NOT NULL CHECK(change_type IN ('A', 'M', 'D', 'R')),
    additions INTEGER DEFAULT 0,
    deletions INTEGER DEFAULT 0
);

CREATE INDEX idx_commits_repo ON commits(repo_id);
CREATE INDEX idx_commits_date ON commits(committed_at);
CREATE INDEX idx_file_changes_commit ON file_changes(commit_id);
CREATE INDEX idx_file_changes_path ON file_changes(file_path);

-- Co-modification view: files that change together in the same commit
CREATE VIEW co_modifications AS
SELECT
    a.file_path AS file_a,
    b.file_path AS file_b,
    COUNT(*) AS co_change_count,
    MIN(c.committed_at) AS first_co_change,
    MAX(c.committed_at) AS last_co_change
FROM file_changes a
JOIN file_changes b ON a.commit_id = b.commit_id AND a.file_path < b.file_path
JOIN commits c ON a.commit_id = c.id
GROUP BY a.file_path, b.file_path;
