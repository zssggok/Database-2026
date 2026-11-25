USE shiyin;
-- 按功能分组的存储过程。安装一次后通过CALL调用，不会自动调用业务功能。
-- p_actor必须由后端从登录会话获取，不能相信客户端传入的编号。
-- 写入过程独立管理事务，请勿在已有事务中调用。
DELIMITER $$

CREATE PROCEDURE sp_list_hot_playlists()
BEGIN
    SELECT p.playlist_id,p.playlist_name,COALESCE(f.favorite_count,0) AS favorite_count
    FROM playlists p LEFT JOIN (
        SELECT playlist_id,COUNT(*) AS favorite_count FROM playlist_favorites GROUP BY playlist_id
    ) f ON f.playlist_id=p.playlist_id
    WHERE p.playlist_is_public=1
    ORDER BY favorite_count DESC,p.playlist_id LIMIT 10;
END$$

CREATE PROCEDURE sp_stats_tags(IN p_actor INT)
BEGIN
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    SELECT g.tag_id,g.tag_name,t.track_status,COUNT(t.track_id) AS track_count
    FROM tags g LEFT JOIN track_tags tt ON tt.tag_id=g.tag_id
    LEFT JOIN tracks t ON t.track_id=tt.track_id
    WHERE EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin')
    GROUP BY g.tag_id,g.tag_name,t.track_status;
END$$

CREATE PROCEDURE sp_stats_uploads(IN p_actor INT)
BEGIN
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    SELECT u.user_id,u.user_name,t.track_status,COUNT(t.track_id) AS track_count
    FROM users u LEFT JOIN tracks t ON t.track_uploader_id=u.user_id
    WHERE EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin')
    GROUP BY u.user_id,u.user_name,t.track_status;
END$$

CREATE PROCEDURE sp_stats_deleted_uploads(IN p_actor INT)
BEGIN
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    SELECT '该用户已注销' AS uploader_name,track_status,COUNT(*) AS track_count
    FROM tracks WHERE track_uploader_id IS NULL
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin')
    GROUP BY track_status;
END$$

DELIMITER ;
