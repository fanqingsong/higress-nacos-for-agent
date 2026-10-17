-- 创建业务库 app（Flyway 连接此库执行迁移；库本身需先于应用存在）
CREATE DATABASE IF NOT EXISTS `app` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
