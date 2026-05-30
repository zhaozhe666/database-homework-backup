/* ============================================================
   校园二手交易平台数据库设计 —— SQLite 运行版
   由 MySQL 8.0 版本适配而来，供 Flask 应用直接运行。

   适配要点：
   - ENUM            -> TEXT + CHECK 约束
   - BIGINT          -> INTEGER（配合 AUTOINCREMENT）
   - 生成列 STORED   -> SQLite GENERATED ALWAYS AS ... STORED
   - ON UPDATE 时间  -> AFTER UPDATE 触发器维护 updated_at
   - 外键级联        -> 需要 PRAGMA foreign_keys = ON
   ============================================================ */

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS favorites;
DROP TABLE IF EXISTS product_images;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;

-- 1. 用户表：平台主体，既可以是买家，也可以是卖家。
CREATE TABLE users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_no TEXT NOT NULL UNIQUE,
  username TEXT NOT NULL,
  real_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  email TEXT UNIQUE,
  campus TEXT NOT NULL,
  dormitory TEXT,
  credit_score INTEGER NOT NULL DEFAULT 100,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','frozen','graduated')),
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  CONSTRAINT chk_users_credit_score CHECK (credit_score BETWEEN 0 AND 100)
);

-- 2. 商品分类表：支持父子分类。
CREATE TABLE categories (
  category_id INTEGER PRIMARY KEY AUTOINCREMENT,
  parent_id INTEGER NULL,
  parent_key INTEGER GENERATED ALWAYS AS (IFNULL(parent_id, 0)) STORED,
  category_name TEXT NOT NULL,
  sort_no INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  CONSTRAINT uk_categories_parent_name UNIQUE (parent_key, category_name),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE ON DELETE SET NULL
);

-- 3. 商品表：卖家发布的闲置物品。
CREATE TABLE products (
  product_id INTEGER PRIMARY KEY AUTOINCREMENT,
  seller_id INTEGER NOT NULL,
  category_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  price REAL NOT NULL,
  original_price REAL NULL,
  condition_level TEXT NOT NULL DEFAULT 'good'
    CHECK (condition_level IN ('new','almost_new','good','used')),
  trade_place TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'on_sale'
    CHECK (status IN ('draft','on_sale','reserved','sold','removed')),
  view_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  CONSTRAINT fk_products_seller
    FOREIGN KEY (seller_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_products_price CHECK (price >= 0),
  CONSTRAINT chk_products_original_price CHECK (original_price IS NULL OR original_price >= price)
);

CREATE INDEX idx_products_category_status ON products(category_id, status);
CREATE INDEX idx_products_seller_status ON products(seller_id, status);
CREATE INDEX idx_products_title ON products(title);

-- 4. 商品图片表。
CREATE TABLE product_images (
  image_id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  image_url TEXT NOT NULL,
  is_cover INTEGER NOT NULL DEFAULT 0,
  sort_no INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  CONSTRAINT fk_product_images_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE INDEX idx_product_images_product ON product_images(product_id, sort_no);