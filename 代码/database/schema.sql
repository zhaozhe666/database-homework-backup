-- =====================================================================
-- 二手交易平台 数据库结构（MySQL 5.6 兼容）
-- 字符集 utf8mb4，存储引擎 InnoDB（支持外键与事务）
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
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户';

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
-- 状态机： on_sale(在售) -> locked(已下单锁定) -> sold(已售出)
--          on_sale -> removed(下架)
-- ---------------------------------------------------------------------
CREATE TABLE products (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  seller_id       INT UNSIGNED NOT NULL COMMENT '卖家',
  category_id     INT UNSIGNED DEFAULT NULL COMMENT '分类',
  title           VARCHAR(100) NOT NULL COMMENT '标题',
  description     TEXT COMMENT '描述',
  price           DECIMAL(10,2) NOT NULL COMMENT '售价',
  condition_level VARCHAR(20)  NOT NULL DEFAULT '9成新' COMMENT '新旧程度',
  image_url       VARCHAR(255) DEFAULT NULL COMMENT '图片地址',
  status          ENUM('on_sale','locked','sold','removed') NOT NULL DEFAULT 'on_sale',
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
-- 订单表
-- 状态机： created(待支付) -> paid(已支付/待收货) -> completed(已完成)
--          created -> cancelled(已取消)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_no     VARCHAR(32)  NOT NULL COMMENT '订单号',
  product_id   INT UNSIGNED NOT NULL,
  buyer_id     INT UNSIGNED NOT NULL,
  seller_id    INT UNSIGNED NOT NULL,
  amount       DECIMAL(10,2) NOT NULL COMMENT '成交金额',
  status       ENUM('created','paid','completed','cancelled') NOT NULL DEFAULT 'created',
  address      VARCHAR(255) DEFAULT NULL COMMENT '收货地址',
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at      DATETIME     DEFAULT NULL,
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
-- 基础分类数据
-- ---------------------------------------------------------------------
INSERT INTO categories (name) VALUES
('数码电子'),
('图书教材'),
('服饰鞋包'),
('运动户外'),
('生活家居'),
('美妆个护');