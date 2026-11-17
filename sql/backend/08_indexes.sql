USE shiyin;
-- 可选安装一次；已有同名或等效索引时先核对，不重复执行。
-- 不重复添加主键/唯一约束及外键已经建立的单列索引。
CREATE INDEX idx_tracks_status_created ON tracks(track_status,track_created_time);
CREATE INDEX idx_tracks_uploader_status ON tracks(track_uploader_id,track_status);
CREATE INDEX idx_comments_track_created ON comments(comment_track_id,comment_created_time);
-- 包含式LIKE '%关键词%'通常不能有效使用普通B-tree名称索引。
