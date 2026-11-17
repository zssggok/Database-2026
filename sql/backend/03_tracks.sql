USE shiyin;
-- 按功能分组的存储过程。安装一次后通过CALL调用，不会自动调用业务功能。
-- p_actor必须由后端从登录会话获取，不能相信客户端传入的编号。
-- 写入过程独立管理事务，请勿在已有事务中调用。
DELIMITER $$

CREATE PROCEDURE sp_review_track(IN p_actor INT, IN p_track INT, IN p_status VARCHAR(16), IN p_comment TEXT)
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
        IF NOT EXISTS (SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
        END IF;
        IF p_status IS NULL OR BINARY p_status NOT IN ('approved','rejected') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='审核结果只能是approved或rejected';
        END IF;
        SELECT track_status INTO v_status FROM tracks WHERE track_id=p_track FOR UPDATE;
        IF v_status IS NULL OR v_status <> 'pending' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='只能审核待审核音乐';
        END IF;
        -- 暂不强制必须有歌手和标签；此规则仍待项目确认。
        UPDATE tracks SET track_status=p_status, track_reviewer_id=p_actor,
            track_reviewed_time=NOW(), track_review_comment=p_comment WHERE track_id=p_track;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_offline_track(IN p_actor INT, IN p_track INT)
BEGIN
    IF @@session.in_transaction = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '请在已有事务外调用此过程';
    END IF;
    BEGIN

        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
        END IF;
        UPDATE tracks SET track_status='offline' WHERE track_id=p_track AND track_status='approved';
        IF ROW_COUNT()=0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='音乐不存在或不是已通过状态';
        END IF;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_edit_track(IN p_actor INT, IN p_track INT, IN p_name VARCHAR(100),
IN p_seconds INT, IN p_path VARCHAR(1024), IN p_hash CHAR(64), IN p_album INT)
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
        SELECT track_uploader_id INTO v_owner FROM tracks
        WHERE track_id=p_track FOR UPDATE;
        IF v_owner IS NULL OR NOT (v_owner <=> p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='音乐不存在或不属于当前用户';
        END IF;
        IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 OR p_path IS NULL
           OR CHAR_LENGTH(TRIM(p_path))=0 OR p_hash IS NULL
           OR NOT REGEXP_LIKE(p_hash, '^[0-9A-Fa-f]{64}$', 'c') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='曲名、路径或音频哈希不合法';
        END IF;
        UPDATE tracks SET track_name=p_name, track_duration_seconds=p_seconds,
            track_audio_path=p_path, track_audio_hash=LOWER(p_hash), track_album_id=p_album
        WHERE track_id=p_track;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_upload_track(IN p_actor INT, IN p_name VARCHAR(100), IN p_seconds INT,
IN p_path VARCHAR(1024), IN p_hash CHAR(64), IN p_album INT)
BEGIN
    IF @@session.in_transaction = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '请在已有事务外调用此过程';
    END IF;
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
        IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 OR p_path IS NULL
           OR CHAR_LENGTH(TRIM(p_path))=0 OR p_hash IS NULL
           OR NOT REGEXP_LIKE(p_hash, '^[0-9A-Fa-f]{64}$', 'c') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='曲名、路径或音频哈希不合法';
        END IF;
        INSERT INTO tracks(track_name,track_duration_seconds,track_audio_path,
            track_audio_hash,track_uploader_id,track_album_id)
        VALUES(p_name,p_seconds,p_path,LOWER(p_hash),p_actor,p_album);
        SELECT LAST_INSERT_ID() AS track_id;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_set_track_artist(IN p_actor INT, IN p_track INT, IN p_related INT, IN p_add TINYINT)
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
        SELECT track_uploader_id INTO v_owner FROM tracks
        WHERE track_id=p_track FOR UPDATE;
        IF v_owner IS NULL OR NOT (v_owner <=> p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='音乐不存在或不属于当前用户';
        END IF;
        IF p_add=1 THEN
            INSERT INTO track_artists(track_id,artist_id) VALUES(p_track,p_related);
        ELSEIF p_add=0 THEN
            DELETE FROM track_artists WHERE track_id=p_track AND artist_id=p_related;
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='操作只能为1添加或0移除';
        END IF;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_set_track_tag(IN p_actor INT, IN p_track INT, IN p_related INT, IN p_add TINYINT)
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
        SELECT track_uploader_id INTO v_owner FROM tracks
        WHERE track_id=p_track FOR UPDATE;
        IF v_owner IS NULL OR NOT (v_owner <=> p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='音乐不存在或不属于当前用户';
        END IF;
        IF p_add=1 THEN
            INSERT INTO track_tags(track_id,tag_id) VALUES(p_track,p_related);
        ELSEIF p_add=0 THEN
            DELETE FROM track_tags WHERE track_id=p_track AND tag_id=p_related;
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='操作只能为1添加或0移除';
        END IF;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_edit_track_full(
    IN p_actor INT, IN p_track INT, IN p_name VARCHAR(100),
    IN p_seconds INT, IN p_path VARCHAR(1024), IN p_hash CHAR(64),
    IN p_album INT, IN p_artists JSON, IN p_tags JSON
)
BEGIN
    IF @@session.in_transaction=1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='请在已有事务外调用此过程';
    END IF;
    BEGIN
        DECLARE v_owner INT DEFAULT NULL;
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;
        START TRANSACTION;
        SELECT track_uploader_id INTO v_owner FROM tracks WHERE track_id=p_track FOR UPDATE;
        IF v_owner IS NULL OR NOT(v_owner <=> p_actor) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='音乐不存在或不属于当前用户';
        END IF;
        IF p_artists IS NULL OR p_tags IS NULL
           OR JSON_TYPE(p_artists)<>'ARRAY' OR JSON_TYPE(p_tags)<>'ARRAY' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='歌手和标签必须是JSON数组';
        END IF;
        IF p_name IS NULL OR CHAR_LENGTH(TRIM(p_name))=0 OR p_path IS NULL
           OR CHAR_LENGTH(TRIM(p_path))=0 OR p_hash IS NULL
           OR NOT REGEXP_LIKE(p_hash,'^[0-9A-Fa-f]{64}$','c') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='音乐字段不合法';
        END IF;
        UPDATE tracks SET track_name=p_name,track_duration_seconds=p_seconds,
            track_audio_path=p_path,track_audio_hash=LOWER(p_hash),track_album_id=p_album,
            track_status='pending'
        WHERE track_id=p_track;
        DELETE FROM track_artists WHERE track_id=p_track;
        INSERT INTO track_artists(track_id,artist_id)
        SELECT p_track,j.id FROM JSON_TABLE(p_artists,'$[*]'
            COLUMNS(id INT PATH '$' ERROR ON ERROR)) j;
        DELETE FROM track_tags WHERE track_id=p_track;
        INSERT INTO track_tags(track_id,tag_id)
        SELECT p_track,j.id FROM JSON_TABLE(p_tags,'$[*]'
            COLUMNS(id INT PATH '$' ERROR ON ERROR)) j;
        COMMIT;
    END;
END$$

CREATE PROCEDURE sp_search_tracks(IN p_title VARCHAR(100), IN p_artist VARCHAR(100), IN p_tag INT)
BEGIN
    SELECT t.track_id,t.track_name,t.track_duration_seconds,t.track_audio_path,
           COALESCE(u.user_nickname,u.user_name,'该用户已注销') AS uploader_name
    FROM tracks t LEFT JOIN users u ON u.user_id=t.track_uploader_id
    WHERE t.track_status='approved'
      AND (p_title IS NULL OR t.track_name LIKE CONCAT('%',p_title,'%'))
      AND (p_artist IS NULL OR EXISTS(
          SELECT 1 FROM track_artists ta JOIN artists a ON a.artist_id=ta.artist_id
          WHERE ta.track_id=t.track_id AND a.artist_name LIKE CONCAT('%',p_artist,'%')))
      AND (p_tag IS NULL OR EXISTS(
          SELECT 1 FROM track_tags tt WHERE tt.track_id=t.track_id AND tt.tag_id=p_tag))
    ORDER BY t.track_created_time DESC,t.track_id DESC;
END$$

CREATE PROCEDURE sp_get_playable_track(IN p_track INT)
BEGIN
    SELECT track_id,track_name,track_audio_path FROM tracks
    WHERE track_id=p_track AND track_status='approved';
END$$

CREATE PROCEDURE sp_list_my_tracks(IN p_actor INT)
BEGIN
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='用户不存在';
    END IF;
    SELECT * FROM tracks WHERE track_uploader_id=p_actor ORDER BY track_created_time DESC;
END$$

CREATE PROCEDURE sp_list_pending_tracks(IN p_actor INT)
BEGIN
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='需要管理员权限';
    END IF;
    SELECT t.* FROM tracks t
    WHERE t.track_status='pending'
      AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin')
    ORDER BY t.track_created_time,t.track_id;
END$$

CREATE PROCEDURE sp_delete_track(IN p_actor INT, IN p_track INT)
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
    DELETE FROM tracks WHERE track_id=p_track
    AND EXISTS(SELECT 1 FROM users WHERE user_id=p_actor AND user_role='admin');
    SELECT ROW_COUNT() AS affected_rows;
    COMMIT;
END$$

DELIMITER ;
