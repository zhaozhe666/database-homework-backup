/* ============================================================
   校园二手交易平台数据库设计
   Course Design: Campus Secondhand Trading Platform

   适用环境：MySQL 8.0+
   存储引擎：InnoDB
   字符集：utf8mb4

   设计目标：
   1. 支持学生发布闲置商品、收藏、沟通、下单、支付、交接和评价。
   2. 通过主键、外键、唯一约束和 CHECK 约束保证数据完整性。
   3. 提供样例数据、业务视图和典型查询，便于课程设计验收。

   执行方式：
   mysql -u root -p < 校园二手交易平台数据库设计.sql
   ============================================================ */

DROP DATABASE IF EXISTS campus_secondhand;
CREATE DATABASE campus_secondhand
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
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
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_users_credit_score CHECK (credit_score BETWEEN 0 AND 100)
) ENGINE=InnoDB COMMENT='用户表';

-- 2. 商品分类表：支持父子分类，便于后期扩展教材、电子产品、生活用品等分类。
CREATE TABLE categories (
  category_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  parent_id BIGINT NULL,
  parent_key BIGINT GENERATED ALWAYS AS (IFNULL(parent_id, 0)) STORED COMMENT '用于约束根分类名称唯一',
  category_name VARCHAR(50) NOT NULL,
  sort_no INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_categories_parent_name UNIQUE (parent_key, category_name),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB COMMENT='商品分类表';

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
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_products_price CHECK (price >= 0),
  CONSTRAINT chk_products_original_price CHECK (original_price IS NULL OR original_price >= price)
) ENGINE=InnoDB COMMENT='商品表';

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
) ENGINE=InnoDB COMMENT='商品图片表';

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
) ENGINE=InnoDB COMMENT='收藏表';

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
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_orders_amount CHECK (total_amount >= 0),
  CONSTRAINT chk_orders_not_self CHECK (buyer_id <> seller_id)
) ENGINE=InnoDB COMMENT='订单表';

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
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_order_items_price CHECK (deal_price >= 0),
  CONSTRAINT chk_order_items_quantity CHECK (quantity > 0)
) ENGINE=InnoDB COMMENT='订单明细表';

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
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT chk_payments_amount CHECK (pay_amount >= 0)
) ENGINE=InnoDB COMMENT='支付表';

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
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT chk_reviews_not_self CHECK (reviewer_id <> target_user_id)
) ENGINE=InnoDB COMMENT='评价表';

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
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT chk_messages_not_self CHECK (sender_id <> receiver_id)
) ENGINE=InnoDB COMMENT='站内消息表';

CREATE INDEX idx_messages_receiver_read ON messages(receiver_id, is_read, created_at);
CREATE INDEX idx_messages_product_time ON messages(product_id, created_at);

/* ============================================================
   二、样例数据
   数据覆盖教材、电子产品、生活用品、收藏、订单、支付、评价和消息。
   ============================================================ */

INSERT INTO users (student_no, username, real_name, password_hash, phone, email, campus, dormitory, credit_score) VALUES
('2023010101', '小林同学', '林晓雨', 'hash_demo_001', '13800010001', 'linxy@example.edu.cn', '东校区', '松园3栋', 98),
('2023010102', '阿泽', '陈泽宇', 'hash_demo_002', '13800010002', 'chenzy@example.edu.cn', '东校区', '竹园1栋', 95),
('2022010208', '南湖旧书铺', '王若楠', 'hash_demo_003', '13800010003', 'wangrn@example.edu.cn', '西校区', '梅园5栋', 100),
('2024010306', '电子小能手', '赵明轩', 'hash_demo_004', '13800010004', 'zhaomx@example.edu.cn', '东校区', '榕园2栋', 92);

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
   三、业务视图
   ============================================================ */

-- 视图 1：在售商品列表，供首页和搜索页使用。
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

-- 视图 2：订单明细视图，供订单管理页面使用。
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

/* ============================================================
   四、典型查询
   ============================================================ */

-- 典型查询 1：按关键词查询在售商品。
SELECT product_id, title, price, category_name, seller_name, trade_place
FROM v_on_sale_products
WHERE title LIKE '%数据库%' OR category_name LIKE '%教材%'
ORDER BY created_at DESC;

-- 典型查询 2：查询某个用户的购买订单。
SELECT order_no, order_status, product_title, deal_price, seller_name, trade_place, created_at
FROM v_order_detail
WHERE buyer_name = '小林同学'
ORDER BY created_at DESC;

-- 典型查询 3：查询用户未读消息数。
SELECT u.username, COUNT(m.message_id) AS unread_count
FROM users u
LEFT JOIN messages m ON u.user_id = m.receiver_id AND m.is_read = 0
GROUP BY u.user_id, u.username;

-- 典型查询 4：统计各分类在售商品数量。
SELECT c.category_name, COUNT(p.product_id) AS on_sale_count
FROM categories c
LEFT JOIN products p ON c.category_id = p.category_id AND p.status = 'on_sale'
GROUP BY c.category_id, c.category_name
ORDER BY on_sale_count DESC, c.sort_no;

/* ============================================================
   五、完整性测试语句（验收时可手动取消注释执行）
   这些语句预期会失败，用来证明约束生效。
   ============================================================ */

-- 测试 1：重复学号，预期违反 users.student_no 唯一约束。
-- INSERT INTO users (student_no, username, real_name, password_hash, phone, campus)
-- VALUES ('2023010101', '重复学号测试', '测试用户', 'hash_demo_x', '13800019999', '东校区');

-- 测试 2：用户购买自己的商品，预期违反 chk_orders_not_self。
-- INSERT INTO orders (order_no, buyer_id, seller_id, total_amount, trade_place)
-- VALUES ('SO202605179999', 1, 1, 10.00, '测试地点');

-- 测试 3：重复收藏同一商品，预期违反 uk_favorites_user_product。
-- INSERT INTO favorites (user_id, product_id) VALUES (1, 2);

-- 测试 4：评分超出范围，预期违反 chk_reviews_rating。
-- INSERT INTO reviews (order_id, reviewer_id, target_user_id, rating, content)
-- VALUES (2, 2, 1, 6, '评分越界测试');
