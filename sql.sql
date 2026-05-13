CREATE TABLE IF NOT EXISTS `melora_music_playlist` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(50)  NOT NULL,
    `title`      VARCHAR(255) NOT NULL,
    `url`        TEXT         NOT NULL,
    `thumbnail`  TEXT         NULL DEFAULT NULL,
    `sort_order` INT(11)      NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`) USING BTREE,
    INDEX `identifier` (`identifier`) USING BTREE
);
