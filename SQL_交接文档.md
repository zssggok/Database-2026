# 拾音：SQL 交接文档

> 版本：2026-11-25。使用者：数据库负责人、后端开发者。
> 本文描述 MySQL 数据库调用接口，不是前端 HTTP 接口文档。签名来自本轮读取的 sql/backend/README.md；用户和音乐模块返回契约另据已读过程代码核对。歌单、评论、资料和统计模块尚未逐条读取完整定义，因此其结果结构明确标为待核对，不据过程名推测列名。
> 代码已编写不等于已安装或已运行通过。本轮未连接数据库，未修改 SQL。

## 1. 交接范围与安装

数据库名：shiyin；README 标注目标 MySQL 8.0.46。47 个过程按用户 5、音乐 12、歌单收藏 12、评论 3、资料 11、统计 4 划分。

先运行 SELECT VERSION()，核对表、过程与触发器是否已存在。schema.sql 只包含 USE shiyin 和 CREATE TABLE，数据库需预先存在。字符集、排序规则、引擎未在 schema 中显式指定，初始化时需核对 InnoDB 与 utf8mb4 等实际设置。

首次安装顺序：schema.sql → 01_triggers.sql → 02_users.sql → 03_tracks.sql → 04_playlists.sql → 05_comments.sql → 06_catalog.sql → 07_statistics.sql。08_indexes.sql 在 SHOW INDEX 确认无等效索引后按需执行。

MySQL 命令行示例（仅用于新测试库的首次安装，先处理第 9 节已知兼容问题）：

```sql
SELECT VERSION();
USE shiyin;
SOURCE D:/my_database/shiyin/sql/schema.sql;
SOURCE D:/my_database/shiyin/sql/backend/01_triggers.sql;
SOURCE D:/my_database/shiyin/sql/backend/02_users.sql;
SOURCE D:/my_database/shiyin/sql/backend/03_tracks.sql;
SOURCE D:/my_database/shiyin/sql/backend/04_playlists.sql;
SOURCE D:/my_database/shiyin/sql/backend/05_comments.sql;
SOURCE D:/my_database/shiyin/sql/backend/06_catalog.sql;
SOURCE D:/my_database/shiyin/sql/backend/07_statistics.sql;
```

已有业务表不要重新执行 schema；对象已存在不要重复安装或自动 DROP。文件改名不代表需要重装数据库对象，升级应给出明确迁移方案。脚本含 DELIMITER 客户端指令；应用连接不能把整份脚本直接当作一条 SQL 执行。

## 2. 后端统一调用规则

### 2.1 身份与参数

- 所有签名中的参数均为 IN，按列出的顺序传入；无参数的过程也需使用括号。
- p_actor 是后端从已认证会话取得的当前用户编号，不信任请求体中的 user_id、role 或 actor。
- 只有明确支持游客的查询才传 NULL 身份；不存在用户编号不应当作游客身份替代。
- 使用驱动的参数绑定功能，禁止把用户输入拼进 SQL 文本。CALL 占位符格式随驱动选择。
- 密码哈希由后端密码库生成和校验；音频哈希、文件路径、时长由后端处理，数据库不验证文件内容是否匹配提交值。
- 返回的数据库路径需由后端转换为受控访问方式；密码哈希、数据库凭据和本机路径不直接返回前端。

### 2.2 事务、连接和返回结果

写入过程独立管理事务。调用前确保连接不处于已有事务中，尤其留意驱动默认关闭 autocommit 的情况；不要通过提交未知事务来掩盖连接使用错误。查询过程通常不主动提交。

驱动须完整读取 CALL 的全部结果集及最终状态，再归还连接池。一个 SELECT 结果为空、SQL SIGNAL 报错和驱动异常是不同情况，不能统一视为“成功但无数据”。有的过程无 SELECT 成功载荷，后端需自行形成 HTTP 成功响应。

部分用户和音乐过程先 SELECT 返回编号/影响行数再 COMMIT；后端不能读到首个结果集就提前向前端报告成功，应等待整个调用成功结束。affected_rows=0 可能表示不存在、无权限或值未变化，按具体过程和接口语义处理。

数据库异常统一映射为面向产品的错误，例如重复数据、权限不足、对象不存在、外键仍被引用、输入不合法。不要把任意 SQL 详细异常直接发给前端。死锁或锁超时重试需以完整操作为单位，并防止重复上传文件等副作用。

### 2.3 本文返回契约的可信范围

标记“已读代码”的返回列可以作为当前对接依据，但仍需运行确认驱动类型与结果集处理。标记“待核对”的部分，仅交接签名、用途和规则，暂不能冻结 JSON 字段。

现有 README 对新建/修改/删除结果有通用说明，不能据此断言每个过程都返回相同字段。后端可以自行制定 JSON 字段名，不必向前端暴露表列名或过程名。

## 3. 接口清单

### 3.1 用户（02_users.sql，5 个）

#### sp_register_user

```sql
CALL sp_register_user(p_name, p_email, p_hash, p_nickname);
```

参数（均为 IN，顺序固定）：

```text
p_name VARCHAR(7), p_email VARCHAR(50), p_hash VARCHAR(255), p_nickname VARCHAR(50)
```

用途与规则：注册普通用户；名称、邮箱、哈希拒绝 NULL 和空白；数据库唯一约束拒绝重复用户名或邮箱。昵称可空。

返回：一行：user_id，新用户编号。 核对状态：已读代码。

#### sp_get_login_user

```sql
CALL sp_get_login_user(p_name);
```

参数（均为 IN，顺序固定）：

```text
p_name VARCHAR(7)
```

用途与规则：按用户名精确查询供后端验证密码；此过程本身不认证成功。

返回：0 或 1 行：user_id、user_name、user_password_hash、user_role。密码哈希仅供后端使用。 核对状态：已读代码。

#### sp_edit_user_profile

```sql
CALL sp_edit_user_profile(p_actor, p_nickname, p_bio);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_nickname VARCHAR(50), p_bio TEXT
```

用途与规则：当前用户修改自己的昵称、简介；两项可空，用户必须存在。

返回：一行：affected_rows。 核对状态：已读代码。

#### sp_delete_my_account

```sql
CALL sp_delete_my_account(p_actor);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT
```

用途与规则：删除当前账号；注销前身份确认、撤销会话和文件策略由后端处理。

返回：一行：affected_rows。 核对状态：已读代码。

#### sp_grant_admin

```sql
CALL sp_grant_admin(p_actor, p_target);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_target INT
```

用途与规则：操作者必须为管理员，将目标用户角色设为 admin；不是首位管理员初始化方式。

返回：一行：affected_rows；0 不区分目标不存在或已是管理员。 核对状态：已读代码。

### 3.2 音乐（03_tracks.sql，12 个）

#### sp_review_track

```sql
CALL sp_review_track(p_actor, p_track, p_status, p_comment);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT, p_status VARCHAR(16), p_comment TEXT
```

用途与规则：仅管理员审核 pending 音乐；p_status 只能为 approved/rejected，按大小写严格校验；意见可空。

返回：无 SELECT 成功载荷；失败通过 SIGNAL 报错。 核对状态：已读代码。

#### sp_offline_track

```sql
CALL sp_offline_track(p_actor, p_track);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT
```

用途与规则：仅管理员将 approved 音乐下架；不存在或状态不符时报错。

返回：无 SELECT 成功载荷。 核对状态：已读代码。

#### sp_edit_track

```sql
CALL sp_edit_track(p_actor, p_track, p_name, p_seconds, p_path, p_hash, p_album);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT, p_name VARCHAR(100), p_seconds INT, p_path VARCHAR(1024), p_hash CHAR(64), p_album INT
```

用途与规则：仅上传者修改基础字段；p_album 可 NULL 表示单曲，其余字段按完整值提供；哈希必须为 64 位十六进制，入库转小写。触发器在敏感字段实际改变时重置待审。

返回：无 SELECT 成功载荷。 核对状态：已读代码。

#### sp_upload_track

```sql
CALL sp_upload_track(p_actor, p_name, p_seconds, p_path, p_hash, p_album);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_name VARCHAR(100), p_seconds INT, p_path VARCHAR(1024), p_hash CHAR(64), p_album INT
```

用途与规则：上传者必须存在；保存基础音乐信息，不包含歌手/标签关联；p_album 可空。新增被触发器设为 pending。

返回：一行：track_id，新音乐编号。 核对状态：已读代码。

#### sp_set_track_artist

```sql
CALL sp_set_track_artist(p_actor, p_track, p_related, p_add);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT, p_related INT, p_add TINYINT
```

用途与规则：仅上传者；p_related 为歌手编号；p_add=1 添加，0 移除。实际关联变化触发重新待审。

返回：无 SELECT 成功载荷；移除不存在的关联可能无变化。 核对状态：已读代码。

#### sp_set_track_tag

```sql
CALL sp_set_track_tag(p_actor, p_track, p_related, p_add);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT, p_related INT, p_add TINYINT
```

用途与规则：仅上传者；p_related 为标签编号；p_add=1 添加，0 移除。实际关联变化触发重新待审。

返回：无 SELECT 成功载荷；移除不存在的关联可能无变化。 核对状态：已读代码。

#### sp_edit_track_full

```sql
CALL sp_edit_track_full(p_actor, p_track, p_name, p_seconds, p_path, p_hash, p_album, p_artists, p_tags);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT, p_name VARCHAR(100), p_seconds INT, p_path VARCHAR(1024), p_hash CHAR(64), p_album INT, p_artists JSON, p_tags JSON
```

用途与规则：仅上传者；同一事务替换基础信息与全部歌手/标签关联，并总是重新待审。两个 JSON 参数必须是数组；[] 清空，NULL 不代表保持原值；不传不存在或重复的编号。

返回：无 SELECT 成功载荷。 核对状态：已读代码。

#### sp_search_tracks

```sql
CALL sp_search_tracks(p_title, p_artist, p_tag);
```

参数（均为 IN，顺序固定）：

```text
p_title VARCHAR(100), p_artist VARCHAR(100), p_tag INT
```

用途与规则：公开检索 approved 音乐；各筛选可 NULL 表示不限，三者 AND；歌手/标签用 EXISTS；默认按上传时间与编号倒序，无分页参数。

返回：多行：track_id、track_name、track_duration_seconds、track_audio_path、uploader_name。 核对状态：已读代码。

#### sp_get_playable_track

```sql
CALL sp_get_playable_track(p_track);
```

参数（均为 IN，顺序固定）：

```text
p_track INT
```

用途与规则：仅查询 approved 音乐。此 SQL 只返回路径，实际读取/流式播放由后端实现。

返回：0 或 1 行：track_id、track_name、track_audio_path。 核对状态：已读代码。

#### sp_list_my_tracks

```sql
CALL sp_list_my_tracks(p_actor);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT
```

用途与规则：当前用户必须存在；返回其所有状态的上传记录。

返回：tracks 的全部列；按 track_created_time 倒序。不要把 SELECT * 结果未经筛选直接作为长期 HTTP 契约。 核对状态：已读代码。

#### sp_list_pending_tracks

```sql
CALL sp_list_pending_tracks(p_actor);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT
```

用途与规则：仅管理员；查询 pending 音乐，按上传时间、编号正序。

返回：tracks 的全部列。 核对状态：已读代码。

#### sp_delete_track

```sql
CALL sp_delete_track(p_actor, p_track);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT
```

用途与规则：当前仅管理员可删除；级联删除评论和关联，但不删除真实音频文件。

返回：一行：affected_rows。 核对状态：已读代码。

### 3.3 歌单与收藏（04_playlists.sql，12 个）

#### sp_add_playlist_track

```sql
CALL sp_add_playlist_track(p_actor, p_playlist, p_track);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT, p_track INT
```

用途与规则：仅创建者；只添加 approved 音乐；同一音乐不能重复加入。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_remove_playlist_track

```sql
CALL sp_remove_playlist_track(p_actor, p_playlist, p_track);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT, p_track INT
```

用途与规则：仅创建者；移除曲目，位置允许留间隔。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_swap_playlist_tracks

```sql
CALL sp_swap_playlist_tracks(p_actor, p_playlist, p_track_a, p_track_b);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT, p_track_a INT, p_track_b INT
```

用途与规则：仅创建者；交换歌单内两首曲目位置。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_favorite_playlist

```sql
CALL sp_favorite_playlist(p_actor, p_playlist);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT
```

用途与规则：登录用户收藏公开歌单；联合主键拒绝重复收藏。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_edit_playlist

```sql
CALL sp_edit_playlist(p_actor, p_playlist, p_name, p_bio, p_public);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT, p_name VARCHAR(100), p_bio TEXT, p_public TINYINT
```

用途与规则：创建者编辑歌单；p_public 为 0 私有或 1 公开；简介可空。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_create_playlist

```sql
CALL sp_create_playlist(p_actor, p_name, p_bio);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_name VARCHAR(100), p_bio TEXT
```

用途与规则：创建私有歌单；简介可空。

返回：README 说明返回新编号；具体列名与结果集待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_get_playlist

```sql
CALL sp_get_playlist(p_actor, p_playlist);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT
```

用途与规则：游客传 NULL 可查公开歌单；私有歌单仅创建者或管理员可访问。

返回：待核对，包括无权访问时是空集还是异常。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_list_playlist_tracks

```sql
CALL sp_list_playlist_tracks(p_actor, p_playlist);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT
```

用途与规则：按歌单可见性查询内容并按位置排序；README 说明过滤非 approved 音乐。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_list_my_playlists

```sql
CALL sp_list_my_playlists(p_actor);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT
```

用途与规则：查询当前用户创建的歌单。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_list_my_favorites

```sql
CALL sp_list_my_favorites(p_actor);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT
```

用途与规则：查询当前用户收藏；过滤当前不可访问的歌单。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_cancel_favorite

```sql
CALL sp_cancel_favorite(p_actor, p_playlist);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT
```

用途与规则：取消当前用户的一条收藏。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_delete_playlist

```sql
CALL sp_delete_playlist(p_actor, p_playlist);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_playlist INT
```

用途与规则：创建者删除自己的歌单，或管理员删除违规歌单；曲目、收藏级联删除。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

### 3.4 评论（05_comments.sql，3 个）

#### sp_add_comment

```sql
CALL sp_add_comment(p_actor, p_track, p_content);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT, p_content TEXT
```

用途与规则：登录用户对 approved 音乐发表评论；后端拒绝空白，具体过程长度校验待核对。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_list_comments

```sql
CALL sp_list_comments(p_actor, p_track);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_track INT
```

用途与规则：按音乐可见性查询；非公开音乐仅上传者和管理员可见；游客使用 NULL 身份的具体行为待过程确认。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_delete_comment

```sql
CALL sp_delete_comment(p_actor, p_comment);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_comment INT
```

用途与规则：评论作者或管理员删除评论。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

### 3.5 歌手、专辑与标签（06_catalog.sql，11 个）

#### sp_create_artist

```sql
CALL sp_create_artist(p_actor, p_name, p_bio);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_name VARCHAR(100), p_bio TEXT
```

用途与规则：管理员新增歌手，姓名不唯一，简介可空。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_edit_artist

```sql
CALL sp_edit_artist(p_actor, p_id, p_name, p_bio);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_id INT, p_name VARCHAR(100), p_bio TEXT
```

用途与规则：管理员编辑歌手。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_delete_artist

```sql
CALL sp_delete_artist(p_actor, p_id);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_id INT
```

用途与规则：管理员删除歌手，仍有音乐/专辑关联时外键限制。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_create_album

```sql
CALL sp_create_album(p_actor, p_name, p_date, p_bio);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_name VARCHAR(100), p_date DATE, p_bio TEXT
```

用途与规则：管理员新增专辑；名称不唯一，日期和简介可空。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_edit_album

```sql
CALL sp_edit_album(p_actor, p_id, p_name, p_date, p_bio);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_id INT, p_name VARCHAR(100), p_date DATE, p_bio TEXT
```

用途与规则：管理员编辑专辑。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_delete_album

```sql
CALL sp_delete_album(p_actor, p_id);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_id INT
```

用途与规则：管理员删除专辑，仍有音乐引用或专辑歌手关联时外键限制。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_create_tag

```sql
CALL sp_create_tag(p_actor, p_name, p_description);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_name VARCHAR(50), p_description VARCHAR(255)
```

用途与规则：管理员新增标签；名称唯一，说明可空。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_edit_tag

```sql
CALL sp_edit_tag(p_actor, p_id, p_name, p_description);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_id INT, p_name VARCHAR(50), p_description VARCHAR(255)
```

用途与规则：管理员编辑标签。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_delete_tag

```sql
CALL sp_delete_tag(p_actor, p_id);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_id INT
```

用途与规则：管理员删除标签，仍有音乐关联时外键限制。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_add_album_artist

```sql
CALL sp_add_album_artist(p_actor, p_album, p_artist);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_album INT, p_artist INT
```

用途与规则：管理员添加专辑与歌手关联。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_remove_album_artist

```sql
CALL sp_remove_album_artist(p_actor, p_album, p_artist);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT, p_album INT, p_artist INT
```

用途与规则：管理员移除专辑与歌手关联。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

### 3.6 统计（07_statistics.sql，4 个）

#### sp_list_hot_playlists

```sql
CALL sp_list_hot_playlists();
```

参数（均为 IN，顺序固定）：

无。

用途与规则：查询热门公开歌单，无参数。

返回：排序、收藏计数、返回列和数量限制均待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_stats_tags

```sql
CALL sp_stats_tags(p_actor);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT
```

用途与规则：管理员查询标签下音乐数量，按状态分类口径需与具体结果确认。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_stats_uploads

```sql
CALL sp_stats_uploads(p_actor);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT
```

用途与规则：管理员查询用户上传数量，按状态分类口径需与具体结果确认。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

#### sp_stats_deleted_uploads

```sql
CALL sp_stats_deleted_uploads(p_actor);
```

参数（均为 IN，顺序固定）：

```text
p_actor INT
```

用途与规则：管理员统计注销用户遗留音乐，单独处理空上传者。

返回：待核对。 核对状态：签名及用途据现有 README，过程正文未完整核对。

## 4. 触发器接口与隐式影响

触发器不能 CALL，安装后随对应表操作执行。

| 触发器 | 时机 | 影响 |
| --- | --- | --- |
| tracks_before_insert | BEFORE INSERT tracks | 强制 pending，清空最近审核人/时间/意见 |
| tracks_before_update | BEFORE UPDATE tracks | 曲名、时长、路径、哈希或专辑变化后 pending；pending 清空审核字段；approved/rejected 检查有效管理员及审核时间 |
| track_artists_after_insert | AFTER INSERT track_artists | 对应音乐重新待审 |
| track_artists_after_delete | AFTER DELETE track_artists | 对应音乐重新待审 |
| track_artists_after_update | AFTER UPDATE track_artists | 原、新音乐重新待审 |
| track_tags_after_insert | AFTER INSERT track_tags | 对应音乐重新待审 |
| track_tags_after_delete | AFTER DELETE track_tags | 对应音乐重新待审 |
| track_tags_after_update | AFTER UPDATE track_tags | 原、新音乐重新待审 |

音乐修改接口成功后，前端应刷新审核状态，不应继续显示为已通过。外键级联与手动 DELETE/UPDATE 的触发器行为不同；该实现不依赖级联时执行关联触发器。

## 5. 常见调用示例

以下 ID 均是占位业务数据，须替换为测试库真实记录。不是测试数据初始化脚本，不要原样在业务库批量执行。

```sql
-- 公开检索，不限条件
CALL sp_search_tracks(NULL, NULL, NULL);
-- 曲名和歌手同时包含关键词
CALL sp_search_tracks('夜', '周', NULL);
-- 登录查询：后端验证哈希后才能建立会话
CALL sp_get_login_user('demo');
-- 查看自己的上传
CALL sp_list_my_tracks(3);
-- 管理员审核
CALL sp_review_track(2, 10, 'approved', '审核通过');
-- 游客查看公开歌单
CALL sp_get_playlist(NULL, 5);
-- 创建者添加已通过音乐
CALL sp_add_playlist_track(3, 5, 10);
-- 交换歌单中两首音乐位置
CALL sp_swap_playlist_tracks(3, 5, 10, 11);
-- 一次替换音乐基础信息与完整关联（会重新待审）
CALL sp_edit_track_full(
  3, 10, '示例曲目', 180, 'audio/example.mp3',
  REPEAT('a', 64), NULL, '[1,2]', '[3]'
);
```

最后一个示例的哈希仅用于展示参数格式；真实上传必须由后端对文件计算哈希，不能使用占位值。

## 6. 从 SQL 接口到后端功能

| 后端操作 | 现有 SQL 支撑 | 后端补充职责 |
| --- | --- | --- |
| 注册 | sp_register_user | 输入校验、密码哈希、邮箱规范化、会话策略 |
| 登录 | sp_get_login_user | 校验密码、建立/撤销会话、避免暴露密码哈希 |
| 检索音乐 | sp_search_tracks | 参数规范化、稳定 JSON 转换；按需求补数据库分页 |
| 上传音乐 | sp_upload_track + 关联入口 | 文件保存、哈希、时长、整体失败补偿；确定完整上传事务入口 |
| 修改音乐及完整关联 | sp_edit_track_full | 上传者身份、参数转换、新旧文件处理 |
| 播放 | sp_get_playable_track | 受控文件访问、音频内容响应、支持播放器需要的范围请求 |
| 审核与下架 | sp_review_track / sp_offline_track | 从会话取得管理员编号、转换错误 |
| 歌单与收藏 | 对应歌单过程 | 所有权、可见性结果转换、页面刷新 |
| 评论 | 对应评论过程 | 输入校验、显示注销作者、转换错误 |
| 管理统计 | 对应统计过程 | 管理员入口、结果字段及统计口径说明 |

HTTP 请求不携带数据库密码、密码哈希、任意音频本机路径或可信操作者编号。一次页面操作可能需要一个组合数据库入口；不机械地将每个过程暴露为一个 HTTP 接口。

## 7. 后端接入前的验证清单

| 场景 | 预期 |
| --- | --- |
| 重复用户名/邮箱/音频哈希 | 唯一约束拒绝，后端返回易懂错误 |
| 普通用户调用审核/资料管理 | 拒绝 |
| 修改他人的音乐或歌单 | 拒绝 |
| 上传与修改音乐/歌手/标签 | 待审且旧审核信息清空 |
| 非 approved 音乐检索、播放、新增到歌单 | 不公开返回或拒绝 |
| 重复加入歌单、重复收藏 | 拒绝重复 |
| 私有歌单与转私有后的收藏 | 无权用户无法获取名称、简介与内容 |
| 非公开音乐评论 | 仅上传者和管理员可见 |
| 关联整体修改中任一步失败 | 音乐信息及关联整体回滚 |
| 歌单交换与并发添加 | 不发生位置重复；交换临时位置不溢出 |
| 删除用户及审核管理员 | 保留音乐和评论及历史审核结果；歌单和收藏级联清理 |
| 删除歌手/标签/专辑仍有引用 | 按外键策略拒绝 |
| 驱动调用 CALL 后继续使用连接 | 全部结果已消费，后续查询正常 |

核对对象使用 SHOW CREATE TABLE / SHOW CREATE PROCEDURE / SHOW CREATE TRIGGER；核对索引使用 SHOW INDEX。测试必须用隔离测试库。将实际验证结果记录为“环境、调用、预期、实际结果”，不要用代码静态存在代替运行证据。

## 8. 需要补充或冻结的 SQL 契约

以下是后续需求，不是已经存在的过程：

- 歌手、专辑、标签的列表/搜索与详情，供上传选择和后台列表使用。
- 完整音乐详情（基础信息、歌手、标签、专辑等）；音乐公开详情、上传者详情、管理员详情的可见字段需分别约定。
- 完整当前用户资料查询；登录查询目前不返回邮箱、昵称、简介。
- 管理员按全部状态浏览音乐；现有专用管理列表仅含 pending。
- 用户删除自己上传音乐：若保留选题目标，需要补权限入口，当前 sp_delete_track 仅管理员可用。
- 完整上传的事务入口：当前 sp_upload_track 只写基础记录，多个独立 CALL 无法保证基础记录与全部关联整体回滚。
- 列表分页、稳定排序和总数契约。不要先取全量结果再将应用切片作为长期方案。
- 歌单、评论、资料、统计模块全部返回列、SQL NULL、错误方式和影响行数语义，核对后再冻结 HTTP JSON 示例。

每个新增/变更入口由 SQL 负责人维护：签名、权限、允许 NULL、返回列、错误、事务边界、至少一组正常与失败样例；前后端共同确认后更新文档。

## 9. 当前已知问题与注意事项

1. 音乐模块使用 @@session.in_transaction；该系统变量不属于目标 MySQL 8.0 的同名系统变量接口，需修复兼容性后再安装。不要因为 MariaDB 支持就认为 MySQL 可用。本文未修改 SQL。
2. 当前各写过程事务前置检查不统一。后端不能依赖“所有过程都会主动拒绝嵌套事务”，必须在调用入口统一管理连接事务状态。
3. 管理员注销后审核人编号可以为空；当前 UPDATE 触发器又要求 approved/rejected 有有效管理员。需验证后续更新路径；重新提交 pending 可清空审核信息，但不应自动覆盖历史状态掩盖问题。
4. 音乐全量修改过程会无条件重新待审，即使最终信息相同；基础修改仅在触发器比较的字段改变时重新待审。
5. 用户名上限 7 字符、邮箱上限 50 字符是当前实现限制；前端、后端、表与过程必须一致。扩容需要同时修改相关签名和结构。
6. 审核通过暂不强制歌手/标签非空。需要更改时，先确认规则，再修改审核入口并测试。
7. 本文尚未完整核对的模块必须读取过程正文并运行后再作为最终交接契约；不得根据过程名称自行补造返回字段。

## 10. 与产品设计文档的关系

《拾音_设计文档.md》解释产品要做什么、表如何组织以及团队分工；本文解释后端如何调用当前 SQL。两份文件可以同时放仓库根目录，或同放 docs 目录。它们补充现有 sql/backend/README.md，不代替真实 SQL 定义；接口改变时需同步更新。
