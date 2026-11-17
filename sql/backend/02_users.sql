USE shiyin;
-- 按功能分组的存储过程。安装一次后通过CALL调用，不会自动调用业务功能。
-- p_actor必须由后端从登录会话获取，不能相信客户端传入的编号。
-- 写入过程独立管理事务，请勿在已有事务中调用。
DELIMITER $$

CREATE PROCEDURE sp_register_user(IN p_name VARCHAR(7), IN p_email VARCHAR(50), IN p_hash VARCHAR(255), IN p_nickname VARCHAR(50))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='name不能为空';
    END IF;
    IF p_email IS NULL OR CHAR_LENGTH(TRIM(p_email))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='email不能为空';
    END IF;
    IF p_hash IS NULL OR CHAR_LENGTH(TRIM(p_hash))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='hash不能为空';
    END IF;
    INSERT INTO users(user_name,user_email,user_password_hash,user_nickname,user_role)
    VALUES(p_name,p_email,p_hash,p_nickname,'user');
    SELECT LAST_INSERT_ID() AS user_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_get_login_user(IN p_name VARCHAR(7))
BEGIN
    SELECT user_id,user_name,user_password_hash,user_role FROM users WHERE user_name=p_name;
END$$

CREATE PROCEDURE sp_edit_user_profile(IN p_actor INT, IN p_nickname VARCHAR(50), IN p_bio TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='用户不存在';
    END IF;
    UPDATE users SET user_nickname=p_nickname,user_bio=p_bio WHERE user_id=p_actor;
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_delete_my_account(IN p_actor INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='用户不存在';
    END IF;
    DELETE FROM users WHERE user_id=p_actor;
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_grant_admin(IN p_actor INT, IN p_target INT)
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
    UPDATE users target JOIN users actor ON actor.user_id=p_actor AND actor.user_role='admin'
    SET target.user_role='admin' WHERE target.user_id=p_target;
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

DELIMITER ;
