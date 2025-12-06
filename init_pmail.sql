PRAGMA foreign_keys = OFF;

CREATE TABLE IF NOT EXISTS user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    salt TEXT,
    is_admin INTEGER DEFAULT 0,
    create_time DATETIME,
    update_time DATETIME
);

CREATE TABLE IF NOT EXISTS email (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_user TEXT,
    to_user TEXT,
    subject TEXT,
    content TEXT,
    status INTEGER DEFAULT 0,
    create_time DATETIME,
    update_time DATETIME
);

CREATE TABLE IF NOT EXISTS "group" (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    description TEXT,
    create_time DATETIME,
    update_time DATETIME
);

CREATE TABLE IF NOT EXISTS rule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    type INTEGER,
    value TEXT,
    create_time DATETIME,
    update_time DATETIME
);

CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    token TEXT,
    expire_time DATETIME,
    create_time DATETIME
);

CREATE TABLE IF NOT EXISTS user_email (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    email_id INTEGER NOT NULL,
    status INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    info TEXT
);

INSERT INTO user (username, password, salt, is_admin, create_time, update_time)
VALUES (
    'admin',
    '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918',
    '',
    1,
    datetime('now'),
    datetime('now')
);

INSERT INTO version (info)
VALUES ('v2.9.9');

PRAGMA foreign_keys = ON;
