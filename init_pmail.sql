PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE `user` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `account` TEXT NOT NULL, `name` TEXT NOT NULL, `password` TEXT NOT NULL, `disabled` INTEGER DEFAULT 0 NOT NULL, `is_admin` INTEGER DEFAULT 0 NOT NULL);
INSERT INTO user VALUES(1,'admin','admin','faddb6ec2efe16116a342f5512583c48',0,1);
CREATE TABLE `email` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `type` INTEGER DEFAULT 0 NOT NULL, `subject` TEXT DEFAULT '' NOT NULL, `reply_to` TEXT NULL, `from_name` TEXT DEFAULT '' NOT NULL, `from_address` TEXT DEFAULT '' NOT NULL, `to` TEXT NULL, `bcc` TEXT NULL, `cc` TEXT NULL, `text` TEXT NULL, `html` TEXT NULL, `sender` TEXT NULL, `attachments` TEXT NULL, `spf_check` INTEGER NULL, `dkim_check` INTEGER NULL, `status` INTEGER DEFAULT 0 NOT NULL, `cron_send_time` DATETIME NULL, `update_time` DATETIME NULL, `send_user_id` INTEGER DEFAULT 0 NOT NULL, `size` INTEGER DEFAULT 1000 NOT NULL, `error` TEXT NULL, `send_date` DATETIME NULL, `create_time` DATETIME NULL);
CREATE TABLE `group` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `parent_id` INTEGER DEFAULT 0 NOT NULL, `user_id` INTEGER DEFAULT 0 NOT NULL, `full_path` TEXT NULL);
CREATE TABLE `rule` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `user_id` INTEGER DEFAULT 0 NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `value` TEXT NULL, `action` INTEGER DEFAULT 0 NOT NULL, `params` TEXT DEFAULT '' NOT NULL, `sort` INTEGER DEFAULT 0 NOT NULL);
CREATE TABLE `sessions` (`token` TEXT PRIMARY KEY NOT NULL, `data` BLOB NULL, `expiry` DATETIME NULL);
CREATE TABLE `user_email` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `user_id` INTEGER NOT NULL, `email_id` INTEGER NOT NULL, `is_read` INTEGER NULL, `group_id` INTEGER DEFAULT 0 NOT NULL, `status` INTEGER DEFAULT 0 NOT NULL, `create` DATETIME NULL);
CREATE TABLE `version` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `info` TEXT NOT NULL);
INSERT INTO sqlite_sequence VALUES('user',1);
CREATE UNIQUE INDEX `UQE_user_account` ON `user` (`account`);
CREATE INDEX `IDX_sessions_expiry` ON `sessions` (`expiry`);
CREATE INDEX `IDX_user_email_'idx_eid'` ON `user_email` (`user_id`,`email_id`);
CREATE INDEX `IDX_user_email_user_id` ON `user_email` (`user_id`);
CREATE INDEX `IDX_user_email_email_id` ON `user_email` (`email_id`);
CREATE INDEX `IDX_user_email_'idx_create_time'` ON `user_email` (`create`);
COMMIT;
/work/config # 
