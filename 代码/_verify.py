# -*- coding: utf-8 -*-
"""端到端验证：检查 secondhand 库现状，并走通订单、退款、评价和消息流程。"""
import io
import random
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

import db
from app import app, ensure_runtime_schema

app.config["TESTING"] = True
client = app.test_client()
ensure_runtime_schema()


def post(path, **data):
    return client.post(path, data=data, follow_redirects=True)


def latest_order_id(product_id):
    return db.query_one(
        "SELECT id FROM orders WHERE product_id=%s ORDER BY id DESC LIMIT 1",
        (product_id,),
    )["id"]


tables = [r["TABLE_NAME"] for r in db.query_all(
    "SELECT TABLE_NAME FROM information_schema.tables "
    "WHERE TABLE_SCHEMA='secondhand'")]
print("现有数据表:", sorted(tables))
for table in ["product_images", "favorites", "reviews", "messages"]:
    assert table in tables
for column in ["refund_reason", "refund_requested_at", "refunded_at"]:
    assert db.query_one(
        "SELECT COUNT(*) c FROM information_schema.columns "
        "WHERE table_schema='secondhand' AND table_name='orders' AND column_name=%s",
        (column,),
    )["c"] == 1
for column in ["sender_deleted", "receiver_deleted"]:
    assert db.query_one(
        "SELECT COUNT(*) c FROM information_schema.columns "
        "WHERE table_schema='secondhand' AND table_name='messages' AND column_name=%s",
        (column,),
    )["c"] == 1
print("用户数:", db.query_one("SELECT COUNT(*) c FROM users")["c"])
print("分类数:", db.query_one("SELECT COUNT(*) c FROM categories")["c"])
print("商品数:", db.query_one("SELECT COUNT(*) c FROM products")["c"])


sfx = random.randint(100000, 999999)
seller = {"username": f"s{sfx}", "password": "pass1234",
          "nickname": f"测试卖家{sfx}", "phone": f"139{sfx % 100000:05d}1"}
buyer = {"username": f"b{sfx}", "password": "pass1234",
         "nickname": f"测试买家{sfx}", "phone": f"139{sfx % 100000:05d}2"}
buyer2 = {"username": f"c{sfx}", "password": "pass1234",
          "nickname": f"测试同学{sfx}", "phone": f"139{sfx % 100000:05d}3"}

print("注册卖家:", post("/register", **seller).status_code)
print("注册买家:", post("/register", **buyer).status_code)
print("注册同学:", post("/register", **buyer2).status_code)

post("/login", username=seller["username"], password="pass1234")
post("/publish", title=f"验证商品{sfx}", description="端到端验证用商品",
     price="100.00", category_id="1", condition_level="9成新",
     image_url="/static/product_images/iphone13-blue.jpg")
pid = db.query_one("SELECT id FROM products WHERE title=%s",
                   (f"验证商品{sfx}",))["id"]
print("发布商品 id =", pid,
      "| 状态 =", db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"])
assert db.query_one(
    "SELECT COUNT(*) c FROM product_images WHERE product_id=%s", (pid,))["c"] == 1
client.get("/logout")

post("/login", username=buyer["username"], password="pass1234")
post(f"/product/{pid}/favorite")
assert db.query_one("SELECT COUNT(*) c FROM favorites WHERE product_id=%s", (pid,))["c"] == 1
print("我的收藏页状态码 =", client.get("/me/favorites").status_code)
post(f"/product/{pid}/message", content="你好，想问一下这个商品还方便今天取吗？")
assert db.query_one("SELECT COUNT(*) c FROM messages WHERE product_id=%s", (pid,))["c"] == 1
print("我的消息页状态码 =", client.get("/me/messages").status_code)
client.get("/logout")

post("/login", username=buyer2["username"], password="pass1234")
post(f"/product/{pid}/message", content="同学你好，这个还在吗？")
assert db.query_one("SELECT COUNT(*) c FROM messages WHERE product_id=%s", (pid,))["c"] == 2
client.get("/logout")

post("/login", username=buyer["username"], password="pass1234")
post("/wallet/recharge", amount="500")
print("买家充值后余额 =",
      db.query_one("SELECT balance FROM users WHERE username=%s", (buyer["username"],))["balance"])

# 10 分钟未付款自动取消：造一个待支付订单，把下单时间推到 11 分钟前，再访问页面触发自动清理。
post("/order/create", product_id=str(pid), address="松园3栋")
timeout_oid = latest_order_id(pid)
db.execute("UPDATE orders SET created_at=DATE_SUB(NOW(), INTERVAL 11 MINUTE) WHERE id=%s", (timeout_oid,))
client.get("/")
timeout_order = db.query_one("SELECT status FROM orders WHERE id=%s", (timeout_oid,))
print("超时订单状态 =", timeout_order["status"],
      "| 商品状态 =", db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"])
assert timeout_order["status"] == "cancelled"
assert db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"] == "on_sale"

# 已付款后申请退款，卖家同意后退回买家余额，商品恢复在售。
post("/order/create", product_id=str(pid), address="松园3栋")
refund_oid = latest_order_id(pid)
post(f"/order/{refund_oid}/pay")
post(f"/order/{refund_oid}/refund/request", reason="临时不需要了")
print("申请退款后订单状态 =",
      db.query_one("SELECT status FROM orders WHERE id=%s", (refund_oid,))["status"])
assert db.query_one("SELECT status FROM orders WHERE id=%s", (refund_oid,))["status"] == "refund_requested"
client.get("/logout")

post("/login", username=seller["username"], password="pass1234")
seller_id = db.query_one("SELECT id FROM users WHERE username=%s", (seller["username"],))["id"]
buyer_id = db.query_one("SELECT id FROM users WHERE username=%s", (buyer["username"],))["id"]
buyer2_id = db.query_one("SELECT id FROM users WHERE username=%s", (buyer2["username"],))["id"]
assert db.query_one(
    "SELECT COUNT(*) c FROM messages "
    "WHERE receiver_id=%s AND is_read=0 AND receiver_deleted=0",
    (seller_id,),
)["c"] == 2
client.get(f"/me/messages?with_user={buyer_id}")
remaining_unread = db.query_one(
    "SELECT COUNT(*) c FROM messages "
    "WHERE receiver_id=%s AND is_read=0 AND receiver_deleted=0",
    (seller_id,),
)["c"]
print("点开一个对话后剩余未读 =", remaining_unread)
assert remaining_unread == 1
post(f"/message/conversation/{buyer2_id}/delete")
assert db.query_one(
    "SELECT COUNT(*) c FROM messages "
    "WHERE receiver_id=%s AND sender_id=%s AND receiver_deleted=0",
    (seller_id, buyer2_id),
)["c"] == 0
assert db.query_one(
    "SELECT COUNT(*) c FROM messages "
    "WHERE receiver_id=%s AND sender_id=%s AND receiver_deleted=0",
    (seller_id, buyer_id),
)["c"] == 1
print("删除单个对话后保留其他对话 OK")
print("提醒中心状态码 =", client.get("/me/notifications").status_code)
post(f"/order/{refund_oid}/refund/approve")
refund_order = db.query_one("SELECT status FROM orders WHERE id=%s", (refund_oid,))
buyer_balance_after_refund = db.query_one(
    "SELECT balance FROM users WHERE username=%s", (buyer["username"],))["balance"]
print("同意退款后订单状态 =", refund_order["status"],
      "| 买家余额 =", buyer_balance_after_refund,
      "| 商品状态 =", db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"])
assert refund_order["status"] == "refunded"
assert db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"] == "on_sale"
client.get("/logout")

# 再走一笔完整交易，确认原有支付、收货、评价流程没有被退款逻辑影响。
post("/login", username=buyer["username"], password="pass1234")
post("/order/create", product_id=str(pid), address="松园3栋")
complete_oid = latest_order_id(pid)
post(f"/order/{complete_oid}/pay")
post(f"/order/{complete_oid}/complete")
post(f"/order/{complete_oid}/review", rating="5", content="交易顺利，卖家沟通很及时。")
print("完成订单状态 =",
      db.query_one("SELECT status FROM orders WHERE id=%s", (complete_oid,))["status"],
      "| 商品状态 =",
      db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"],
      "| 评价记录数 =",
      db.query_one("SELECT COUNT(*) c FROM reviews WHERE order_id=%s", (complete_oid,))["c"])
assert db.query_one("SELECT status FROM orders WHERE id=%s", (complete_oid,))["status"] == "completed"
assert db.query_one("SELECT COUNT(*) c FROM reviews WHERE order_id=%s", (complete_oid,))["c"] == 1

print("首页状态码 =", client.get("/").status_code)
print("商品详情状态码 =", client.get(f"/product/{pid}").status_code)

# 清理测试数据。
for oid in [timeout_oid, refund_oid, complete_oid]:
    db.execute("DELETE FROM reviews WHERE order_id=%s", (oid,))
    db.execute("DELETE FROM payments WHERE order_id=%s", (oid,))
    db.execute("DELETE FROM orders WHERE id=%s", (oid,))
db.execute("DELETE FROM messages WHERE product_id=%s", (pid,))
db.execute("DELETE FROM favorites WHERE product_id=%s", (pid,))
db.execute("DELETE FROM products WHERE id=%s", (pid,))
db.execute("DELETE FROM users WHERE username IN (%s,%s,%s)",
           (buyer["username"], seller["username"], buyer2["username"]))
print("清理完成，超时取消、退款、评价和消息全部通过 OK")
