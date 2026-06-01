-- =====================================================================
-- 校园二手交易平台数据库结构（MySQL 5.6 兼容）
-- 字符集：utf8mb4，存储引擎：InnoDB
-- =====================================================================

DROP DATABASE IF EXISTS secondhand;
CREATE DATABASE secondhand DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE secondhand;

-- ---------------------------------------------------------------------
-- 用户表
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username      VARCHAR(50)  NOT NULL COMMENT '登录账号',
  password_hash VARCHAR(255) NOT NULL COMMENT '加密后的密码',
  nickname      VARCHAR(50)  NOT NULL COMMENT '昵称',
  phone         VARCHAR(20)  DEFAULT NULL COMMENT '联系电话',
  balance       DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '钱包余额',
  is_active     TINYINT(1) NOT NULL DEFAULT 1 COMMENT '账号是否启用',
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户';

-- ---------------------------------------------------------------------
-- 管理员表：管理员是用户的一种扩展身份，并带独立后台权限。
-- ---------------------------------------------------------------------
CREATE TABLE admins (
  id                         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id                    INT UNSIGNED NOT NULL COMMENT '对应用户',
  can_manage_products        TINYINT(1) NOT NULL DEFAULT 1 COMMENT '商品管理权限',
  can_manage_users           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '用户管理权限',
  can_manage_admin_register  TINYINT(1) NOT NULL DEFAULT 1 COMMENT '管理员注册控制权限',
  created_by                 INT UNSIGNED DEFAULT NULL COMMENT '创建人',
  created_at                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_admin_user (user_id),
  KEY idx_admin_created_by (created_by),
  CONSTRAINT fk_admin_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_admin_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员';

-- ---------------------------------------------------------------------
-- 商品分类表
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(50)  NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品分类';

-- ---------------------------------------------------------------------
-- 商品表
-- 状态机：on_sale(在售) -> locked(已下单锁定) -> sold(已售出)
--        on_sale -> removed(下架)
-- image_url 保留为兼容缓存；正式多图关系见 product_images。
-- ---------------------------------------------------------------------
CREATE TABLE products (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  seller_id       INT UNSIGNED NOT NULL COMMENT '卖家',
  category_id     INT UNSIGNED DEFAULT NULL COMMENT '分类',
  title           VARCHAR(100) NOT NULL COMMENT '标题',
  description     TEXT COMMENT '描述',
  price           DECIMAL(10,2) NOT NULL COMMENT '售价',
  condition_level VARCHAR(20)  NOT NULL DEFAULT '9成新' COMMENT '新旧程度',
  image_url       TEXT DEFAULT NULL COMMENT '兼容缓存：多图路径用 | 分隔',
  status          ENUM('on_sale','locked','sold','removed') NOT NULL DEFAULT 'on_sale',
  removal_reason  VARCHAR(255) DEFAULT NULL COMMENT '下架原因',
  removed_by      INT UNSIGNED DEFAULT NULL COMMENT '下架操作人',
  removed_at      DATETIME DEFAULT NULL COMMENT '下架时间',
  view_count      INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '浏览量',
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_seller (seller_id),
  KEY idx_category (category_id),
  KEY idx_status (status),
  CONSTRAINT fk_product_seller   FOREIGN KEY (seller_id)   REFERENCES users(id),
  CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES categories(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品';

-- ---------------------------------------------------------------------
-- 商品图片表：一个商品可有多张图片，可标记封面并排序。
-- ---------------------------------------------------------------------
CREATE TABLE product_images (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id INT UNSIGNED NOT NULL,
  image_url  VARCHAR(500) NOT NULL COMMENT '图片地址',
  is_cover   TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否封面',
  sort_no    INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '排序',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_product_images_product (product_id, sort_no, id),
  CONSTRAINT fk_product_images_product
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品图片';

-- ---------------------------------------------------------------------
-- 收藏表：同一用户对同一商品只能收藏一次。
-- ---------------------------------------------------------------------
CREATE TABLE favorites (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    INT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_favorites_user_product (user_id, product_id),
  KEY idx_favorites_user (user_id, created_at),
  KEY idx_favorites_product (product_id),
  CONSTRAINT fk_favorites_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_favorites_product
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收藏';

-- ---------------------------------------------------------------------
-- 订单表
-- 状态机：created(待支付) -> paid(已支付/待发货)
--        created -> cancelled(已取消)
--        paid -> shipped(已发货/待收货) -> completed(已完成)
--        paid/shipped -> refund_requested(退款申请中) -> refunded(已退款)
--        refund_requested -> paid/shipped(买家撤回/卖家拒绝)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_no     VARCHAR(32)  NOT NULL COMMENT '订单号',
  product_id   INT UNSIGNED NOT NULL,
  buyer_id     INT UNSIGNED NOT NULL,
  seller_id    INT UNSIGNED NOT NULL,
  amount       DECIMAL(10,2) NOT NULL COMMENT '成交金额',
  status       ENUM('created','paid','shipped','refund_requested','refunded','completed','cancelled') NOT NULL DEFAULT 'created',
  address      VARCHAR(255) DEFAULT NULL COMMENT '收货地址',
  refund_reason VARCHAR(255) DEFAULT NULL COMMENT '退款原因',
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at      DATETIME     DEFAULT NULL,
  shipped_at   DATETIME     DEFAULT NULL,
  refund_requested_at DATETIME DEFAULT NULL,
  refunded_at  DATETIME     DEFAULT NULL,
  completed_at DATETIME     DEFAULT NULL,
  cancelled_at DATETIME     DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_order_no (order_no),
  KEY idx_buyer (buyer_id),
  KEY idx_seller (seller_id),
  KEY idx_product (product_id),
  CONSTRAINT fk_order_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT fk_order_buyer   FOREIGN KEY (buyer_id)   REFERENCES users(id),
  CONSTRAINT fk_order_seller  FOREIGN KEY (seller_id)  REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单';

-- ---------------------------------------------------------------------
-- 支付流水表（钱包余额支付，平台托管 -> 确认收货后打款给卖家）
-- ---------------------------------------------------------------------
CREATE TABLE payments (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id   INT UNSIGNED NOT NULL,
  amount     DECIMAL(10,2) NOT NULL,
  method     ENUM('balance') NOT NULL DEFAULT 'balance' COMMENT '支付方式',
  status     ENUM('success','failed') NOT NULL DEFAULT 'success',
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_order (order_id),
  CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES orders(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='支付流水';

-- ---------------------------------------------------------------------
-- 系统设置表：用于管理员注册开关等后台配置。
-- ---------------------------------------------------------------------
CREATE TABLE app_settings (
  setting_key   VARCHAR(80) NOT NULL,
  setting_value VARCHAR(255) NOT NULL,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (setting_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统设置';

INSERT INTO app_settings (setting_key, setting_value) VALUES
('admin_registration_enabled', '0');

-- ---------------------------------------------------------------------
-- 评价表：订单完成后，买卖双方可互评。
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id       INT UNSIGNED NOT NULL,
  reviewer_id    INT UNSIGNED NOT NULL COMMENT '评价人',
  target_user_id INT UNSIGNED NOT NULL COMMENT '被评价人',
  rating         TINYINT UNSIGNED NOT NULL COMMENT '1-5 分',
  content        VARCHAR(500) DEFAULT NULL COMMENT '评价内容',
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_reviews_order_reviewer (order_id, reviewer_id),
  KEY idx_reviews_target (target_user_id, created_at),
  CONSTRAINT fk_review_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_review_reviewer FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_review_target FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价';

-- ---------------------------------------------------------------------
-- 站内消息表：买卖双方围绕商品沟通。
-- ---------------------------------------------------------------------
CREATE TABLE messages (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  sender_id   INT UNSIGNED NOT NULL,
  receiver_id INT UNSIGNED NOT NULL,
  product_id  INT UNSIGNED DEFAULT NULL,
  content     VARCHAR(500) NOT NULL,
  is_read     TINYINT(1) NOT NULL DEFAULT 0,
  sender_deleted   TINYINT(1) NOT NULL DEFAULT 0 COMMENT '发送方是否隐藏该消息',
  receiver_deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '接收方是否隐藏该消息',
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_messages_receiver_read (receiver_id, is_read, created_at),
  KEY idx_messages_sender_time (sender_id, created_at),
  KEY idx_messages_product_time (product_id, created_at),
  CONSTRAINT fk_message_sender FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_message_receiver FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_message_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='站内消息';

-- ---------------------------------------------------------------------
-- 事件提醒表：记录订单、退款、评价、管理员操作等需要用户感知的变化。
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     INT UNSIGNED NOT NULL,
  actor_id    INT UNSIGNED DEFAULT NULL,
  order_id    INT UNSIGNED DEFAULT NULL,
  product_id  INT UNSIGNED DEFAULT NULL,
  notice_type VARCHAR(40) NOT NULL,
  title       VARCHAR(120) NOT NULL,
  content     VARCHAR(500) DEFAULT NULL,
  is_read     TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_notifications_user_read (user_id, is_read, created_at),
  KEY idx_notifications_order (order_id),
  KEY idx_notifications_product (product_id),
  CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_notification_actor FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_notification_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_notification_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='事件提醒';

-- ---------------------------------------------------------------------
-- 基础分类数据
-- ---------------------------------------------------------------------
INSERT INTO categories (name) VALUES
('数码电子'),
('图书教材'),
('服饰鞋包'),
('运动户外'),
('生活家居'),
('美妆个护'),
('其他');
