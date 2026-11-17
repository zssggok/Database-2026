# 后端数据库代码

建表文件仍是上一级的 schema.sql；本目录按功能保存触发器、存储过程和索引。
这些脚本面向当前表结构和 MySQL 8.0.46。此次只整理文件，没有连接数据库执行，没有插入测试数据。

## 文件划分

| 文件 | 内容 | 存储过程数量 |
| --- | --- | --- |
| 01_triggers.sql | 新音乐待审，音乐及歌手、标签关联变化后重新审核 | — |
| 02_users.sql | 注册、登录查询、资料修改、注销、管理员赋权 | 5 |
| 03_tracks.sql | 上传、修改、审核、下架、检索、播放和删除音乐 | 12 |
| 04_playlists.sql | 创建和编辑歌单、曲目增删与排序、收藏和取消收藏 | 12 |
| 05_comments.sql | 发表评论、查询评论、删除评论 | 3 |
| 06_catalog.sql | 管理员维护歌手、专辑、标签及专辑歌手关联 | 11 |
| 07_statistics.sql | 热门公开歌单和管理员统计 | 4 |
| 08_indexes.sql | 可选的查询索引 | — |

共47个存储过程。原02_procedures.sql、03_queries.sql已拆分，不再使用；原04_indexes.sql改名为08_indexes.sql。
本次仅重新分组，47个过程的定义与整理前完全一致。01触发器和08索引不是存储过程，不使用CALL调用。

## 安装顺序

先完成上一级schema.sql建表。已有业务表不要重新建表。
安装前查看SHOW TRIGGERS FROM shiyin和SHOW PROCEDURE STATUS WHERE Db='shiyin'，确认没有同名对象。
如果曾经安装过旧版02和03文件，这些过程已经在数据库中，不要再执行以下同名过程安装文件。
文件改名不会改变已经安装的数据库对象，也不需要因为改名重新安装。
如需升级过程，应另行核对后给出迁移脚本，本目录不自动删除或覆盖数据库对象。

首次安装时，在MySQL命令行执行：

```sql
SOURCE D:/my_database/shiyin/sql/backend/01_triggers.sql;
SOURCE D:/my_database/shiyin/sql/backend/02_users.sql;
SOURCE D:/my_database/shiyin/sql/backend/03_tracks.sql;
SOURCE D:/my_database/shiyin/sql/backend/04_playlists.sql;
SOURCE D:/my_database/shiyin/sql/backend/05_comments.sql;
SOURCE D:/my_database/shiyin/sql/backend/06_catalog.sql;
SOURCE D:/my_database/shiyin/sql/backend/07_statistics.sql;
```

这些文件只安装功能，不会自动调用注册、删除等业务操作。
索引先用SHOW INDEX核对是否已有同名或等效索引，再按需执行08_indexes.sql。
若安装报错，停下查看原因及已安装对象，不要直接重复执行全部文件。

## 调用示例

以下仅展示格式，未执行。示例编号应替换成实际存在且有权限的数据编号。

```sql
-- 检索已通过音乐，不限制曲名、歌手、标签
CALL sp_search_tracks(NULL,NULL,NULL);
-- 曲名包含“夜”，不限制歌手和标签；%和_仍作为LIKE通配符
CALL sp_search_tracks('夜',NULL,NULL);
-- 管理员2审核音乐10通过
CALL sp_review_track(2,10,'approved','审核通过');
-- 用户3创建私有歌单，返回新编号
CALL sp_create_playlist(3,'学习时听','学习歌单');
-- 用户3添加已通过音乐10至自己的歌单5
CALL sp_add_playlist_track(3,5,10);
-- 用户3取消收藏歌单5
CALL sp_cancel_favorite(3,5);
-- 游客查看公开歌单5，当前用户编号为NULL
CALL sp_get_playlist(NULL,5);
-- 查询热门公开歌单，无参数也要写括号
CALL sp_list_hot_playlists();
```

p_actor表示当前登录用户编号，必须由后端从已认证会话中读取，传入编号本身不代表已认证。
sp_get_login_user仅查找账号及密码哈希，不代表登录成功；后端须用密码库验证，不将哈希返回给前端。
注册只创建普通用户，首位管理员需要受控初始化，不自动创建。
写入过程自己管理事务，不在调用方事务内调用。查询通常返回结果表；删除和修改返回affected_rows或changed_count；新建返回编号。
影响行数0可能表示不存在、无权限或数据未变化，具体按过程条件处理。数据库异常由后端转换成易懂提示。
sp_edit_track_full最后两个参数为全部歌手、标签编号的JSON数组，例如'[1,2]'，空数组'[]'表示清空。
普通字段和关联一次提交时使用full过程以确保整体回滚；该过程总会重新待审。
审核通过时是否强制存在歌手和标签仍待确认，目前不强制非空。

## 全部过程及参数

按签名中的顺序传参；IN表示输入参数，NULL仅用于允许为空或允许游客的参数。

### 02_users.sql

| 过程 | 输入参数（按顺序） |
| --- | --- |
| sp_register_user | IN p_name VARCHAR(7), IN p_email VARCHAR(50), IN p_hash VARCHAR(255), IN p_nickname VARCHAR(50) |
| sp_get_login_user | IN p_name VARCHAR(7) |
| sp_edit_user_profile | IN p_actor INT, IN p_nickname VARCHAR(50), IN p_bio TEXT |
| sp_delete_my_account | IN p_actor INT |
| sp_grant_admin | IN p_actor INT, IN p_target INT |

### 03_tracks.sql

| 过程 | 输入参数（按顺序） |
| --- | --- |
| sp_review_track | IN p_actor INT, IN p_track INT, IN p_status VARCHAR(16), IN p_comment TEXT |
| sp_offline_track | IN p_actor INT, IN p_track INT |
| sp_edit_track | IN p_actor INT, IN p_track INT, IN p_name VARCHAR(100), IN p_seconds INT, IN p_path VARCHAR(1024), IN p_hash CHAR(64), IN p_album INT |
| sp_upload_track | IN p_actor INT, IN p_name VARCHAR(100), IN p_seconds INT, IN p_path VARCHAR(1024), IN p_hash CHAR(64), IN p_album INT |
| sp_set_track_artist | IN p_actor INT, IN p_track INT, IN p_related INT, IN p_add TINYINT |
| sp_set_track_tag | IN p_actor INT, IN p_track INT, IN p_related INT, IN p_add TINYINT |
| sp_edit_track_full | IN p_actor INT, IN p_track INT, IN p_name VARCHAR(100), IN p_seconds INT, IN p_path VARCHAR(1024), IN p_hash CHAR(64), IN p_album INT, IN p_artists JSON, IN p_tags JSON |
| sp_search_tracks | IN p_title VARCHAR(100), IN p_artist VARCHAR(100), IN p_tag INT |
| sp_get_playable_track | IN p_track INT |
| sp_list_my_tracks | IN p_actor INT |
| sp_list_pending_tracks | IN p_actor INT |
| sp_delete_track | IN p_actor INT, IN p_track INT |

### 04_playlists.sql

| 过程 | 输入参数（按顺序） |
| --- | --- |
| sp_add_playlist_track | IN p_actor INT, IN p_playlist INT, IN p_track INT |
| sp_remove_playlist_track | IN p_actor INT, IN p_playlist INT, IN p_track INT |
| sp_swap_playlist_tracks | IN p_actor INT, IN p_playlist INT, IN p_track_a INT, IN p_track_b INT |
| sp_favorite_playlist | IN p_actor INT, IN p_playlist INT |
| sp_edit_playlist | IN p_actor INT, IN p_playlist INT, IN p_name VARCHAR(100), IN p_bio TEXT, IN p_public TINYINT |
| sp_create_playlist | IN p_actor INT, IN p_name VARCHAR(100), IN p_bio TEXT |
| sp_get_playlist | IN p_actor INT, IN p_playlist INT |
| sp_list_playlist_tracks | IN p_actor INT, IN p_playlist INT |
| sp_list_my_playlists | IN p_actor INT |
| sp_list_my_favorites | IN p_actor INT |
| sp_cancel_favorite | IN p_actor INT, IN p_playlist INT |
| sp_delete_playlist | IN p_actor INT, IN p_playlist INT |

### 05_comments.sql

| 过程 | 输入参数（按顺序） |
| --- | --- |
| sp_add_comment | IN p_actor INT, IN p_track INT, IN p_content TEXT |
| sp_list_comments | IN p_actor INT, IN p_track INT |
| sp_delete_comment | IN p_actor INT, IN p_comment INT |

### 06_catalog.sql

| 过程 | 输入参数（按顺序） |
| --- | --- |
| sp_create_artist | IN p_actor INT, IN p_name VARCHAR(100), IN p_bio TEXT |
| sp_edit_artist | IN p_actor INT, IN p_id INT, IN p_name VARCHAR(100), IN p_bio TEXT |
| sp_delete_artist | IN p_actor INT, IN p_id INT |
| sp_create_album | IN p_actor INT, IN p_name VARCHAR(100), IN p_date DATE, IN p_bio TEXT |
| sp_edit_album | IN p_actor INT, IN p_id INT, IN p_name VARCHAR(100), IN p_date DATE, IN p_bio TEXT |
| sp_delete_album | IN p_actor INT, IN p_id INT |
| sp_create_tag | IN p_actor INT, IN p_name VARCHAR(50), IN p_description VARCHAR(255) |
| sp_edit_tag | IN p_actor INT, IN p_id INT, IN p_name VARCHAR(50), IN p_description VARCHAR(255) |
| sp_delete_tag | IN p_actor INT, IN p_id INT |
| sp_add_album_artist | IN p_actor INT, IN p_album INT, IN p_artist INT |
| sp_remove_album_artist | IN p_actor INT, IN p_album INT, IN p_artist INT |

### 07_statistics.sql

| 过程 | 输入参数（按顺序） |
| --- | --- |
| sp_list_hot_playlists | 无参数 |
| sp_stats_tags | IN p_actor INT |
| sp_stats_uploads | IN p_actor INT |
| sp_stats_deleted_uploads | IN p_actor INT |

## 规则由谁负责

数据库约束保证主键、唯一性、外键、状态范围和位置为正数。
存储过程检查权限/状态并锁定相关记录；触发器处理重新待审和清空旧审核信息。
写入过程自己开启、提交事务，异常时回滚；查询过程不主动提交事务。所有写入过程都禁止在已有事务中调用，避免隐式提交调用方的事务。
添加、移除、重排歌单曲目都先锁同一歌单；交换使用MAX(position)+1作为临时位置，并检查INT上限。
删除曲目后允许位置有间隔。直接写playlist_tracks的SQL可能绕过这些锁定规则，后端应统一使用过程。
音乐修改和关联修改先锁音乐；关联触发器更新音乐。死锁/锁超时可由后端有限次数重试完整请求。
收藏时锁定歌单并检查公开状态；唯一约束拒绝重复收藏。
直接SQL可绕过部分业务规则。数据库账号应限制给受信任后端，不能把数据库凭据交给普通用户。
传入p_actor并不证明身份；身份认证、管理员赋权入口、参数校验、文件访问、密码/音频哈希计算由后端负责。
注册只能写普通用户。首位管理员的初始化需要单独的受控操作，本目录不自动创建管理员。
数据库不验证音频内容与提交的哈希是否匹配。音频文件不随数据库级联自动删除。

## 查询和删除规则

公开检索只返回approved音乐；歌单内容也过滤其他状态。
评论在音乐非公开时仅向上传者与管理员返回。
收藏存在不代表仍有访问权；私有歌单仅向创建者和管理员返回。
保留注销用户的音乐、评论，用LEFT JOIN显示“该用户已注销”；用户创建的歌单与其收藏记录级联删除。
注销管理员后允许已审核音乐的审核人编号因外键SET NULL为空，保留旧审核结果。
MySQL的外键级联不会按普通UPDATE/DELETE方式执行关联表触发器；本设计不依赖级联触发重新审核。
未执行本机级联验证。删除关联本身仍会触发重新待审；删除音乐的级联关联不需要重新审核已删除音乐。
音乐表UPDATE触发器会要求approved/rejected有有效管理员；注销审核人后的孤立审核记录应先重新提交pending再修改。
正式接口需要确认注销前的身份并撤销会话；删除账号只是SQL层操作，不等于完整账号注销功能。

## 后续验证

按你的要求暂不插入数据、不运行测试。当前只完成代码编写与静态检查，未宣称运行通过。
之后应在隔离测试库安装当前schema和这些脚本，覆盖重复收藏、非公开音乐加入歌单、
权限越界、重新待审、联合筛选、评论可见性、用户删除、交换位置、异常回滚和并发冲突。
SHOW CREATE TABLE、SHOW CREATE TRIGGER和SHOW CREATE PROCEDURE可用于核对安装结果。
seed.sql、checks.sql以及完整前后端接口不在本次文件中。
