-- Manual MySQL migration for Spring Boot's default snake_case physical naming.
-- Review against the deployment schema; do not run twice. No live data migration is performed by the implementation task.
ALTER TABLE commitment ADD COLUMN target_steps INT NULL,
    ADD COLUMN step_evidence_mode VARCHAR(12) NULL;
ALTER TABLE commitment_week ADD COLUMN steps_settlement_pending BOOLEAN DEFAULT FALSE;

CREATE TABLE step_connection (
    member_id INT NOT NULL PRIMARY KEY,
    source VARCHAR(20) NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    checked_at DATETIME NULL,
    last_successful_read_at DATETIME NULL,
    CONSTRAINT fk_step_connection_member FOREIGN KEY (member_id) REFERENCES member(id) ON DELETE CASCADE
);
CREATE TABLE daily_steps (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    activity_day DATE NOT NULL,
    total INT NOT NULL,
    source VARCHAR(20) NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    zone_id VARCHAR(40) NOT NULL,
    observed_at DATETIME NULL,
    synced_at DATETIME NULL,
    CONSTRAINT uk_steps_member_day UNIQUE (member_id, activity_day),
    CONSTRAINT fk_daily_steps_member FOREIGN KEY (member_id) REFERENCES member(id) ON DELETE CASCADE
);
