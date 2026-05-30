# -*- coding: utf-8 -*-
"""二手交易平台 Web 应用（Flask）。

核心业务闭环：
    注册/登录 -> 发布/浏览商品 -> 下单(锁定商品) -> 余额支付(平台托管)
    -> 确认收货(打款给卖家) -> 交易完成
"""

import functools
import os
import random
import uuid
from datetime import datetime

from flask import (
    Flask, render_template, request, redirect, url_for,
    session, flash, abort,
)
from werkzeug.exceptions import RequestEntityTooLarge
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename

from config import SECRET_KEY
from db import query_all, query_one, get_cursor

app = Flask(__name__)
app.secret_key = SECRET_KEY
MAX_UPLOAD_MB = 20
app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_MB * 1024 * 1024

UPLOAD_FOLDER = os.path.join(app.static_folder, "uploads")
ALLOWED_IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "gif", "webp"}
MAX_PRODUCT_IMAGES = 4
IMAGE_URL_SEPARATOR = "|"

# 状态中文映射，供模板显示
PRODUCT_STATUS = {
    "on_sale": "在售",
    "locked": "交易中",
    "sold": "已售出",
    "removed": "已下架",
}
ORDER_STATUS = {
    "created": "待支付",
    "paid": "待收货",
    "completed": "已完成",
    "cancelled": "已取消",
}


# --------------------------------------------------------------------- #
# 通用辅助
# --------------------------------------------------------------------- #
def current_user():
    """返回当前登录用户（dict）或 None。"""
    uid = session.get("user_id")
    if not uid:
        return None
    return query_one("SELECT * FROM users WHERE id=%s", (uid,))


@app.context_processor
def inject_globals():
    """模板全局变量。"""
    return {
        "current_user": current_user(),
        "PRODUCT_STATUS": PRODUCT_STATUS,
        "ORDER_STATUS": ORDER_STATUS,
        "image_urls": image_urls,
        "cover_image": cover_image,
    }


def login_required(view):
    @functools.wraps(view)
    def wrapped(*args, **kwargs):
        if not session.get("user_id"):
            flash("请先登录", "warning")
            return redirect(url_for("login", next=request.path))
        return view(*args, **kwargs)
    return wrapped


def gen_order_no():
    """生成订单号：时间戳 + 4 位随机数。"""
    return datetime.now().strftime("%Y%m%d%H%M%S") + "%04d" % random.randint(0, 9999)


def image_urls(value):
    """把数据库里的图片字段转成列表，兼容旧的单图 URL。"""
    if not value:
        return []
    return [url for url in str(value).split(IMAGE_URL_SEPARATOR) if url]


def cover_image(value):
    urls = image_urls(value)
    return urls[0] if urls else ""


def save_uploaded_images(file_storages):
    """保存上传的商品图片，返回可直接存入数据库的静态资源路径列表。"""
    files = [file for file in file_storages if file and file.filename]
    if not files:
        return []
    if len(files) > MAX_PRODUCT_IMAGES:
        raise ValueError("最多上传 %d 张图片" % MAX_PRODUCT_IMAGES)

    prepared = []
    for file_storage in files:
        filename = secure_filename(file_storage.filename)
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        if ext not in ALLOWED_IMAGE_EXTENSIONS:
            raise ValueError("图片格式仅支持 JPG、PNG、GIF、WEBP")
        prepared.append((file_storage, ext))

    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    urls = []
    for file_storage, ext in prepared:
        stored_name = "%s.%s" % (uuid.uuid4().hex, ext)
        file_storage.save(os.path.join(UPLOAD_FOLDER, stored_name))
        urls.append(url_for("static", filename="uploads/" + stored_name))
    return urls


def save_uploaded_image(file_storage):
    """保存单张上传图片，保留给测试和旧调用使用。"""
    urls = save_uploaded_images([file_storage])
    return urls[0] if urls else None


def read_product_form():
    return {
        "title": request.form.get("title", "").strip(),
        "description": request.form.get("description", "").strip(),
        "price": request.form.get("price", type=float),
        "category_id": request.form.get("category_id", type=int),
        "condition_level": request.form.get("condition_level", "9成新").strip(),
    }


def read_image_files():
    image_files = request.files.getlist("image_files")
    if not image_files:
        image_files = [request.files.get("image_file")]
    return image_files


def read_kept_image_urls():
    """读取编辑页保留的旧图路径，只允许保留当前商品已有图片。"""
    return [url for url in request.form.getlist("kept_images") if url]


def validate_product_form(form):
    if not form["title"] or form["price"] is None or form["price"] <= 0:
        return "标题必填，价格须大于 0"
    return None


# --------------------------------------------------------------------- #
# 首页 / 商品浏览
# --------------------------------------------------------------------- #
@app.route("/")
def index():
    keyword = request.args.get("q", "").strip()
    category_id = request.args.get("category", type=int)

    sql = (
        "SELECT p.*, u.nickname AS seller_name, c.name AS category_name "
        "FROM products p "
        "JOIN users u ON p.seller_id = u.id "
        "LEFT JOIN categories c ON p.category_id = c.id "
        "WHERE p.status IN ('on_sale','locked') "
    )
    params = []
    if keyword:
        sql += "AND p.title LIKE %s "
        params.append("%" + keyword + "%")
    if category_id:
        sql += "AND p.category_id = %s "
        params.append(category_id)
    sql += "ORDER BY p.created_at DESC"

    products = query_all(sql, params)
    categories = query_all("SELECT * FROM categories ORDER BY id")
    return render_template(
        "index.html", products=products, categories=categories,
        keyword=keyword, category_id=category_id,
    )


@app.route("/product/<int:pid>")
def product_detail(pid):
    product = query_one(
        "SELECT p.*, u.nickname AS seller_name, u.phone AS seller_phone, "
        "c.name AS category_name "
        "FROM products p JOIN users u ON p.seller_id = u.id "
        "LEFT JOIN categories c ON p.category_id = c.id "
        "WHERE p.id = %s",
        (pid,),
    )
    if not product:
        abort(404)
    # 浏览量 +1
    with get_cursor(commit=True) as cur:
        cur.execute("UPDATE products SET view_count = view_count + 1 WHERE id=%s", (pid,))
    return render_template("product_detail.html", product=product)


# --------------------------------------------------------------------- #
# 注册 / 登录 / 退出
# --------------------------------------------------------------------- #
@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        nickname = request.form.get("nickname", "").strip()
        phone = request.form.get("phone", "").strip()

        if not username or not password or not nickname:
            flash("账号、密码、昵称不能为空", "danger")
            return render_template("register.html")
        if query_one("SELECT id FROM users WHERE username=%s", (username,)):
            flash("该账号已被注册", "danger")
            return render_template("register.html")

        with get_cursor(commit=True) as cur:
            cur.execute(
                "INSERT INTO users (username, password_hash, nickname, phone) "
                "VALUES (%s, %s, %s, %s)",
                (username, generate_password_hash(password), nickname, phone or None),
            )
        flash("注册成功，请登录", "success")
        return redirect(url_for("login"))
    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        user = query_one("SELECT * FROM users WHERE username=%s", (username,))
        if not user or not check_password_hash(user["password_hash"], password):
            flash("账号或密码错误", "danger")
            return render_template("login.html")
        session["user_id"] = user["id"]
        flash("登录成功，欢迎 %s" % user["nickname"], "success")
        next_url = request.args.get("next") or url_for("index")
        return redirect(next_url)
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("已退出登录", "info")
    return redirect(url_for("index"))


# --------------------------------------------------------------------- #
# 发布 / 管理商品
# --------------------------------------------------------------------- #
@app.route("/publish", methods=["GET", "POST"])
@login_required
def publish():
    categories = query_all("SELECT * FROM categories ORDER BY id")
    if request.method == "POST":
        form = read_product_form()
        image_url = request.form.get("image_url", "").strip()
        image_files = read_image_files()

        error = validate_product_form(form)
        if error:
            flash(error, "danger")
            return render_template("publish.html", categories=categories)

        try:
            uploaded_image_urls = save_uploaded_images(image_files)
        except ValueError as exc:
            flash(str(exc), "danger")
            return render_template("publish.html", categories=categories)

        with get_cursor(commit=True) as cur:
            cur.execute(
                "INSERT INTO products "
                "(seller_id, category_id, title, description, price, condition_level, image_url) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (session["user_id"], form["category_id"], form["title"], form["description"],
                 form["price"], form["condition_level"],
                 IMAGE_URL_SEPARATOR.join(uploaded_image_urls) or image_url or None),
            )
        flash("商品发布成功", "success")
        return redirect(url_for("my_selling"))
    return render_template("publish.html", categories=categories)


@app.route("/product/<int:pid>/edit", methods=["GET", "POST"])
@login_required
def edit_product(pid):
    product = query_one("SELECT * FROM products WHERE id=%s", (pid,))
    if not product or product["seller_id"] != session["user_id"]:
        abort(403)
    if product["status"] != "on_sale":
        flash("只有在售商品可以编辑", "warning")
        return redirect(url_for("my_selling"))

    categories = query_all("SELECT * FROM categories ORDER BY id")
    if request.method == "POST":
        form = read_product_form()
        image_files = read_image_files()

        error = validate_product_form(form)
        if error:
            flash(error, "danger")
            return render_template("edit_product.html", product=product, categories=categories)

        try:
            existing_images = image_urls(product["image_url"])
            kept_images = [
                url for url in read_kept_image_urls()
                if url in existing_images
            ]
            new_image_count = len([file for file in image_files if file and file.filename])
            if len(kept_images) + new_image_count > MAX_PRODUCT_IMAGES:
                raise ValueError("商品图片最多保留 %d 张，请先删除多余图片" % MAX_PRODUCT_IMAGES)
            uploaded_image_urls = save_uploaded_images(image_files)
        except ValueError as exc:
            flash(str(exc), "danger")
            return render_template("edit_product.html", product=product, categories=categories)

        merged_images = kept_images + uploaded_image_urls
        image_url = IMAGE_URL_SEPARATOR.join(merged_images) or None
        with get_cursor(commit=True) as cur:
            cur.execute(
                "UPDATE products SET category_id=%s, title=%s, description=%s, "
                "price=%s, condition_level=%s, image_url=%s WHERE id=%s",
                (form["category_id"], form["title"], form["description"],
                 form["price"], form["condition_level"], image_url, pid),
            )
        flash("商品信息已更新", "success")
        return redirect(url_for("my_selling"))

    return render_template("edit_product.html", product=product, categories=categories)


@app.route("/product/<int:pid>/remove", methods=["POST"])
@login_required
def remove_product(pid):
    product = query_one("SELECT * FROM products WHERE id=%s", (pid,))
    if not product or product["seller_id"] != session["user_id"]:
        abort(403)
    if product["status"] != "on_sale":
        flash("该商品当前状态无法下架", "warning")
        return redirect(url_for("my_selling"))
    with get_cursor(commit=True) as cur:
        cur.execute("UPDATE products SET status='removed' WHERE id=%s", (pid,))
    flash("商品已下架", "info")
    return redirect(url_for("my_selling"))


@app.route("/product/<int:pid>/restore", methods=["POST"])
@login_required
def restore_product(pid):
    product = query_one("SELECT * FROM products WHERE id=%s", (pid,))
    if not product or product["seller_id"] != session["user_id"]:
        abort(403)
    if product["status"] != "removed":
        flash("只有已下架商品可以重新上架", "warning")
        return redirect(url_for("my_selling"))
    with get_cursor(commit=True) as cur:
        cur.execute("UPDATE products SET status='on_sale' WHERE id=%s", (pid,))
    flash("商品已重新上架", "success")
    return redirect(url_for("my_selling"))


@app.route("/product/<int:pid>/delete", methods=["POST"])
@login_required
def delete_product(pid):
    product = query_one("SELECT * FROM products WHERE id=%s", (pid,))
    if not product or product["seller_id"] != session["user_id"]:
        abort(403)
    if product["status"] == "locked":
        flash("交易中的商品不能删除", "warning")
        return redirect(url_for("my_selling"))

    order_count = query_one(
        "SELECT COUNT(*) AS c FROM orders WHERE product_id=%s",
        (pid,),
    )["c"]
    if order_count:
        flash("已有订单记录，不能删除；可以下架保留交易记录", "warning")
        return redirect(url_for("my_selling"))

    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM products WHERE id=%s", (pid,))
    flash("商品已删除", "info")
    return redirect(url_for("my_selling"))


# --------------------------------------------------------------------- #
# 下单 / 支付 / 收货 / 取消（订单状态机，事务保证一致性）
# --------------------------------------------------------------------- #
@app.route("/order/create", methods=["POST"])
@login_required
def create_order():
    pid = request.form.get("product_id", type=int)
    address = request.form.get("address", "").strip()
    buyer_id = session["user_id"]

    try:
        with get_cursor(commit=True) as cur:
            # 加行锁，避免并发下单同一商品
            cur.execute("SELECT * FROM products WHERE id=%s FOR UPDATE", (pid,))
            product = cur.fetchone()
            if not product:
                flash("商品不存在", "danger")
                return redirect(url_for("index"))
            if product["seller_id"] == buyer_id:
                flash("不能购买自己发布的商品", "warning")
                return redirect(url_for("product_detail", pid=pid))
            if product["status"] != "on_sale":
                flash("商品已被下单或售出", "warning")
                return redirect(url_for("product_detail", pid=pid))

            # 锁定商品 + 创建订单
            cur.execute("UPDATE products SET status='locked' WHERE id=%s", (pid,))
            order_no = gen_order_no()
            cur.execute(
                "INSERT INTO orders "
                "(order_no, product_id, buyer_id, seller_id, amount, status, address) "
                "VALUES (%s, %s, %s, %s, %s, 'created', %s)",
                (order_no, pid, buyer_id, product["seller_id"], product["price"], address or None),
            )
            order_id = cur.lastrowid
        flash("下单成功，请尽快支付", "success")
        return redirect(url_for("order_detail", oid=order_id))
    except Exception:
        flash("下单失败，请重试", "danger")
        return redirect(url_for("product_detail", pid=pid))


@app.route("/order/<int:oid>")
@login_required
def order_detail(oid):
    order = query_one(
        "SELECT o.*, p.title, p.image_url, p.condition_level, "
        "bu.nickname AS buyer_name, su.nickname AS seller_name, su.phone AS seller_phone "
        "FROM orders o "
        "JOIN products p ON o.product_id = p.id "
        "JOIN users bu ON o.buyer_id = bu.id "
        "JOIN users su ON o.seller_id = su.id "
        "WHERE o.id=%s",
        (oid,),
    )
    if not order:
        abort(404)
    uid = session["user_id"]
    if uid not in (order["buyer_id"], order["seller_id"]):
        abort(403)
    payments = query_all("SELECT * FROM payments WHERE order_id=%s ORDER BY id", (oid,))
    return render_template("order_detail.html", order=order, payments=payments)


@app.route("/order/<int:oid>/pay", methods=["POST"])
@login_required
def pay_order(oid):
    buyer_id = session["user_id"]
    try:
        with get_cursor(commit=True) as cur:
            cur.execute("SELECT * FROM orders WHERE id=%s FOR UPDATE", (oid,))
            order = cur.fetchone()
            if not order:
                flash("订单不存在", "danger")
                return redirect(url_for("index"))
            if order["buyer_id"] != buyer_id:
                abort(403)
            if order["status"] != "created":
                flash("订单状态不支持支付", "warning")
                return redirect(url_for("order_detail", oid=oid))

            # 校验买家余额
            cur.execute("SELECT balance FROM users WHERE id=%s FOR UPDATE", (buyer_id,))
            buyer = cur.fetchone()
            if buyer["balance"] < order["amount"]:
                flash("余额不足，请先充值", "danger")
                return redirect(url_for("order_detail", oid=oid))

            # 扣买家余额（平台托管，确认收货后再打款卖家）
            cur.execute(
                "UPDATE users SET balance = balance - %s WHERE id=%s",
                (order["amount"], buyer_id),
            )
            cur.execute(
                "UPDATE orders SET status='paid', paid_at=NOW() WHERE id=%s", (oid,)
            )
            cur.execute(
                "INSERT INTO payments (order_id, amount, method, status) "
                "VALUES (%s, %s, 'balance', 'success')",
                (oid, order["amount"]),
            )
        flash("支付成功，等待卖家发货 / 确认收货后完成交易", "success")
    except Exception:
        flash("支付失败，请重试", "danger")
    return redirect(url_for("order_detail", oid=oid))


@app.route("/order/<int:oid>/complete", methods=["POST"])
@login_required
def complete_order(oid):
    buyer_id = session["user_id"]
    try:
        with get_cursor(commit=True) as cur:
            cur.execute("SELECT * FROM orders WHERE id=%s FOR UPDATE", (oid,))
            order = cur.fetchone()
            if not order:
                flash("订单不存在", "danger")
                return redirect(url_for("index"))
            if order["buyer_id"] != buyer_id:
                abort(403)
            if order["status"] != "paid":
                flash("订单状态不支持确认收货", "warning")
                return redirect(url_for("order_detail", oid=oid))

            # 打款给卖家 + 商品标记售出 + 订单完成
            cur.execute(
                "UPDATE users SET balance = balance + %s WHERE id=%s",
                (order["amount"], order["seller_id"]),
            )
            cur.execute("UPDATE products SET status='sold' WHERE id=%s", (order["product_id"],))
            cur.execute(
                "UPDATE orders SET status='completed', completed_at=NOW() WHERE id=%s", (oid,)
            )
        flash("确认收货成功，交易完成", "success")
    except Exception:
        flash("操作失败，请重试", "danger")
    return redirect(url_for("order_detail", oid=oid))


@app.route("/order/<int:oid>/cancel", methods=["POST"])
@login_required
def cancel_order(oid):
    uid = session["user_id"]
    try:
        with get_cursor(commit=True) as cur:
            cur.execute("SELECT * FROM orders WHERE id=%s FOR UPDATE", (oid,))
            order = cur.fetchone()
            if not order:
                flash("订单不存在", "danger")
                return redirect(url_for("index"))
            if uid not in (order["buyer_id"], order["seller_id"]):
                abort(403)
            if order["status"] != "created":
                flash("仅待支付订单可取消", "warning")
                return redirect(url_for("order_detail", oid=oid))

            # 释放商品 + 订单取消
            cur.execute("UPDATE products SET status='on_sale' WHERE id=%s", (order["product_id"],))
            cur.execute(
                "UPDATE orders SET status='cancelled', cancelled_at=NOW() WHERE id=%s", (oid,)
            )
        flash("订单已取消", "info")
    except Exception:
        flash("取消失败，请重试", "danger")
    return redirect(url_for("order_detail", oid=oid))


# --------------------------------------------------------------------- #
# 个人中心
# --------------------------------------------------------------------- #
@app.route("/me")
@login_required
def me():
    uid = session["user_id"]
    selling_cnt = query_one(
        "SELECT COUNT(*) AS c FROM products WHERE seller_id=%s AND status IN ('on_sale','locked')",
        (uid,))["c"]
    bought_cnt = query_one("SELECT COUNT(*) AS c FROM orders WHERE buyer_id=%s", (uid,))["c"]
    sold_cnt = query_one(
        "SELECT COUNT(*) AS c FROM orders WHERE seller_id=%s AND status='completed'", (uid,))["c"]
    return render_template(
        "me.html", selling_cnt=selling_cnt, bought_cnt=bought_cnt, sold_cnt=sold_cnt)


@app.route("/me/profile", methods=["GET", "POST"])
@login_required
def profile():
    user = current_user()
    if request.method == "POST":
        nickname = request.form.get("nickname", "").strip()
        phone = request.form.get("phone", "").strip()
        old_password = request.form.get("old_password", "")
        new_password = request.form.get("new_password", "")
        confirm_password = request.form.get("confirm_password", "")
        changing_password = bool(old_password or new_password or confirm_password)

        if not nickname:
            flash("昵称不能为空", "danger")
            return render_template("profile.html", user=user)

        password_hash = None
        if changing_password:
            if not old_password or not new_password or not confirm_password:
                flash("修改密码时请完整填写旧密码、新密码和确认密码", "danger")
                return render_template("profile.html", user=user)
            if not check_password_hash(user["password_hash"], old_password):
                flash("旧密码不正确", "danger")
                return render_template("profile.html", user=user)
            if len(new_password) < 6:
                flash("新密码至少 6 位", "danger")
                return render_template("profile.html", user=user)
            if new_password != confirm_password:
                flash("两次输入的新密码不一致", "danger")
                return render_template("profile.html", user=user)
            password_hash = generate_password_hash(new_password)

        with get_cursor(commit=True) as cur:
            if password_hash:
                cur.execute(
                    "UPDATE users SET nickname=%s, phone=%s, password_hash=%s WHERE id=%s",
                    (nickname, phone or None, password_hash, session["user_id"]),
                )
            else:
                cur.execute(
                    "UPDATE users SET nickname=%s, phone=%s WHERE id=%s",
                    (nickname, phone or None, session["user_id"]),
                )
        flash("账号资料已保存", "success")
        return redirect(url_for("profile"))

    return render_template("profile.html", user=user)


@app.route("/me/selling")
@login_required
def my_selling():
    products = query_all(
        "SELECT p.*, c.name AS category_name, "
        "(SELECT COUNT(*) FROM orders o WHERE o.product_id = p.id) AS order_count "
        "FROM products p "
        "LEFT JOIN categories c ON p.category_id = c.id "
        "WHERE p.seller_id=%s ORDER BY p.created_at DESC",
        (session["user_id"],),
    )
    return render_template("my_selling.html", products=products)


@app.route("/me/bought")
@login_required
def my_bought():
    orders = query_all(
        "SELECT o.*, p.title, p.image_url, su.nickname AS seller_name "
        "FROM orders o JOIN products p ON o.product_id = p.id "
        "JOIN users su ON o.seller_id = su.id "
        "WHERE o.buyer_id=%s ORDER BY o.created_at DESC",
        (session["user_id"],),
    )
    return render_template("my_orders.html", orders=orders, role="buyer")


@app.route("/me/sold")
@login_required
def my_sold():
    orders = query_all(
        "SELECT o.*, p.title, p.image_url, bu.nickname AS buyer_name "
        "FROM orders o JOIN products p ON o.product_id = p.id "
        "JOIN users bu ON o.buyer_id = bu.id "
        "WHERE o.seller_id=%s ORDER BY o.created_at DESC",
        (session["user_id"],),
    )
    return render_template("my_orders.html", orders=orders, role="seller")


@app.route("/wallet/recharge", methods=["GET", "POST"])
@login_required
def recharge():
    if request.method == "POST":
        amount = request.form.get("amount", type=float)
        if amount is None or amount <= 0:
            flash("充值金额须大于 0", "danger")
            return render_template("recharge.html")
        with get_cursor(commit=True) as cur:
            cur.execute(
                "UPDATE users SET balance = balance + %s WHERE id=%s",
                (amount, session["user_id"]),
            )
        flash("充值成功 +%.2f 元" % amount, "success")
        return redirect(url_for("me"))
    return render_template("recharge.html")


# --------------------------------------------------------------------- #
@app.errorhandler(403)
def forbidden(e):
    return render_template("error.html", code=403, message="没有权限访问该页面"), 403


@app.errorhandler(404)
def not_found(e):
    return render_template("error.html", code=404, message="页面不存在"), 404


@app.errorhandler(RequestEntityTooLarge)
def file_too_large(e):
    return render_template(
        "error.html", code=413,
        message="上传图片总大小不能超过 %dMB" % MAX_UPLOAD_MB,
    ), 413


if __name__ == "__main__":
    # use_reloader=False：避免本机 watchdog 版本与 Werkzeug 重载器不兼容导致启动失败
    app.run(host="127.0.0.1", port=5000, debug=True, use_reloader=False)
