USE shiyin;
-- 按功能分组的存储过程。安装一次后通过CALL调用，不会自动调用业务功能。
-- p_actor必须由后端从登录会话获取，不能相信客户端传入的编号。
-- 写入过程独立管理事务，请勿在已有事务中调用。
DELIMITER $$

CREATE PROCEDURE sp_add_playlist_track(IN p_actor INT, IN p_playlist INT, IN p_track INT)
BEGIN
    IF @@session.in_transaction = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '请在已有事务外调用此过程';
    END IF;
    BEGIN
        DECLARE v_owner INT;
        DECLARE v_status VARCHAR(16) DEFAULT NULL;
        DECLARE v_position BIGINT;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        START TRANSACTION;
        SET v_owner = NULL;
        SELECT playlist_creator_id INTO v_owner FROM playlists
        WHERE playlist_id=p_playlist FOR UPDATE;
        IF v_owner IS NULL OR NOT (v_owner <=> p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='歌单不存在或不属于当前用户';
        END IF;
        SELECT track_status INTO v_status FROM tracks WHERE track_id=p_track FOR UPDATE;
        IF v_status IS NULL OR v_status <> 'approved' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='只能添加审核通过的音乐';
        END IF;
        SELECT COALESCE(MAX(position),0)+1 INTO v_position FROM playlist_tracks WHERE playlist_id=p_playlist;
        IF v_position>2147483647 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='歌单位置超过INT上限';
        END IF;
        INSERT INTO playlist_tracks(playlist_id,track_id,position) VALUES(p_playlist,p_track,v_position);
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_remove_playlist_track(IN p_actor INT, IN p_playlist INT, IN p_track INT)
BEGIN
    IF @@session.in_transaction = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '请在已有事务外调用此过程';
    END IF;
    BEGIN
        DECLARE v_owner INT;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        START TRANSACTION;
        SET v_owner = NULL;
        SELECT playlist_creator_id INTO v_owner FROM playlists
        WHERE playlist_id=p_playlist FOR UPDATE;
        IF v_owner IS NULL OR NOT (v_owner <=> p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='歌单不存在或不属于当前用户';
        END IF;
        DELETE FROM playlist_tracks WHERE playlist_id=p_playlist AND track_id=p_track;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_swap_playlist_tracks(IN p_actor INT, IN p_playlist INT, IN p_track_a INT, IN p_track_b INT)
BEGIN
    IF @@session.in_transaction = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '请在已有事务外调用此过程';
    END IF;
    BEGIN
        DECLARE v_owner INT;
        DECLARE v_a INT DEFAULT NULL;
        DECLARE v_b INT DEFAULT NULL;
        DECLARE v_temp BIGINT;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        START TRANSACTION;
        SET v_owner = NULL;
        SELECT playlist_creator_id INTO v_owner FROM playlists
        WHERE playlist_id=p_playlist FOR UPDATE;
        IF v_owner IS NULL OR NOT (v_owner <=> p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='歌单不存在或不属于当前用户';
        END IF;
        SELECT position INTO v_a FROM playlist_tracks WHERE playlist_id=p_playlist AND track_id=p_track_a;
        SELECT position INTO v_b FROM playlist_tracks WHERE playlist_id=p_playlist AND track_id=p_track_b;
        IF v_a IS NULL OR v_b IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要交换的音乐不在歌单内';
        END IF;
        SELECT COALESCE(MAX(position),0)+1 INTO v_temp FROM playlist_tracks WHERE playlist_id=p_playlist;
        IF v_temp>2147483647 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='没有可用临时位置';
        END IF;
        -- 使用未被占用的正数临时位置，避免即时唯一检查造成交换失败。
        UPDATE playlist_tracks SET position=v_temp WHERE playlist_id=p_playlist AND track_id=p_track_a;
        UPDATE playlist_tracks SET position=v_a WHERE playlist_id=p_playlist AND track_id=p_track_b;
        UPDATE playlist_tracks SET position=v_b WHERE playlist_id=p_playlist AND track_id=p_track_a;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_favorite_playlist(IN p_actor INT, IN p_playlist INT)
BEGIN
    IF @@session.in_transaction = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '请在已有事务外调用此过程';
    END IF;
    BEGIN
        DECLARE v_public TINYINT DEFAULT NULL;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        START TRANSACTION;
        SELECT playlist_is_public INTO v_public FROM playlists WHERE playlist_id=p_playlist FOR UPDATE;
        IF v_public IS NULL OR v_public<>1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='只能收藏公开歌单';
        END IF;
        INSERT INTO playlist_favorites(user_id,playlist_id) VALUES(p_actor,p_playlist);
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_edit_playlist(IN p_actor INT, IN p_playlist INT, IN p_name VARCHAR(100), IN p_bio TEXT, IN p_public TINYINT)
BEGIN
    IF @@session.in_transaction = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '请在已有事务外调用此过程';
    END IF;
    BEGIN
        DECLARE v_owner INT;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        START TRANSACTION;
        SET v_owner = NULL;
        SELECT playlist_creator_id INTO v_owner FROM playlists
        WHERE playlist_id=p_playlist FOR UPDATE;
        IF v_owner IS NULL OR NOT (v_owner <=> p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='歌单不存在或不属于当前用户';
        END IF;
        IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='歌单名称不能为空';
        END IF;
        UPDATE playlists SET playlist_name=p_name,playlist_bio=p_bio,playlist_is_public=p_public
        WHERE playlist_id=p_playlist;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_create_playlist(IN p_actor INT, IN p_name VARCHAR(100), IN p_bio TEXT)
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
    IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='name不能为空';
    END IF;
    INSERT INTO playlists(playlist_creator_id,playlist_name,playlist_bio)
    VALUES(p_actor,p_name,p_bio);
    SELECT LAST_INSERT_ID() AS playlist_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_get_playlist(IN p_actor INT, IN p_playlist INT)
BEGIN
    SELECT p.* FROM playlists p WHERE p.playlist_id=p_playlist
    AND (p.playlist_is_public=1 OR p.playlist_creator_id=p_actor
         OR EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin'));
END$$

CREATE PROCEDURE sp_list_playlist_tracks(IN p_actor INT, IN p_playlist INT)
BEGIN
    SELECT pt.position,t.track_id,t.track_name,t.track_duration_seconds
    FROM playlist_tracks pt JOIN playlists p ON p.playlist_id=pt.playlist_id
    JOIN tracks t ON t.track_id=pt.track_id
    WHERE p.playlist_id=p_playlist AND t.track_status='approved'
    AND (p.playlist_is_public=1 OR p.playlist_creator_id=p_actor
         OR EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin'))
    ORDER BY pt.position;
END$$

CREATE PROCEDURE sp_list_my_playlists(IN p_actor INT)
BEGIN
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='用户不存在';
    END IF;
    SELECT * FROM playlists WHERE playlist_creator_id=p_actor ORDER BY playlist_created_time DESC;
END$$

CREATE PROCEDURE sp_list_my_favorites(IN p_actor INT)
BEGIN
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='用户不存在';
    END IF;
    SELECT p.*,f.created_time AS favorite_time
    FROM playlist_favorites f JOIN playlists p ON p.playlist_id=f.playlist_id
    WHERE f.user_id=p_actor
    AND (p.playlist_is_public=1 OR p.playlist_creator_id=f.user_id
         OR EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin'))
    ORDER BY f.created_time DESC;
END$$

CREATE PROCEDURE sp_cancel_favorite(IN p_actor INT, IN p_playlist INT)
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
    DELETE FROM playlist_favorites WHERE user_id=p_actor AND playlist_id=p_playlist;
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

CREATE PROCEDURE sp_delete_playlist(IN p_actor INT, IN p_playlist INT)
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
    DELETE FROM playlists WHERE playlist_id=p_playlist
    AND (playlist_creator_id=p_actor
         OR EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin'));
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

DELIMITER ;
