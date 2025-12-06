-- ============================================
-- CREATE TABLES
-- ============================================

-- Tabel User
CREATE TABLE IF NOT EXISTS "user" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "account" TEXT,
    "name" TEXT,
    "password" TEXT,
    "disabled" INTEGER UNSIGNED NOT NULL DEFAULT 0,
    "is_admin" INTEGER UNSIGNED NOT NULL DEFAULT 0
);

-- Tabel Email
CREATE TABLE IF NOT EXISTS "email" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "type" TINYINT NOT NULL DEFAULT 0,
    "subject" TEXT,
    "reply_to" TEXT,
    "from_name" TEXT,
    "from_address" TEXT,
    "to" TEXT,
    "bcc" TEXT,
    "cc" TEXT,
    "text" TEXT,
    "html" MEDIUMTEXT,
    "sender" TEXT,
    "attachments" LONGTEXT,
    "spf_check" TINYINT,
    "dkim_check" TINYINT,
    "status" TINYINT NOT NULL DEFAULT 0,
    "cron_send_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "send_user_id" INTEGER UNSIGNED NOT NULL DEFAULT 0,
    "size" INTEGER UNSIGNED NOT NULL DEFAULT 1000,
    "error" TEXT,
    "send_date" TIMESTAMP,
    "create_time" TIMESTAMP
);

-- Tabel Group
CREATE TABLE IF NOT EXISTS "group" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "name" TEXT,
    "parent_id" INTEGER UNSIGNED NOT NULL DEFAULT 0,
    "user_id" INTEGER UNSIGNED NOT NULL DEFAULT 0,
    "full_path" TEXT
);

-- Tabel Rule
CREATE TABLE IF NOT EXISTS "rule" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "user_id" INTEGER NOT NULL DEFAULT 0,
    "name" TEXT,
    "value" TEXT,
    "action" INTEGER NOT NULL DEFAULT 0,
    "params" TEXT,
    "sort" INTEGER NOT NULL DEFAULT 0
);

-- Tabel Sessions
CREATE TABLE IF NOT EXISTS "sessions" (
    "token" TEXT PRIMARY KEY,
    "data" BLOB,
    "expiry" TIMESTAMP
);

-- Tabel UserEmail
CREATE TABLE IF NOT EXISTS "user_email" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "user_id" INTEGER NOT NULL,
    "email_id" INTEGER NOT NULL,
    "is_read" TINYINT,
    "group_id" INTEGER NOT NULL DEFAULT 0,
    "status" TINYINT NOT NULL DEFAULT 0,
    "create" DATETIME
);

-- Tabel Version
CREATE TABLE IF NOT EXISTS "version" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "info" TEXT
);

-- ============================================
-- CREATE INDEXES (UPDATED to match PMail's naming convention)
-- ============================================

-- Sessions table index
CREATE INDEX IF NOT EXISTS "IDX_sessions_idx_expiry" ON "sessions" ("expiry");

-- UserEmail table indices (updated names)
CREATE INDEX IF NOT EXISTS "IDX_user_email_idx_eid" ON "user_email" ("user_id", "email_id");
CREATE INDEX IF NOT EXISTS "IDX_user_email_idx_email_id" ON "user_email" ("email_id");
CREATE INDEX IF NOT EXISTS "IDX_user_email_idx_user_id" ON "user_email" ("user_id");
CREATE INDEX IF NOT EXISTS "IDX_user_email_idx_create" ON "user_email" ("create");

-- ============================================
-- INITIAL DATA
-- ============================================

-- Hapus data lama jika ada (opsional, uncomment jika diperlukan)
-- DELETE FROM "user";
-- DELETE FROM "group";
-- DELETE FROM "version";

-- Reset auto-increment (uncomment jika diperlukan)
-- DELETE FROM "sqlite_sequence" WHERE "name" IN ('user', 'group', 'version');

-- Insert user admin (password: admin dengan MD5)
INSERT OR IGNORE INTO "user" ("account", "name", "password", "disabled", "is_admin") 
VALUES (
    'admin', 
    'Administrator', 
    'faddb6ec2efe16116a342f5512583c48',
    0, 
    1
);

-- Insert user regular (password: admin dengan MD5)
INSERT OR IGNORE INTO "user" ("account", "name", "password", "disabled", "is_admin") 
VALUES (
    'user', 
    'Regular User', 
    'faddb6ec2efe16116a342f5512583c48',
    0, 
    0
);

-- Insert grup-grup default untuk user admin (ID = 1)
INSERT OR IGNORE INTO "group" ("id", "name", "parent_id", "user_id", "full_path") 
VALUES 
    (2000000000, 'INBOX', 0, 1, 'INBOX'),
    (2000000001, 'Sent Messages', 0, 1, 'Sent Messages'),
    (2000000002, 'Drafts', 0, 1, 'Drafts'),
    (2000000003, 'Deleted Messages', 0, 1, 'Deleted Messages'),
    (2000000004, 'Junk', 0, 1, 'Junk');

-- Insert grup-grup default untuk user regular (ID = 2)
INSERT OR IGNORE INTO "group" ("id", "name", "parent_id", "user_id", "full_path") 
VALUES 
    (2000000005, 'INBOX', 0, 2, 'INBOX'),
    (2000000006, 'Sent Messages', 0, 2, 'Sent Messages'),
    (2000000007, 'Drafts', 0, 2, 'Drafts'),
    (2000000008, 'Deleted Messages', 0, 2, 'Deleted Messages'),
    (2000000009, 'Junk', 0, 2, 'Junk');

-- Insert version info
INSERT OR IGNORE INTO "version" ("info") VALUES ('1.0.0');
