PRAGMA foreign_keys = OFF;
-- Insert admin user
INSERT INTO user (username, password, salt, is_admin, create_time, update_time)
VALUES (
    'admin',
    '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', -- password: admin
    '',
    1,
    datetime('now'),
    datetime('now')
);

-- Insert version info
INSERT INTO version (info)
VALUES ('v2.9.9');

PRAGMA foreign_keys = ON;
