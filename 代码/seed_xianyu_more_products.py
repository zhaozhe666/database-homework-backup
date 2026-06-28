# -*- coding: utf-8 -*-
"""Import a second small batch of detailed Xianyu-style demo products."""

from db import get_cursor, query_one


PRODUCTS = [
    {
        "seller": "alice",
        "category": "服饰鞋包",
        "title": "江利达浅绿色双肩包",
        "description": (
            "江利达 JLD 浅绿色双肩包，OUR YOUTH 字母款。包身容量适中，日常可以放教材、"
            "笔记本、雨伞和水杯，适合上课、图书馆自习或短途通勤使用。肩带比较宽，背负感不勒肩，"
            "外观保存较好，适合想买一个轻便书包的同学。"
        ),
        "price": 19.00,
        "condition_level": "几乎全新",
        "images": [
            "/static/product_images/xianyu_seed_more/backpack_1.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/backpack_2.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/backpack_3.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/backpack_4.webp?v=more20260628",
        ],
    },
    {
        "seller": "bob",
        "category": "生活家居",
        "title": "宿舍可折叠床上小桌板",
        "description": (
            "宿舍床上用可折叠小桌板，桌面约 60cm x 40cm，高约 28cm。桌腿可以折叠收纳，"
            "桌面带卡槽和防滑挡条，可以放平板、书本或轻薄笔记本电脑。适合床上看网课、临时办公、"
            "整理资料，也适合宿舍空间比较紧的场景。"
        ),
        "price": 28.60,
        "condition_level": "全新",
        "images": [
            "/static/product_images/xianyu_seed_more/desk_1.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/desk_2.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/desk_3.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/desk_4.webp?v=more20260628",
        ],
    },
    {
        "seller": "carol",
        "category": "数码电子",
        "title": "美团 22.5W 快充充电宝",
        "description": (
            "美团共享款三线充电宝，容量约 7500mAh，支持 22.5W 快充。机身自带常用充电线，"
            "带 Type-C 充电口，可以反复充电使用。适合上课、图书馆自习、短途出门时给手机临时补电，"
            "页面标注带 3C 认证，可作为随身备用电源。"
        ),
        "price": 25.00,
        "condition_level": "95新",
        "images": [
            "/static/product_images/xianyu_seed_more/powerbank_1.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/powerbank_2.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/powerbank_3.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/powerbank_4.webp?v=more20260628",
        ],
    },
    {
        "seller": "jiji",
        "category": "其他",
        "title": "DEXIN BST 科学函数计算器",
        "description": (
            "DEXIN BST DC-1800N 科学函数计算器，浅蓝色外壳，带保护壳。支持三角函数、统计、"
            "排列组合、指数对数、双曲函数等常用计算，按键清晰，屏幕显示正常。适合高数、统计、"
            "工程计算和日常考试备考使用，价格低，作为备用计算器也合适。"
        ),
        "price": 4.90,
        "condition_level": "几乎全新",
        "images": [
            "/static/product_images/xianyu_seed_more/calculator_1.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/calculator_2.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/calculator_3.webp?v=more20260628",
            "/static/product_images/xianyu_seed_more/calculator_4.webp?v=more20260628",
        ],
    },
]


def main():
    inserted = 0
    with get_cursor(commit=True) as cur:
        for item in PRODUCTS:
            existing = query_one("SELECT id FROM products WHERE title=%s", (item["title"],))
            if existing:
                continue
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
            inserted += 1
    print("Imported %d detailed Xianyu-style demo products." % inserted)


if __name__ == "__main__":
    main()
