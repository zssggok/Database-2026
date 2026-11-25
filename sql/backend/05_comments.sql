USE shiyin;
-- 按功能分组的存储过程。安装一次后通过CALL调用，不会自动调用业务功能。
-- p_actor必须由后端从登录会话获取，不能相信客户端传入的编号。
-- 写入过程独立管理事务，请勿在已有事务中调用。
DELIMITER $$

CREATE PROCEDURE sp_add_comment(IN p_actor INT, IN p_track INT, IN p_content TEXT)
BEGIN
    IF @@session.in_transaction = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '请在已有事务外调用此过程';
    END IF;
    BEGIN
        DECLARE v_status VARCHAR(16) DEFAULT NULL;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        START TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='评论用户不存在';
        END IF;
        IF p_content IS NULL OR CHAR_LENGTH(TRIM(p_content))=0 OR CHAR_LENGTH(p_content)>1000 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='评论需要1至1000个字符';
        END IF;
        SELECT track_status INTO v_status FROM tracks WHERE track_id=p_track FOR UPDATE;
        IF v_status IS NULL OR v_status<>'approved' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='只能评论审核通过的音乐';
        END IF;
        INSERT INTO comments(comment_user_id,comment_track_id,comment_content) VALUES(p_actor,p_track,p_content);
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_list_comments(IN p_actor INT, IN p_track INT)
BEGIN
    SELECT c.comment_id,c.comment_content,c.comment_created_time,
           COALESCE(u.user_nickname,u.user_name,'该用户已注销') AS commenter_name
    FROM comments c JOIN tracks t ON t.track_id=c.comment_track_id
    LEFT JOIN users u ON u.user_id=c.comment_user_id
    WHERE t.track_id=p_track
    AND (t.track_status='approved' OR t.track_uploader_id=p_actor
         OR EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin'))
    ORDER BY c.comment_created_time,c.comment_id;
END$$

CREATE PROCEDURE sp_delete_comment(IN p_actor INT, IN p_comment INT)
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
    DELETE FROM comments WHERE comment_id=p_comment
    AND (comment_user_id=p_actor
         OR EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin'));
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

DELIMITER ;
