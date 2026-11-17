USE shiyin;
-- 按功能分组的存储过程。安装一次后通过CALL调用，不会自动调用业务功能。
-- p_actor必须由后端从登录会话获取，不能相信客户端传入的编号。
-- 写入过程独立管理事务，请勿在已有事务中调用。
DELIMITER $$

CREATE PROCEDURE sp_create_artist(IN p_actor INT, IN p_name VARCHAR(100), IN p_bio TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='name不能为空';
    END IF;
    INSERT INTO artists(artist_name,artist_bio)
    SELECT p_name,p_bio FROM users WHERE user_id=p_actor AND user_role='admin';
    SELECT LAST_INSERT_ID() AS artist_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_edit_artist(IN p_actor INT, IN p_id INT, IN p_name VARCHAR(100), IN p_bio TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='name不能为空';
    END IF;
    UPDATE artists SET artist_name=p_name,artist_bio=p_bio WHERE artist_id=p_id
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin');
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_delete_artist(IN p_actor INT, IN p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    DELETE FROM artists WHERE artist_id=p_id
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin');
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_create_album(IN p_actor INT, IN p_name VARCHAR(100), IN p_date DATE, IN p_bio TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='name不能为空';
    END IF;
    INSERT INTO albums(album_name,album_release_date,album_bio)
    SELECT p_name,p_date,p_bio FROM users WHERE user_id=p_actor AND user_role='admin';
    SELECT LAST_INSERT_ID() AS album_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_edit_album(IN p_actor INT, IN p_id INT, IN p_name VARCHAR(100), IN p_date DATE, IN p_bio TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='name不能为空';
    END IF;
    UPDATE albums SET album_name=p_name,album_release_date=p_date,album_bio=p_bio WHERE album_id=p_id
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin');
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_delete_album(IN p_actor INT, IN p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    DELETE FROM albums WHERE album_id=p_id
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin');
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_create_tag(IN p_actor INT, IN p_name VARCHAR(50), IN p_description VARCHAR(255))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='name不能为空';
    END IF;
    INSERT INTO tags(tag_name,tag_description)
    SELECT p_name,p_description FROM users WHERE user_id=p_actor AND user_role='admin';
    SELECT LAST_INSERT_ID() AS tag_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_edit_tag(IN p_actor INT, IN p_id INT, IN p_name VARCHAR(50), IN p_description VARCHAR(255))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='name不能为空';
    END IF;
    UPDATE tags SET tag_name=p_name,tag_description=p_description WHERE tag_id=p_id
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin');
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_delete_tag(IN p_actor INT, IN p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    DELETE FROM tags WHERE tag_id=p_id
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin');
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_add_album_artist(IN p_actor INT, IN p_album INT, IN p_artist INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    INSERT INTO album_artists(album_id,artist_id)
    SELECT p_album,p_artist FROM users WHERE user_id=p_actor AND user_role='admin';
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_remove_album_artist(IN p_actor INT, IN p_album INT, IN p_artist INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    DELETE FROM album_artists WHERE album_id=p_album AND artist_id=p_artist
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin');
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

DELIMITER ;
