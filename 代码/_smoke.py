"""临时冒烟测试：在进程内走通核心交易闭环。"""
import re, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
from app import app
import db

app.config["TESTING"] = True
c = app.test_client()

def post(path, **data):
    return c.post(path, data=data, follow_redirects=True)

# 用随机学号注册两个账号，避免和已有数据冲突
import random
sfx = random.randint(10000, 99999)
buyer = {"student_no": f"b{sfx}", "username": f"买家{sfx}", "real_name": "测试买家",
         "phone": f"139{sfx}0001", "password": "pass1234", "campus": "东校区"}
seller = {"student_no": f"s{sfx}", "username": f"卖家{sfx}", "real_name": "测试卖家",
          "phone": f"139{sfx}0002", "password": "pass1234", "campus": "东校区"}

print("注册卖家:", post("/register", **seller).status_code)
print("注册买家:", post("/register", **buyer).status_code)

# 卖家登录并发布
post("/login", account=seller["student_no"], password="pass1234")
r = post("/publish", title=f"测试商品{sfx}", category_id="4", price="19.90",
         original_price="59.00", condition_level="good", trade_place="图书馆",
         description="冒烟测试用商品")
m = re.search(r"/product/(\d+)", r.request.path)
pid = db.query_one("SELECT product_id FROM products WHERE title=%s", (f"测试商品{sfx}",))["product_id"]
print("发布商品 product_id =", pid)
c.get("/logout")

# 买家登录、下单
post("/login", account=buyer["student_no"], password="pass1234")
post(f"/product/{pid}/order")
order = db.query_one("SELECT * FROM orders WHERE seller_id=(SELECT user_id FROM users WHERE student_no=%s) ORDER BY order_id DESC LIMIT 1", (seller["student_no"],))
oid = order["order_id"]
print("下单后 订单状态 =", order["order_status"], "| 商品状态 =",
      db.query_one("SELECT status FROM products WHERE product_id=%s", (pid,))["status"])

# 支付
post(f"/order/{oid}/pay", pay_method="wechat")
print("支付后 订单状态 =", db.query_one("SELECT order_status FROM orders WHERE order_id=%s", (oid,))["order_status"],
      "| 支付状态 =", db.query_one("SELECT pay_status FROM payments WHERE order_id=%s", (oid,))["pay_status"])

# 完成
post(f"/order/{oid}/complete")
print("完成后 订单状态 =", db.query_one("SELECT order_status FROM orders WHERE order_id=%s", (oid,))["order_status"],
      "| 商品状态 =", db.query_one("SELECT status FROM products WHERE product_id=%s", (pid,))["status"])

# 评价
post(f"/order/{oid}/review", rating="5", content="交易顺利")
rv = db.query_one("SELECT * FROM reviews WHERE order_id=%s AND reviewer_id=(SELECT user_id FROM users WHERE student_no=%s)", (oid, buyer["student_no"]))
print("评价 rating =", rv["rating"] if rv else None)

# 首页能访问
print("首页状态码 =", c.get("/").status_code)

# 清理测试数据
db.execute("DELETE FROM reviews WHERE order_id=%s", (oid,))
db.execute("DELETE FROM payments WHERE order_id=%s", (oid,))
db.execute("DELETE FROM order_items WHERE order_id=%s", (oid,))
db.execute("DELETE FROM orders WHERE order_id=%s", (oid,))
db.execute("DELETE FROM product_images WHERE product_id=%s", (pid,))
db.execute("DELETE FROM products WHERE product_id=%s", (pid,))
db.execute("DELETE FROM users WHERE student_no IN (%s,%s)", (buyer["student_no"], seller["student_no"]))
print("清理完成，闭环全部通过 ✔")