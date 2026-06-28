# -*- coding: utf-8 -*-
"""Import a small batch of Xianyu-style demo products.

This script is intentionally not called by app startup. Run it manually only
after reviewing docs/xianyu_seed_preview.md.
"""

from db import get_cursor, query_one


PRODUCTS = [
    {
        "seller": "alice",
        "category": "数码电子",
        "title": "得峰 14 寸笔记本电脑",
        "description": (
            "14 寸得峰笔记本，卖家描述接近全新，无拆修。适合日常办公、"
            "网课和轻量学习使用，带基础配件。"
        ),
        "price": 380.00,
        "condition_level": "几乎全新",
        "source": "https://www.goofish.com/item?id=1054485600131&categoryId=126854525",
        "images": [
            "/static/product_images/xianyu_seed/laptop_1.webp",
            "/static/product_images/xianyu_seed/laptop_2.webp",
            "/static/product_images/xianyu_seed/laptop_3.webp",
            "/static/product_images/xianyu_seed/laptop_4.webp",
        ],
    },
    {
        "seller": "alice",
        "category": "图书教材",
        "title": "数据库系统原理微课版二手教材",
        "description": (
            "人民邮电出版社《数据库系统原理（微课版）》二手教材，林子雨编著。"
            "适合数据库课程学习，书况约 85-95 新，可能有少量笔记。"
        ),
        "price": 16.56,
        "condition_level": "9成新",
        "source": "https://www.goofish.com/item?id=1058417267069&categoryId=127812005",
        "images": [
            "/static/product_images/xianyu_seed/book_1.webp",
            "/static/product_images/xianyu_seed/book_2.webp",
            "/static/product_images/xianyu_seed/book_3.webp",
            "/static/product_images/xianyu_seed/book_4.webp",
        ],
    },
    {
        "seller": "bob",
        "category": "生活家居",
        "title": "美式长臂夹子台灯",
        "description": (
            "长臂夹子台灯，USB 供电，三档色温、十级亮度调节。灯臂可调节，"
            "适合宿舍书桌、床边阅读和自习使用。"
        ),
        "price": 17.00,
        "condition_level": "全新",
        "source": "https://www.goofish.com/item?id=1041596683805&categoryId=126858406",
        "images": [
            "/static/product_images/xianyu_seed/lamp_1.webp",
            "/static/product_images/xianyu_seed/lamp_2.webp",
            "/static/product_images/xianyu_seed/lamp_3.webp",
            "/static/product_images/xianyu_seed/lamp_4.webp",
        ],
    },
    {
        "seller": "bob",
        "category": "数码电子",
        "title": "无线蓝牙鼠标",
        "description": (
            "无线蓝牙鼠标，支持笔记本和平板日常办公使用。静音按键，轻便小巧，"
            "适合宿舍、图书馆和课堂携带。"
        ),
        "price": 14.90,
        "condition_level": "全新",
        "source": "https://www.goofish.com/item?id=972079424141&categoryId=126856266",
        "images": [
            "/static/product_images/xianyu_seed/mouse_1.webp",
            "/static/product_images/xianyu_seed/mouse_2.webp",
            "/static/product_images/xianyu_seed/mouse_3.webp",
            "/static/product_images/xianyu_seed/mouse_4.webp",
        ],
    },
    {
        "seller": "carol",
        "category": "运动户外",
        "title": "BATTLE 26 寸山地自行车",
        "description": (
            "26 寸 BATTLE 山地车，21 速，铝合金车架，带后货架。"
            "刹车正常，适合校园通勤、买菜和短途代步。"
        ),
        "price": 100.00,
        "condition_level": "轻微使用痕迹",
        "source": "https://www.goofish.com/item?id=1062317545077&categoryId=127058035",
        "images": [
            "/static/product_images/xianyu_seed/bike_1.webp",
            "/static/product_images/xianyu_seed/bike_2.webp",
            "/static/product_images/xianyu_seed/bike_3.webp",
            "/static/product_images/xianyu_seed/bike_4.webp",
        ],
    },
    {
        "seller": "carol",
        "category": "服饰鞋包",
        "title": "黑色网面运动鞋 41 码",
        "description": (
            "黑色网面运动鞋，41 码，鞋面透气，适合日常运动、散步和校园通勤。"
            "鞋底有正常使用痕迹。"
        ),
        "price": 20.00,
        "condition_level": "轻微穿着痕迹",
        "source": "https://www.goofish.com/item?id=1060272516129&categoryId=126866685",
        "images": [
            "/static/product_images/xianyu_seed/shoes_1.webp",
            "/static/product_images/xianyu_seed/shoes_2.webp",
            "/static/product_images/xianyu_seed/shoes_3.webp",
            "/static/product_images/xianyu_seed/shoes_4.webp",
        ],
    },
    {
        "seller": "jiji",
        "category": "生活家居",
        "title": "米家电水壶 N1",
        "description": (
            "米家电水壶 N1，1.5L 容量，1500W 功率，304 不锈钢内胆。"
            "适合宿舍、办公室和日常烧水使用。"
        ),
        "price": 50.00,
        "condition_level": "全新",
        "source": "https://www.goofish.com/item?id=1038963540954&categoryId=126854875",
        "images": [
            "/static/product_images/xianyu_seed/kettle_1.webp",
            "/static/product_images/xianyu_seed/kettle_2.webp",
            "/static/product_images/xianyu_seed/kettle_3.webp",
            "/static/product_images/xianyu_seed/kettle_4.webp",
        ],
    },
    {
        "seller": "jiji",
        "category": "数码电子",
        "title": "有线机械手感键盘",
        "description": (
            "有线机械手感键盘，USB 接口，带背光，适合台式机和笔记本外接使用。"
            "适合宿舍学习、办公和轻度游戏。"
        ),
        "price": 27.00,
        "condition_level": "全新",
        "source": "https://www.goofish.com/item?id=1032927844654&categoryId=126856263",
        "images": [
            "/static/product_images/xianyu_seed/keyboard_1.webp",
            "/static/product_images/xianyu_seed/keyboard_2.webp",
            "/static/product_images/xianyu_seed/keyboard_3.webp",
            "/static/product_images/xianyu_seed/keyboard_4.webp",
        ],
    },
]


def main():
    with get_cursor(commit=True) as cur:
        for item in PRODUCTS:
            seller = query_one("SELECT id FROM users WHERE username=%s", (item["seller"],))
            category = query_one("SELECT id FROM categories WHERE name=%s", (item["category"],))
            if not seller:
                raise RuntimeError("Missing seller: %s" % item["seller"])
            if not category:
                raise RuntimeError("Missing category: %s" % item["category"])

            cur.execute(
                "INSERT INTO products "
                "(seller_id, category_id, title, description, price, condition_level, image_url, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, 'on_sale')",
                (
                    seller["id"],
                    category["id"],
                    item["title"],
                    item["description"],
                    item["price"],
                    item["condition_level"],
                    "|".join(item["images"]),
                ),
            )
            product_id = cur.lastrowid
            for sort_no, image_url in enumerate(item["images"][:4]):
                cur.execute(
                    "INSERT INTO product_images (product_id, image_url, is_cover, sort_no) "
                    "VALUES (%s, %s, %s, %s)",
                    (product_id, image_url, 1 if sort_no == 0 else 0, sort_no),
                )
    print("Imported %d Xianyu-style demo products." % len(PRODUCTS))


if __name__ == "__main__":
    main()
