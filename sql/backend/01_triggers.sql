USE shiyin;
-- 安装一次；重复安装会报“对象已存在”，不删除已有对象。
DELIMITER $$
CREATE TRIGGER tracks_before_insert
BEFORE INSERT ON tracks FOR EACH ROW
BEGIN
    SET NEW.track_status = 'pending';
    SET NEW.track_reviewer_id = NULL;
    SET NEW.track_reviewed_time = NULL;
    SET NEW.track_review_comment = NULL;
END$$

CREATE TRIGGER tracks_before_update
BEFORE UPDATE ON tracks FOR EACH ROW
BEGIN
    IF NOT (NEW.track_name <=> OLD.track_name)
       OR NOT (NEW.track_audio_path <=> OLD.track_audio_path)
       OR NOT (NEW.track_audio_hash <=> OLD.track_audio_hash)
       OR NOT (NEW.track_duration_seconds <=> OLD.track_duration_seconds)
       OR NOT (NEW.track_album_id <=> OLD.track_album_id) THEN
        SET NEW.track_status = 'pending';
    END IF;
    IF NEW.track_status = 'pending' THEN
        SET NEW.track_reviewer_id = NULL;
        SET NEW.track_reviewed_time = NULL;
        SET NEW.track_review_comment = NULL;
    ELSEIF NEW.track_status IN ('approved', 'rejected') THEN
        IF NEW.track_reviewer_id IS NULL OR NEW.track_reviewed_time IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '审核人和审核时间不能为空';
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM users
            WHERE user_id = NEW.track_reviewer_id AND user_role = 'admin'
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '审核人必须是管理员';
        END IF;
    END IF;
END$$

-- 关联变化后重新审核；外键级联动作不依赖这些触发器执行。
CREATE TRIGGER track_artists_after_insert
AFTER INSERT ON track_artists FOR EACH ROW
BEGIN
    UPDATE tracks SET track_status = 'pending' WHERE track_id = NEW.track_id;
END$$

-- 关联变化后重新审核；外键级联动作不依赖这些触发器执行。
CREATE TRIGGER track_artists_after_delete
AFTER DELETE ON track_artists FOR EACH ROW
BEGIN
    UPDATE tracks SET track_status = 'pending' WHERE track_id = OLD.track_id;
END$$

-- 关联变化后重新审核；外键级联动作不依赖这些触发器执行。
CREATE TRIGGER track_artists_after_update
AFTER UPDATE ON track_artists FOR EACH ROW
BEGIN
    UPDATE tracks SET track_status = 'pending' WHERE track_id = OLD.track_id;
    UPDATE tracks SET track_status = 'pending' WHERE track_id = NEW.track_id;
END$$

-- 关联变化后重新审核；外键级联动作不依赖这些触发器执行。
CREATE TRIGGER track_tags_after_insert
AFTER INSERT ON track_tags FOR EACH ROW
BEGIN
    UPDATE tracks SET track_status = 'pending' WHERE track_id = NEW.track_id;
END$$

-- 关联变化后重新审核；外键级联动作不依赖这些触发器执行。
CREATE TRIGGER track_tags_after_delete
AFTER DELETE ON track_tags FOR EACH ROW
BEGIN
    UPDATE tracks SET track_status = 'pending' WHERE track_id = OLD.track_id;
END$$

-- 关联变化后重新审核；外键级联动作不依赖这些触发器执行。
CREATE TRIGGER track_tags_after_update
AFTER UPDATE ON track_tags FOR EACH ROW
BEGIN
    UPDATE tracks SET track_status = 'pending' WHERE track_id = OLD.track_id;
    UPDATE tracks SET track_status = 'pending' WHERE track_id = NEW.track_id;
END$$
DELIMITER ;
