USE shiyin;

-- 用户删除规则：保留其音乐和评论，对应用户编号设为NULL；删除其创建的歌单。
-- 删除审核管理员时保留审核状态、时间和意见，审核人编号设为NULL。
-- 用户编号为NULL时，应用显示“该用户已注销”，不能将数据归属给其他用户。

-- 1.用户表
-- user_id 用户编号
-- user_name 用户名
-- user_email 用户邮箱
-- user_password_hash 密码哈希
-- user_nickname 昵称
-- user_bio 简介
-- user_role 用户角色
-- user_created_time 注册时间
-- user_updated_time 修改时间
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    user_name VARCHAR(7) NOT NULL UNIQUE,
    user_email VARCHAR(50) NOT NULL UNIQUE,
    user_password_hash VARCHAR(255) NOT NULL,
    user_nickname VARCHAR(50),
    user_bio TEXT,
    user_role VARCHAR(16) NOT NULL DEFAULT 'user' CHECK (user_role IN ('user', 'admin')),
    user_created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_updated_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2.歌手表
-- artist_id 歌手编号
-- artist_name 歌手名字
-- artist_bio 歌手简介
-- artist_created_time 歌手资料创建时间
CREATE TABLE artists (
    artist_id INT PRIMARY KEY AUTO_INCREMENT,
    artist_name VARCHAR(100) NOT NULL,
    artist_bio TEXT,
    artist_created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3.专辑表
-- album_id 专辑编号
-- album_name 专辑名称
-- album_release_date 专辑发行日期
-- album_bio 专辑简介
-- album_created_time 专辑资料的创建时间
CREATE TABLE albums (
    album_id INT PRIMARY KEY AUTO_INCREMENT,
    album_name VARCHAR(100) NOT NULL,
    album_release_date DATE,
    album_bio TEXT,
    album_created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4.音乐表
-- track_id 音乐编号
-- track_name 曲名
-- track_duration_seconds 音乐时长，单位为秒，必须大于0
-- track_audio_path 音频文件路径
-- track_audio_hash 音频文件哈希值，用于防止重复上传
-- track_uploader_id 上传者的用户编号，关联用户表，用户删除后设为NULL
-- track_album_id 所属专辑编号，关联专辑表，可以为空表示单曲
-- track_status 审核状态：pending待审核、approved通过、rejected拒绝、offline下架
-- track_reviewer_id 最近审核人的用户编号，关联用户表，审核人删除后设为NULL
-- track_reviewed_time 最近审核时间
-- track_review_comment 最近审核意见
-- track_created_time 上传时间
-- track_updated_time 最近修改时间
CREATE TABLE tracks (
    track_id INT PRIMARY KEY AUTO_INCREMENT,
    track_name VARCHAR(100) NOT NULL,
    track_duration_seconds INT NOT NULL CHECK (track_duration_seconds > 0),
    track_audio_path VARCHAR(1024) NOT NULL,
    track_audio_hash CHAR(64) NOT NULL UNIQUE,
    track_uploader_id INT,
    track_album_id INT,
    track_status VARCHAR(16) NOT NULL DEFAULT 'pending'
        CHECK (track_status IN ('pending', 'approved', 'rejected', 'offline')),
    track_reviewer_id INT,
    track_reviewed_time DATETIME,
    track_review_comment TEXT,
    track_created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    track_updated_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (track_uploader_id) REFERENCES users(user_id)
        ON DELETE SET NULL,
    FOREIGN KEY (track_album_id) REFERENCES albums(album_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (track_reviewer_id) REFERENCES users(user_id)
        ON DELETE SET NULL
);

-- 5.歌单表
-- playlist_id 歌单编号
-- playlist_creator_id 创建者编号，删除创建者时同时删除歌单
-- playlist_name 歌单名称
-- playlist_bio 歌单简介
-- playlist_is_public 是否公开
-- playlist_created_time 创建时间
-- playlist_updated_time 最近修改时间
CREATE TABLE playlists (
    playlist_id INT PRIMARY KEY AUTO_INCREMENT,
    playlist_creator_id INT NOT NULL,
    playlist_name VARCHAR(100) NOT NULL,
    playlist_bio TEXT,
    playlist_is_public TINYINT NOT NULL DEFAULT 0
        CHECK (playlist_is_public IN (0, 1)),
    playlist_created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    playlist_updated_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (playlist_creator_id) REFERENCES users(user_id)
        ON DELETE CASCADE
);

-- 6.标签表
-- tag_id 标签编号
-- tag_name 标签名称，不能重复
-- tag_description 标签说明
CREATE TABLE tags (
    tag_id INT PRIMARY KEY AUTO_INCREMENT,
    tag_name VARCHAR(50) NOT NULL UNIQUE,
    tag_description VARCHAR(255)
);

-- 7.评论表
-- comment_id 评论编号
-- comment_user_id 评论者的用户编号，关联用户表，用户删除后设为NULL
-- comment_track_id 被评论的音乐编号，关联音乐表
-- comment_content 评论内容
-- comment_created_time 发表时间
CREATE TABLE comments (
    comment_id INT PRIMARY KEY AUTO_INCREMENT,
    comment_user_id INT,
    comment_track_id INT NOT NULL,
    comment_content TEXT NOT NULL,
    comment_created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (comment_user_id) REFERENCES users(user_id)
        ON DELETE SET NULL,
    FOREIGN KEY (comment_track_id) REFERENCES tracks(track_id)
        ON DELETE CASCADE
);

-- 8.音乐与歌手关联表
-- track_id 音乐编号，关联音乐表
-- artist_id 歌手编号，关联歌手表
CREATE TABLE track_artists (
    track_id INT NOT NULL,
    artist_id INT NOT NULL,

    PRIMARY KEY (track_id, artist_id),

    FOREIGN KEY (track_id) REFERENCES tracks(track_id)
        ON DELETE CASCADE,
    FOREIGN KEY (artist_id) REFERENCES artists(artist_id)
        ON DELETE RESTRICT
);

-- 9.专辑与歌手关联表
-- album_id 专辑编号，关联专辑表
-- artist_id 歌手编号，关联歌手表
CREATE TABLE album_artists (
    album_id INT NOT NULL,
    artist_id INT NOT NULL,

    PRIMARY KEY (album_id, artist_id),

    FOREIGN KEY (album_id) REFERENCES albums(album_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (artist_id) REFERENCES artists(artist_id)
        ON DELETE RESTRICT
);

-- 10.歌单与音乐关联表
-- playlist_id 歌单编号，关联歌单表
-- track_id 音乐编号，关联音乐表
-- position 音乐在歌单中的排列位置，从1开始
-- added_time 加入歌单的时间
CREATE TABLE playlist_tracks (
    playlist_id INT NOT NULL,
    track_id INT NOT NULL,
    position INT NOT NULL CHECK (position > 0),
    added_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (playlist_id, track_id),
    UNIQUE (playlist_id, position),

    FOREIGN KEY (playlist_id) REFERENCES playlists(playlist_id)
        ON DELETE CASCADE,
    FOREIGN KEY (track_id) REFERENCES tracks(track_id)
        ON DELETE CASCADE
);

-- 11.歌单收藏关联表
-- user_id 收藏者的用户编号，关联用户表
-- playlist_id 被收藏的歌单编号，关联歌单表
-- created_time 收藏时间
CREATE TABLE playlist_favorites (
    user_id INT NOT NULL,
    playlist_id INT NOT NULL,
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, playlist_id),

    FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE,
    FOREIGN KEY (playlist_id) REFERENCES playlists(playlist_id)
        ON DELETE CASCADE
);

-- 12.音乐与标签关联表
-- track_id 音乐编号，关联音乐表
-- tag_id 标签编号，关联标签表
CREATE TABLE track_tags (
    track_id INT NOT NULL,
    tag_id INT NOT NULL,

    PRIMARY KEY (track_id, tag_id),

    FOREIGN KEY (track_id) REFERENCES tracks(track_id)
        ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(tag_id)
        ON DELETE RESTRICT
);
