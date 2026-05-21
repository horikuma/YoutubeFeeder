PRAGMA journal_mode = DELETE;

CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS translation_units (
    id INTEGER PRIMARY KEY,
    file_id INTEGER NOT NULL,
    compile_directory TEXT,
    compile_command TEXT NOT NULL,
    parsed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (file_id) REFERENCES files(id)
);

CREATE TABLE IF NOT EXISTS functions (
    id INTEGER PRIMARY KEY,
    usr TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    file_id INTEGER,
    line INTEGER,
    column INTEGER,
    is_definition INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (file_id) REFERENCES files(id)
);

CREATE TABLE IF NOT EXISTS globals (
    id INTEGER PRIMARY KEY,
    usr TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    type TEXT,
    storage_class TEXT,
    file_id INTEGER,
    line INTEGER,
    column INTEGER,
    first_seen_tu_id INTEGER,
    FOREIGN KEY (file_id) REFERENCES files(id),
    FOREIGN KEY (first_seen_tu_id) REFERENCES translation_units(id)
);

CREATE TABLE IF NOT EXISTS global_accesses (
    id INTEGER PRIMARY KEY,
    global_usr TEXT NOT NULL,
    function_usr TEXT,
    access_kind TEXT NOT NULL,
    file_id INTEGER NOT NULL,
    line INTEGER,
    column INTEGER,
    expression TEXT,
    tu_id INTEGER,
    FOREIGN KEY (global_usr) REFERENCES globals(usr),
    FOREIGN KEY (function_usr) REFERENCES functions(usr),
    FOREIGN KEY (file_id) REFERENCES files(id),
    FOREIGN KEY (tu_id) REFERENCES translation_units(id)
);

CREATE TABLE IF NOT EXISTS call_edges (
    id INTEGER PRIMARY KEY,
    caller_usr TEXT NOT NULL,
    callee_usr TEXT NOT NULL,
    argument_summary TEXT,
    file_id INTEGER NOT NULL,
    line INTEGER,
    column INTEGER,
    tu_id INTEGER,
    FOREIGN KEY (caller_usr) REFERENCES functions(usr),
    FOREIGN KEY (callee_usr) REFERENCES functions(usr),
    FOREIGN KEY (file_id) REFERENCES files(id),
    FOREIGN KEY (tu_id) REFERENCES translation_units(id)
);

CREATE INDEX IF NOT EXISTS idx_globals_name ON globals(name);
CREATE INDEX IF NOT EXISTS idx_global_accesses_global_usr ON global_accesses(global_usr);
CREATE INDEX IF NOT EXISTS idx_global_accesses_function_usr ON global_accesses(function_usr);
CREATE INDEX IF NOT EXISTS idx_call_edges_caller_usr ON call_edges(caller_usr);
CREATE INDEX IF NOT EXISTS idx_call_edges_callee_usr ON call_edges(callee_usr);
