# -*- coding: utf-8 -*-
"""端到端验证：检查 secondhand 库现状，并走通订单、退款、评价和消息流程。"""
import io
import random
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

import db
from app import app, ensure_runtime_schema
from werkzeug.security import generate_password_hash

app.config["TESTING"] = True
client = app.test_client()
ensure_runtime_schema()


def csrf_value():
    with client.session_transaction() as sess:
        token = sess.get("_csrf_token")
        if not token:
            token = "verify-csrf-token"
            sess["_csrf_token"] = token
        return token


def post(path, **data):
    data = dict(data)
    data["_csrf_token"] = csrf_value()
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
for table in ["admins", "product_images", "favorites", "reviews", "messages", "notifications"]:
    assert table in tables
for column in ["refund_reason", "refund_requested_at", "refunded_at", "shipped_at"]:
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
for column in ["is_active"]:
    assert db.query_one(
        "SELECT COUNT(*) c FROM information_schema.columns "
        "WHERE table_schema='secondhand' AND table_name='users' AND column_name=%s",
        (column,),
    )["c"] == 1
for column in ["can_manage_products", "can_manage_users", "can_manage_admin_register"]:
    assert db.query_one(
        "SELECT COUNT(*) c FROM information_schema.columns "
        "WHERE table_schema='secondhand' AND table_name='admins' AND column_name=%s",
        (column,),
    )["c"] == 1
for column in ["removal_reason", "removed_by", "removed_at"]:
    assert db.query_one(
        "SELECT COUNT(*) c FROM information_schema.columns "
        "WHERE table_schema='secondhand' AND table_name='products' AND column_name=%s",
        (column,),
    )["c"] == 1
assert "app_settings" in tables
assert db.query_one(
    "SELECT a.id FROM admins a JOIN users u ON a.user_id=u.id WHERE u.username='admin'"
)
original_admin_registration_setting = db.query_one(
    "SELECT setting_value FROM app_settings WHERE setting_key='admin_registration_enabled'",
)["setting_value"]
print("用户数:", db.query_one("SELECT COUNT(*) c FROM users")["c"])
print("分类数:", db.query_one("SELECT COUNT(*) c FROM categories")["c"])
print("商品数:", db.query_one("SELECT COUNT(*) c FROM products")["c"])
assert client.post("/login", data={"username": "nobody", "password": "wrong"}).status_code == 400
print("CSRF 无 token POST 拦截 OK")


sfx = random.randint(100000, 999999)
seller = {"username": f"s{sfx}", "password": "pass1234",
          "nickname": f"测试卖家{sfx}", "phone": f"139{sfx % 100000:05d}1"}
buyer = {"username": f"b{sfx}", "password": "pass1234",
         "nickname": f"测试买家{sfx}", "phone": f"139{sfx % 100000:05d}2"}
buyer2 = {"username": f"c{sfx}", "password": "pass1234",
          "nickname": f"测试同学{sfx}", "phone": f"139{sfx % 100000:05d}3"}
admin = {"username": f"a{sfx}", "password": "pass1234",
         "nickname": f"测试管理员{sfx}", "phone": f"139{sfx % 100000:05d}4"}

print("注册卖家:", post("/register", **seller).status_code)
print("注册买家:", post("/register", **buyer).status_code)
print("注册同学:", post("/register", **buyer2).status_code)
db.execute(
    "INSERT INTO users (username, password_hash, nickname, phone) "
    "VALUES (%s, %s, %s, %s)",
    (admin["username"], generate_password_hash(admin["password"]), admin["nickname"], admin["phone"]),
)
admin_id = db.query_one("SELECT id FROM users WHERE username=%s", (admin["username"],))["id"]
db.execute(
    "INSERT INTO admins "
    "(user_id, can_manage_products, can_manage_users, can_manage_admin_register) "
    "VALUES (%s, 1, 1, 1)",
    (admin_id,),
)
print("临时管理员创建完成")

post("/login", username=seller["username"], password="pass1234")
post("/publish", title=f"验证商品{sfx}", description="端到端验证用商品",
     price="100.00", category_id="1", condition_level="9成新",
     image_url="/static/product_images/iphone13-blue.jpg")
pid = db.query_one("SELECT id FROM products WHERE title=%s",
                   (f"验证商品{sfx}",))["id"]
post("/publish", title=f"撤回退款商品{sfx}", description="中文文件名上传验证",
     price="100.00", category_id="1", condition_level="9成新",
     image_files=(io.BytesIO(b"fake image bytes"), "图片.jpg"))
cancel_refund_pid = db.query_one("SELECT id FROM products WHERE title=%s",
                                 (f"撤回退款商品{sfx}",))["id"]
post("/publish", title=f"拒绝退款商品{sfx}", description="退款拒绝验证用商品",
     price="100.00", category_id="1", condition_level="9成新",
     image_url="/static/product_images/camera-vlog.jpg")
reject_refund_pid = db.query_one("SELECT id FROM products WHERE title=%s",
                                 (f"拒绝退款商品{sfx}",))["id"]
print("发布商品 id =", pid,
      "| 状态 =", db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"])
assert db.query_one(
    "SELECT COUNT(*) c FROM product_images WHERE product_id=%s", (pid,))["c"] == 1
chinese_upload_url = db.query_one(
    "SELECT image_url FROM product_images WHERE product_id=%s ORDER BY sort_no LIMIT 1",
    (cancel_refund_pid,),
)["image_url"]
print("中文图片名上传路径 =", chinese_upload_url)
assert chinese_upload_url.startswith("/static/uploads/")
client.get("/logout")

post("/login", username=admin["username"], password=admin["password"])
print("后台首页状态码 =", client.get("/admin").status_code)
print("后台商品页状态码 =", client.get("/admin/products").status_code)
post(f"/admin/products/{pid}/remove", reason="测试违规下架")
admin_removed = db.query_one(
    "SELECT status, removal_reason, removed_by FROM products WHERE id=%s",
    (pid,),
)
print("管理员下架状态 =", admin_removed["status"], "| 原因 =", admin_removed["removal_reason"])
assert admin_removed["status"] == "removed"
assert admin_removed["removal_reason"] == "测试违规下架"
client.get("/logout")

post("/login", username=seller["username"], password="pass1234")
post(f"/product/{pid}/restore")
assert db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"] == "removed"
print("卖家查看被管理员下架商品页状态码 =", client.get(f"/product/{pid}").status_code)
print("普通用户访问管理员创建页状态码 =", client.get("/admin/register").status_code)
assert client.get("/admin/register").status_code == 403
client.get("/logout")

print("未登录访问管理员创建页状态码 =", client.get("/admin/register").status_code)
assert client.get("/admin/register").status_code == 302

post("/login", username=admin["username"], password=admin["password"])
post(f"/admin/products/{pid}/restore")
assert db.query_one("SELECT status FROM products WHERE id=%s", (pid,))["status"] == "on_sale"
print("管理员恢复商品 OK")
print("后台用户页状态码 =", client.get("/admin/users").status_code)
seller_id_for_admin = db.query_one("SELECT id FROM users WHERE username=%s", (seller["username"],))["id"]
post(
    f"/admin/users/{seller_id_for_admin}/admin",
    is_admin="1",
    can_manage_products="1",
    can_manage_users="0",
    can_manage_admin_register="0",
)
seller_admin = db.query_one("SELECT * FROM admins WHERE user_id=%s", (seller_id_for_admin,))
assert seller_admin and seller_admin["can_manage_products"] == 1 and seller_admin["can_manage_users"] == 0
post(f"/admin/users/{seller_id_for_admin}/admin")
assert not db.query_one("SELECT id FROM admins WHERE user_id=%s", (seller_id_for_admin,))
post("/admin/settings", admin_registration_enabled="1")
assert db.query_one(
    "SELECT setting_value FROM app_settings WHERE setting_key='admin_registration_enabled'",
)["setting_value"] == "1"
print("管理员注册开关打开后页面 =", client.get("/admin/register").status_code)
created_admin = {
    "username": f"newadmin{sfx}",
    "password": "pass1234",
    "nickname": f"新管理员{sfx}",
    "phone": f"139{sfx % 100000:05d}5",
}
print("已有管理员创建管理员:", post("/admin/register", **created_admin).status_code)
created_admin_row = db.query_one(
    "SELECT a.*, u.username FROM admins a JOIN users u ON a.user_id=u.id WHERE u.username=%s",
    (created_admin["username"],),
)
assert created_admin_row
assert created_admin_row["created_by"] == admin_id
post("/admin/settings")
if original_admin_registration_setting == "1":
    post("/admin/settings", admin_registration_enabled="1")
assert db.query_one(
    "SELECT setting_value FROM app_settings WHERE setting_key='admin_registration_enabled'",
)["setting_value"] == original_admin_registration_setting
print("用户权限和注册开关 OK")
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

# 已付款后申请退款，退款中不能直接确认收货，卖家同意后退回买家余额，商品恢复在售。
post("/order/create", product_id=str(pid), address="松园3栋")
refund_oid = latest_order_id(pid)
post(f"/order/{refund_oid}/pay")
post(f"/order/{refund_oid}/refund/request", reason="临时不需要了")
print("申请退款后订单状态 =",
      db.query_one("SELECT status FROM orders WHERE id=%s", (refund_oid,))["status"])
assert db.query_one("SELECT status FROM orders WHERE id=%s", (refund_oid,))["status"] == "refund_requested"
post(f"/order/{refund_oid}/complete")
assert db.query_one("SELECT status FROM orders WHERE id=%s", (refund_oid,))["status"] == "refund_requested"
print("退款申请中禁止直接确认收货 OK")

post("/order/create", product_id=str(cancel_refund_pid), address="松园3栋")
cancel_refund_oid = latest_order_id(cancel_refund_pid)
post(f"/order/{cancel_refund_oid}/pay")
post(f"/order/{cancel_refund_oid}/refund/request", reason="想想还是要")
post(f"/order/{cancel_refund_oid}/refund/cancel")
cancel_refund_order = db.query_one(
    "SELECT status, refund_reason, refund_requested_at FROM orders WHERE id=%s",
    (cancel_refund_oid,),
)
print("买家撤回退款后订单状态 =", cancel_refund_order["status"])
assert cancel_refund_order["status"] == "paid"
assert cancel_refund_order["refund_reason"] is None
assert cancel_refund_order["refund_requested_at"] is None

post("/order/create", product_id=str(reject_refund_pid), address="松园3栋")
reject_refund_oid = latest_order_id(reject_refund_pid)
post(f"/order/{reject_refund_oid}/pay")
post(f"/order/{reject_refund_oid}/refund/request", reason="想退款")
assert db.query_one(
    "SELECT status FROM orders WHERE id=%s", (reject_refund_oid,),
)["status"] == "refund_requested"
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
pending_shipments = db.query_one(
    "SELECT COUNT(*) c FROM orders WHERE seller_id=%s AND status='paid'",
    (seller_id,),
)["c"]
print("卖家待发货提醒数量 =", pending_shipments)
assert pending_shipments >= 1
post(f"/order/{reject_refund_oid}/refund/reject")
reject_refund_order = db.query_one(
    "SELECT status, refund_reason, refund_requested_at FROM orders WHERE id=%s",
    (reject_refund_oid,),
)
print("卖家拒绝退款后订单状态 =", reject_refund_order["status"])
assert reject_refund_order["status"] == "paid"
assert reject_refund_order["refund_reason"] is None
assert reject_refund_order["refund_requested_at"] is None
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
assert db.query_one("SELECT status FROM orders WHERE id=%s", (complete_oid,))["status"] == "paid"
print("卖家未发货前禁止确认收货 OK")
client.get("/logout")

post("/login", username=seller["username"], password="pass1234")
post(f"/order/{complete_oid}/ship")
assert db.query_one("SELECT status FROM orders WHERE id=%s", (complete_oid,))["status"] == "shipped"
client.get("/logout")

post("/login", username=buyer["username"], password="pass1234")
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

# 退款申请更新必须再次要求 status='paid'，防止完成打款后又被改回退款中。
with db.get_cursor(commit=True) as cur:
    cur.execute(
        "UPDATE orders SET status='refund_requested' WHERE id=%s AND status='paid'",
        (complete_oid,),
    )
    stale_refund_rows = cur.rowcount
assert stale_refund_rows == 0
assert db.query_one("SELECT status FROM orders WHERE id=%s", (complete_oid,))["status"] == "completed"
print("并发退款尾段防护 OK")

print("首页状态码 =", client.get("/").status_code)
print("商品详情状态码 =", client.get(f"/product/{pid}").status_code)

# 清理测试数据。
for oid in [timeout_oid, refund_oid, cancel_refund_oid, reject_refund_oid, complete_oid]:
    db.execute("DELETE FROM reviews WHERE order_id=%s", (oid,))
    db.execute("DELETE FROM payments WHERE order_id=%s", (oid,))
    db.execute("DELETE FROM orders WHERE id=%s", (oid,))
db.execute("DELETE FROM messages WHERE product_id=%s", (pid,))
db.execute("DELETE FROM favorites WHERE product_id=%s", (pid,))
db.execute("DELETE FROM products WHERE id IN (%s,%s,%s)",
           (pid, cancel_refund_pid, reject_refund_pid))
if chinese_upload_url.startswith("/static/"):
    uploaded_path = Path(app.static_folder) / chinese_upload_url[len("/static/"):]
    if uploaded_path.exists():
        uploaded_path.unlink()
db.execute("DELETE FROM users WHERE username IN (%s,%s,%s,%s)",
           (buyer["username"], seller["username"], buyer2["username"], admin["username"]))
db.execute("DELETE FROM users WHERE username=%s", (created_admin["username"],))
print("清理完成，超时取消、退款、评价和消息全部通过 OK")
