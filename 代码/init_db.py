# -*- coding: utf-8 -*-
"""初始化数据库：执行 schema.sql 建库建表，并写入演示用户与商品。

用法（确保 MySQL 服务已启动）：
    python init_db.py
"""

import os

from werkzeug.security import generate_password_hash

from config import DB_CONFIG
from db import get_connection

SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "database", "schema.sql")


def split_sql(text):
    """按分号拆分 SQL 语句，忽略注释行与空语句。"""
    statements = []
    buf = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("--"):
            continue
        buf.append(line)
        if stripped.endswith(";"):
            statements.append("\n".join(buf).rstrip(";\n "))
            buf = []
    if buf:
        statements.append("\n".join(buf).rstrip(";\n "))
    return [s for s in statements if s.strip()]


def run_schema():
    """执行 schema.sql（建库、建表、基础分类）。"""
    with open(SCHEMA_PATH, encoding="utf-8") as f:
        sql_text = f.read()

    conn = get_connection(use_database=False)
    try:
        with conn.cursor() as cur:
            for stmt in split_sql(sql_text):
                cur.execute(stmt)
        conn.commit()
    finally:
        conn.close()
    print("[OK] 数据库与数据表创建完成")


def seed_data():
    """写入演示用户与商品。"""
    users = [
        # username, password, nickname, phone, balance
        ("alice", "123456", "爱丽丝", "13800000001", 5000.00),
        ("bob", "123456", "小波", "13800000002", 5000.00),
        ("carol", "123456", "卡罗尔", "13800000003", 5000.00),
        ("admin", "admin123", "平台管理员", "13800000000", 0.00),
    ]
    # 商品： seller_username, category_name, title, desc, price, condition, image
    products = [
        ("alice", "数码电子", "iPhone 13 128G 蓝色",
         "国行正品，电池健康 89%，无磕碰，配原装充电线。", 3200.00, "95新",
         "/static/product_images/iphone13-blue.jpg"),
        ("alice", "图书教材", "《数据库系统概论》第5版",
         "王珊著，考研专业课用书，少量笔记，不影响阅读。", 25.00, "9成新",
         "/static/product_images/database-book.jpg"),
        ("bob", "数码电子", "罗技 MX Master 3 鼠标",
         "办公神器，手感极佳，含 USB 接收器。", 320.00, "95新",
         "/static/product_images/mouse.jpg"),
        ("bob", "运动户外", "迪卡侬 折叠自行车",
         "通勤代步，已骑半年，刹车变速正常。", 480.00, "8成新",
         "/static/product_images/folding-bike.jpg"),
        ("carol", "服饰鞋包", "Nike Air Force 1 白色 42码",
         "正品，穿过两次，鞋盒齐全。", 350.00, "99新",
         "/static/product_images/white-sneakers.jpg"),
        ("carol", "生活家居", "宜家台灯 暖光",
         "护眼台灯，三档亮度，搬家出。", 45.00, "9成新",
         "/static/product_images/desk-lamp.jpg"),
        ("bob", "其他", "宿舍折叠小桌板",
         "适合床上看书和放电脑，桌腿稳，桌面有轻微使用痕迹。", 28.00, "9成新",
         "/static/product_images/dorm-desk.jpg"),
    ]

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # 用户
            user_ids = {}
            for username, pwd, nickname, phone, balance in users:
                cur.execute(
                    "INSERT INTO users (username, password_hash, nickname, phone, balance) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (username, generate_password_hash(pwd), nickname, phone, balance),
                )
                user_ids[username] = cur.lastrowid
            cur.execute(
                "INSERT INTO admins "
                "(user_id, can_manage_products, can_manage_users, can_manage_admin_register) "
                "VALUES (%s, 1, 1, 1)",
                (user_ids["admin"],),
            )

            # 分类映射
            cur.execute("SELECT id, name FROM categories")
            cat_ids = {row["name"]: row["id"] for row in cur.fetchall()}

            # 商品
            for seller, cat, title, desc, price, cond, img in products:
                cur.execute(
                    "INSERT INTO products "
                    "(seller_id, category_id, title, description, price, condition_level, image_url) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                    (user_ids[seller], cat_ids.get(cat), title, desc, price, cond, img),
                )
                product_id = cur.lastrowid
                cur.execute(
                    "INSERT INTO product_images (product_id, image_url, is_cover, sort_no) "
                    "VALUES (%s, %s, 1, 0)",
                    (product_id, img),
                )
        conn.commit()
    finally:
        conn.close()
    print("[OK] 演示用户与商品写入完成")
    print("     演示账号： alice / bob / carol  密码均为 123456")
    print("     管理员： admin / admin123")


if __name__ == "__main__":
    print("连接 MySQL：%s:%s 数据库=%s" % (
        DB_CONFIG["host"], DB_CONFIG["port"], DB_CONFIG["database"]))
    run_schema()
    seed_data()
    print("全部初始化完成，可执行： python app.py")
