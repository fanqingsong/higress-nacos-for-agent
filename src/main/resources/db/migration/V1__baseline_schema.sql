-- 业务表结构基线（由 Flyway 管理；勿手工改库后不补迁移脚本）

CREATE TABLE `orders` (
  `id` VARCHAR(64) NOT NULL COMMENT '订单ID',
  `user_id` VARCHAR(64) NOT NULL COMMENT '用户ID',
  `product` VARCHAR(255) NOT NULL COMMENT '产品名称',
  `quantity` INT NOT NULL DEFAULT 1 COMMENT '数量',
  `price` DECIMAL(10,2) NOT NULL COMMENT '价格',
  `status` VARCHAR(32) NOT NULL DEFAULT 'pending' COMMENT '订单状态: pending, shipped, completed',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表';

CREATE TABLE `users` (
  `id` VARCHAR(64) NOT NULL COMMENT '用户ID',
  `name` VARCHAR(128) NOT NULL COMMENT '用户姓名',
  `email` VARCHAR(255) NOT NULL COMMENT '用户邮箱',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE INDEX `idx_email` (`email`),
  INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

CREATE TABLE `employees` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `name` VARCHAR(128) NOT NULL COMMENT '员工姓名',
  `position` VARCHAR(128) NOT NULL COMMENT '工作岗位',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='员工表';
