# -*- coding: utf-8 -*-
"""端到端验证：检查 secondhand 库现状，并在进程内走通交易闭环。

匹配当前 app.py / database/schema.sql 的真实接口与字段。
"""
import io
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

import db
from app import app

app.config["TESTING"] = True
client = app.test_client()


def post(path, **data):
    return client.post(path, data=data, follow_redirects=True)


# 1. 现状检查：表与演示数据
tables = [r["TABLE_NAME"] for r in db.query_all(
    "SELECT TABLE_NAME FROM information_schema.tables "
    "WHERE TABLE_SCHEMA='secondhand'")]
print("现有数据表:", sorted(tables))
print("用户数:", db.query_one("SELECT COUNT(*) c FROM users")["c"])
print("分类数:", db.query_one("SELECT COUNT(*) c FROM categories")["c"])
print("商品数:", db.query_one("SELECT COUNT(*) c FROM products")["c"])

# 2. 闭环测试：注册 -> 发布 -> 充值 -> 下单 -> 支付 -> 收货
import random
sfx = random.randint(100000, 999999)
seller = {"username": f"s{sfx}", "password": "pass1234",
          "nickname": f"测试卖家{sfx}", "phone": f"139{sfx % 100000:05d}1"}
buyer = {"username": f"b{sfx}", "password": "pass1234",
         "nickname": f"测试买家{sfx}", "phone": f"139{sfx % 100000:05d}2"}

print("注册卖家:", post("/register", **seller).status_code)
print("注册买家:", post("/register", **buyer).status_code)

# 卖家发布
post("/login", username=seller["username"], password="pass1234")
post("/publish", title=f"验证商品{sfx}", description="端到端验证用商品",
     price="100.00", category_id="1", condition_level="9成新", image_url="")
pid = db.query_one("SELECT id FROM products WHERE title=%s",
                   (f"验证商品{sfx}",))["id"]
print("发布商品 id =", pid,
      "| 状态 =", db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"])
client.get("/logout")

# 买家充值 + 下单
post("/login", username=buyer["username"], password="pass1234")
post("/wallet/recharge", amount="500")
buyer_row = db.query_one("SELECT * FROM users WHERE username=%s", (buyer["username"],))
print("买家充值后余额 =", buyer_row["balance"])

post("/order/create", product_id=str(pid), address="松园3栋")
order = db.query_one("SELECT * FROM orders WHERE product_id=%s ORDER BY id DESC LIMIT 1", (pid,))
oid = order["id"]
print("下单后 订单状态 =", order["status"],
      "| 商品状态 =", db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"])

# 支付
post(f"/order/{oid}/pay")
print("支付后 订单状态 =",
      db.query_one("SELECT status FROM orders WHERE id=%s", (oid,))["status"],
      "| 支付流水 =",
      db.query_one("SELECT status FROM payments WHERE order_id=%s", (oid,))["status"])

# 确认收货
post(f"/order/{oid}/complete")
seller_row = db.query_one("SELECT * FROM users WHERE username=%s", (seller["username"],))
print("收货后 订单状态 =",
      db.query_one("SELECT status FROM orders WHERE id=%s", (oid,))["status"],
      "| 商品状态 =",
      db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"],
      "| 卖家余额 =", seller_row["balance"])

print("首页状态码 =", client.get("/").status_code)
print("商品详情状态码 =", client.get(f"/product/{pid}").status_code)

# 3. 清理测试数据
db.execute("DELETE FROM payments WHERE order_id=%s", (oid,))
db.execute("DELETE FROM orders WHERE id=%s", (oid,))
db.execute("DELETE FROM products WHERE id=%s", (pid,))
db.execute("DELETE FROM users WHERE username IN (%s,%s)",
           (buyer["username"], seller["username"]))
print("清理完成，交易闭环全部通过 OK")