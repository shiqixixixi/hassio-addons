package database

import (
	"database/sql"

	_ "github.com/go-sql-driver/mysql"
	"github.com/lithammer/shortuuid/v3"
	"github.com/mritd/logger"
)

type MySQL struct {
}

var mysqlDB *sql.DB

const (
	dbSchema = "" +
		"CREATE TABLE IF NOT EXISTS `devices` (" +
		"    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT," +
		"    `key` VARCHAR(255) NOT NULL," +
		"    `token` VARCHAR(255) NOT NULL," +
		"    `create_time` DATETIME(3) NOT NULL," +
		"    PRIMARY KEY (`id`)," +
		"    UNIQUE KEY `key` (`key`)" +
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

	MARKDOWN_DB_SCHEMA = "" +
		"CREATE TABLE IF NOT EXISTS `markdown` (" +
		"    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT," +
		"    `key` VARCHAR(255) NOT NULL,    " +
		"    `content` TEXT NOT NULL," +
		"    `create_time` DATETIME(3) NOT NULL," +
		"    PRIMARY KEY (`id`), " +
		"    UNIQUE KEY `key` (`key`)" +
		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
)

func NewMySQL(dsn string) Database {
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		logger.Fatalf("failed to open database connection (%s): %v", dsn, err)
	}

	_, err = db.Exec(dbSchema)
	if err != nil {
		logger.Fatalf("failed to init database schema(%s): %v", dbSchema, err)
	}

	_, err = db.Exec(MARKDOWN_DB_SCHEMA)
	if err != nil {
		logger.Fatalf("failed to init database schema(%s): %v", MARKDOWN_DB_SCHEMA, err)
	}

	mysqlDB = db
	return &MySQL{}
}

func (d *MySQL) CountAll() (int, error) {
	var count int
	err := mysqlDB.QueryRow("SELECT COUNT(1) FROM `devices`").Scan(&count)
	if err != nil {
		return 0, err
	}

	return count, nil
}

func (d *MySQL) DeviceTokenByKey(key string) (string, error) {
	var token string
	err := mysqlDB.QueryRow("SELECT `token` FROM `devices` WHERE `key`=? ", key).Scan(&token)
	if err != nil {
		return "", err
	}

	return token, nil
}

func (d *MySQL) SaveDeviceTokenByKey(key, token string) (string, error) {
	if key == "" {
		// Generate a new UUID as the deviceKey when a new device register
		key = shortuuid.New()
	}

	_, err := mysqlDB.Exec("INSERT INTO `devices` (`key`,`token`,`create_time`) VALUES (?,?,current_timestamp(3)) ON DUPLICATE KEY UPDATE `token`=?", key, token, token)
	if err != nil {
		return "", err
	}

	return key, nil
}

// Get Markdown Content by key
func (d *MySQL) GetMarkdownByKey(key string) (string, error) {
	var markdown string
	err := mysqlDB.QueryRow("SELECT `content` FROM `markdown` WHERE `key`=? ", key).Scan(&markdown)
	if err != nil {
		return "", err
	}
	return markdown, nil
}

// Save Markdown Content
func (d *MySQL) SaveMarkdown(content string) (string, error) {
	key := shortuuid.New()
	_, err := mysqlDB.Exec("INSERT INTO `markdown` (`key`,`content`,`create_time`) VALUES (?,?,current_timestamp(3)) ON DUPLICATE KEY UPDATE `content`=?", key, content, content)
	if err != nil {
		return "", err
	}

	return key, nil
}

func (d *MySQL) Close() error {
	return mysqlDB.Close()
}
