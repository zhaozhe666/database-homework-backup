/* ============================================================
   校园二手交易平台数据库设计 —— MySQL 5.6 运行版
   目标环境：本机 D:\BtSoft\mysql\MySQL5.6（实测 5.6.51-log），端口 3306

   为什么单独出这一版（8.0 脚本在 5.6 上会失败）：
   1. utf8mb4_0900_ai_ci 是 8.0 才有的排序规则 -> 改用 utf8mb4_general_ci
   2. 生成列 GENERATED ALWAYS AS ... STORED 是 5.7.6+ 才支持 -> 改用普通列 + 触发器维护
   3. CHECK 约束在 5.6 会被解析但静默忽略（等于没约束）-> 改用 BEFORE 触发器 + SIGNAL 真正拦截

   导入方式（PowerShell）：
   & "D:\BtSoft\mysql\MySQL5.6\bin\mysql.exe" -u root -p414290 < schema_mysql56.sql
   ============================================================ */

DROP DATABASE IF EXISTS campus_secondhand;
CREATE DATABASE campus_secondhand
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_general_ci;
USE campus_secondhand;

/* ============================================================
   一、核心数据表
   ============================================================ */

-- 1. 用户表：平台主体，既可以是买家，也可以是卖家。
CREATE TABLE users (
  user_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  student_no VARCHAR(20) NOT NULL UNIQUE COMMENT '学号',
  username VARCHAR(50) NOT NULL COMMENT '昵称',
  real_name VARCHAR(30) NOT NULL COMMENT '真实姓名，用于校内认证',
  password_hash VARCHAR(255) NOT NULL COMMENT '密码摘要',
  phone VARCHAR(20) NOT NULL UNIQUE COMMENT '手机号',
  email VARCHAR(80) UNIQUE COMMENT '邮箱',
  campus VARCHAR(50) NOT NULL COMMENT '校区',
  dormitory VARCHAR(80) COMMENT '宿舍楼或常用交易区域',
  credit_score INT NOT NULL DEFAULT 100 COMMENT '信用分',
  status ENUM('active','frozen','graduated') NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 2. 商品分类表：支持父子分类。parent_key 用触发器维护（5.6 无生成列），
--    目的是让 (parent_key, category_name) 唯一约束在“同一父级下不能重名”时生效。
CREATE TABLE categories (
  category_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  parent_id BIGINT NULL,
  parent_key BIGINT NOT NULL DEFAULT 0 COMMENT '由触发器维护：IFNULL(parent_id,0)',
  category_name VARCHAR(50) NOT NULL,
  sort_no INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_categories_parent_name UNIQUE (parent_key, category_name),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品分类表';

-- 3. 商品表：卖家发布的闲置物品。
CREATE TABLE products (
  product_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  seller_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL,
  title VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  original_price DECIMAL(10,2) NULL,
  condition_level ENUM('new','almost_new','good','used') NOT NULL DEFAULT 'good',
  trade_place VARCHAR(100) NOT NULL COMMENT '建议交易地点',
  status ENUM('draft','on_sale','reserved','sold','removed') NOT NULL DEFAULT 'on_sale',
  view_count INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_products_seller
    FOREIGN KEY (seller_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品表';

CREATE INDEX idx_products_category_status ON products(category_id, status);
CREATE INDEX idx_products_seller_status ON products(seller_id, status);
CREATE INDEX idx_products_title ON products(title);

-- 4. 商品图片表：一个商品可上传多张图片，封面图单独标记。
CREATE TABLE product_images (
  image_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT NOT NULL,
  image_url VARCHAR(255) NOT NULL,
  is_cover TINYINT(1) NOT NULL DEFAULT 0,
  sort_no INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_images_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品图片表';

CREATE INDEX idx_product_images_product ON product_images(product_id, sort_no);

-- 5. 收藏表：记录用户收藏商品，避免重复收藏。
CREATE TABLE favorites (
  favorite_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_favorites_user_product UNIQUE (user_id, product_id),
  CONSTRAINT fk_favorites_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_favorites_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收藏表';

-- 6. 订单表：记录买卖双方达成交易后的主订单。
CREATE TABLE orders (
  order_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_no VARCHAR(32) NOT NULL UNIQUE,
  buyer_id BIGINT NOT NULL,
  seller_id BIGINT NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  order_status ENUM('pending_payment','paid','completed','cancelled','refunded') NOT NULL DEFAULT 'pending_payment',
  trade_place VARCHAR(100) NOT NULL,
  remark VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at DATETIME NULL,
  completed_at DATETIME NULL,
  cancelled_at DATETIME NULL,
  CONSTRAINT fk_orders_buyer
    FOREIGN KEY (buyer_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_orders_seller
    FOREIGN KEY (seller_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

CREATE INDEX idx_orders_buyer_status ON orders(buyer_id, order_status, created_at);
CREATE INDEX idx_orders_seller_status ON orders(seller_id, order_status, created_at);

-- 7. 订单明细表：保留一单多商品能力，也便于记录成交价快照。
CREATE TABLE order_items (
  item_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  deal_price DECIMAL(10,2) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  CONSTRAINT uk_order_items_product UNIQUE (product_id),
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单明细表';

-- 8. 支付表：记录支付流水。课程设计中只模拟校内支付，不保存银行卡等敏感信息。
CREATE TABLE payments (
  payment_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL UNIQUE,
  pay_method ENUM('wechat','alipay','campus_card','cash') NOT NULL,
  pay_amount DECIMAL(10,2) NOT NULL,
  pay_status ENUM('unpaid','success','failed','refunded') NOT NULL DEFAULT 'unpaid',
  transaction_no VARCHAR(64) UNIQUE,
  paid_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='支付表';

-- 9. 评价表：订单完成后，买卖双方可互评。
CREATE TABLE reviews (
  review_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  reviewer_id BIGINT NOT NULL,
  target_user_id BIGINT NOT NULL,
  rating INT NOT NULL,
  content VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_reviews_order_reviewer UNIQUE (order_id, reviewer_id),
  CONSTRAINT fk_reviews_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_reviews_reviewer
    FOREIGN KEY (reviewer_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_reviews_target_user
    FOREIGN KEY (target_user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价表';

-- 10. 站内消息表：买卖双方围绕商品沟通。
CREATE TABLE messages (
  message_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  sender_id BIGINT NOT NULL,
  receiver_id BIGINT NOT NULL,
  product_id BIGINT NULL,
  content VARCHAR(1000) NOT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_messages_sender
    FOREIGN KEY (sender_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_messages_receiver
    FOREIGN KEY (receiver_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_messages_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='站内消息表';

CREATE INDEX idx_messages_receiver_read ON messages(receiver_id, is_read, created_at);
CREATE INDEX idx_messages_product_time ON messages(product_id, created_at);

/* ============================================================
   二、触发器：在 5.6 上补回 8.0 的“生成列 + CHECK 约束”能力
   用 SIGNAL 抛出 SQLSTATE '45000' 主动报错，等价于 CHECK 失败。
   ============================================================ */
DELIMITER $$

-- 维护 categories.parent_key（替代生成列）
CREATE TRIGGER trg_categories_bi BEFORE INSERT ON categories
FOR EACH ROW
BEGIN
  SET NEW.parent_key = IFNULL(NEW.parent_id, 0);
END$$

CREATE TRIGGER trg_categories_bu BEFORE UPDATE ON categories
FOR EACH ROW
BEGIN
  SET NEW.parent_key = IFNULL(NEW.parent_id, 0);
END$$

-- users.credit_score 必须在 0~100
CREATE TRIGGER trg_users_bi BEFORE INSERT ON users
FOR EACH ROW
BEGIN
  IF NEW.credit_score < 0 OR NEW.credit_score > 100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'credit_score 必须在 0 到 100 之间';
  END IF;
END$$

CREATE TRIGGER trg_users_bu BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
  IF NEW.credit_score < 0 OR NEW.credit_score > 100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'credit_score 必须在 0 到 100 之间';
  END IF;
END$$

-- products：价格非负，原价不低于现价
CREATE TRIGGER trg_products_bi BEFORE INSERT ON products
FOR EACH ROW
BEGIN
  IF NEW.price < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '商品价格不能为负';
  END IF;
  IF NEW.original_price IS NOT NULL AND NEW.original_price < NEW.price THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '原价不能低于现价';
  END IF;
END$$

CREATE TRIGGER trg_products_bu BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
  IF NEW.price < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '商品价格不能为负';
  END IF;
  IF NEW.original_price IS NOT NULL AND NEW.original_price < NEW.price THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '原价不能低于现价';
  END IF;
END$$

-- orders：金额非负，且买家不能等于卖家
CREATE TRIGGER trg_orders_bi BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
  IF NEW.total_amount < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '订单金额不能为负';
  END IF;
  IF NEW.buyer_id = NEW.seller_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '买家不能购买自己的商品';
  END IF;
END$$

-- order_items：成交价非负，数量为正
CREATE TRIGGER trg_order_items_bi BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
  IF NEW.deal_price < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '成交价不能为负';
  END IF;
  IF NEW.quantity <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '数量必须为正';
  END IF;
END$$

-- payments：金额非负
CREATE TRIGGER trg_payments_bi BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
  IF NEW.pay_amount < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '支付金额不能为负';
  END IF;
END$$

-- reviews：评分 1~5，且不能给自己评价
CREATE TRIGGER trg_reviews_bi BEFORE INSERT ON reviews
FOR EACH ROW
BEGIN
  IF NEW.rating < 1 OR NEW.rating > 5 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '评分必须在 1 到 5 之间';
  END IF;
  IF NEW.reviewer_id = NEW.target_user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '不能给自己评价';
  END IF;
END$$

-- messages：不能给自己发消息
CREATE TRIGGER trg_messages_bi BEFORE INSERT ON messages
FOR EACH ROW
BEGIN
  IF NEW.sender_id = NEW.receiver_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '不能给自己发送消息';
  END IF;
END$$

DELIMITER ;

/* ============================================================
   三、样例数据
   ============================================================ */

INSERT INTO users (student_no, username, real_name, password_hash, phone, email, campus, dormitory, credit_score) VALUES
('2023010101', '小林同学', '林晓雨', 'pbkdf2:sha256:demo$placeholder', '13800010001', 'linxy@example.edu.cn', '东校区', '松园3栋', 98),
('2023010102', '阿泽', '陈泽宇', 'pbkdf2:sha256:demo$placeholder', '13800010002', 'chenzy@example.edu.cn', '东校区', '竹园1栋', 95),
('2022010208', '南湖旧书铺', '王若楠', 'pbkdf2:sha256:demo$placeholder', '13800010003', 'wangrn@example.edu.cn', '西校区', '梅园5栋', 100),
('2024010306', '电子小能手', '赵明轩', 'pbkdf2:sha256:demo$placeholder', '13800010004', 'zhaomx@example.edu.cn', '东校区', '榕园2栋', 92);

INSERT INTO categories (parent_id, category_name, sort_no) VALUES
(NULL, '教材资料', 10),
(NULL, '数码电子', 20),
(NULL, '生活用品', 30),
(1, '专业教材', 11),
(1, '考试资料', 12),
(2, '电脑配件', 21),
(2, '耳机音箱', 22);

INSERT INTO products (seller_id, category_id, title, description, price, original_price, condition_level, trade_place, status) VALUES
(3, 4, '数据库系统概论第六版', '课程使用教材，少量笔记，不缺页，适合数据库原理课程。', 28.00, 59.00, 'good', '图书馆一楼大厅', 'on_sale'),
(4, 6, '罗技无线鼠标 M590', '按键正常，蓝牙和接收器均可用，附电池。', 45.00, 129.00, 'used', '东校区食堂门口', 'on_sale'),
(1, 7, '索尼入耳式耳机', '自用备用耳机，声音正常，已清洁。', 35.00, 99.00, 'good', '松园3栋楼下', 'reserved'),
(2, 3, '折叠收纳箱两个', '毕业整理闲置，适合宿舍使用。', 20.00, 50.00, 'used', '竹园快递站', 'sold');

INSERT INTO product_images (product_id, image_url, is_cover, sort_no) VALUES
(1, '/uploads/products/db-book-cover.jpg', 1, 1),
(2, '/uploads/products/mouse-cover.jpg', 1, 1),
(3, '/uploads/products/earphone-cover.jpg', 1, 1),
(4, '/uploads/products/box-cover.jpg', 1, 1);

INSERT INTO favorites (user_id, product_id) VALUES
(1, 2),
(2, 1),
(4, 1);

INSERT INTO orders (order_no, buyer_id, seller_id, total_amount, order_status, trade_place, paid_at, completed_at) VALUES
('SO202605170001', 1, 2, 20.00, 'completed', '竹园快递站', '2026-05-17 10:10:00', '2026-05-17 11:00:00'),
('SO202605170002', 2, 1, 35.00, 'paid', '松园3栋楼下', '2026-05-17 12:30:00', NULL);

INSERT INTO order_items (order_id, product_id, deal_price, quantity) VALUES
(1, 4, 20.00, 1),
(2, 3, 35.00, 1);

INSERT INTO payments (order_id, pay_method, pay_amount, pay_status, transaction_no, paid_at) VALUES
(1, 'wechat', 20.00, 'success', 'WX2026051710100001', '2026-05-17 10:10:00'),
(2, 'alipay', 35.00, 'success', 'ALI2026051712300002', '2026-05-17 12:30:00');

INSERT INTO reviews (order_id, reviewer_id, target_user_id, rating, content) VALUES
(1, 1, 2, 5, '交易很准时，物品和描述一致。'),
(1, 2, 1, 5, '买家沟通顺畅，付款及时。');

INSERT INTO messages (sender_id, receiver_id, product_id, content, is_read) VALUES
(1, 4, 2, '你好，鼠标还能再便宜一点吗？', 0),
(4, 1, 2, '可以小刀，东校区食堂门口交易方便。', 1),
(2, 3, 1, '数据库教材还在吗？有没有划线？', 0);

/* ============================================================
   四、业务视图
   ============================================================ */

CREATE OR REPLACE VIEW v_on_sale_products AS
SELECT
  p.product_id,
  p.title,
  p.price,
  p.condition_level,
  p.trade_place,
  p.view_count,
  p.created_at,
  c.category_name,
  u.username AS seller_name,
  u.campus
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN users u ON p.seller_id = u.user_id
WHERE p.status = 'on_sale';

CREATE OR REPLACE VIEW v_order_detail AS
SELECT
  o.order_no,
  o.order_status,
  buyer.username AS buyer_name,
  seller.username AS seller_name,
  p.title AS product_title,
  oi.deal_price,
  o.trade_place,
  o.created_at
FROM orders o
JOIN users buyer ON o.buyer_id = buyer.user_id
JOIN users seller ON o.seller_id = seller.user_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id;