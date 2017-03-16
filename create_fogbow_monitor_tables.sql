-- Creating fogbow monitor database

CREATE TABLE IF NOT EXISTS monitor_log (
	id INT NOT NULL PRIMARY KEY,
	object_type VARCHAR(10) NOT NULL,
	object_id VARCHAR(255) NOT NULL,
	creation_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	last_update TIMESTAMP NULL,
	status VARCHAR(20) NOT NULL,
	manager_response TEXT NULL
);