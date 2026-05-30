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
from datetime import datetime, timedelta

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
RUNTIME_SCHEMA_READY = False
ORDER_PAYMENT_TIMEOUT_MINUTES = 10

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
    "refund_requested": "退款申请中",
    "refunded": "已退款",
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


def notification_summary(user_id):
    """返回全局提醒数量：未读消息 + 待卖家处理的退款申请。"""
    unread_messages = query_one(
        "SELECT COUNT(*) AS c FROM messages "
        "WHERE receiver_id=%s AND is_read=0 AND receiver_deleted=0",
        (user_id,),
    )["c"]
    refund_requests = query_one(
        "SELECT COUNT(*) AS c FROM orders WHERE seller_id=%s AND status='refund_requested'",
        (user_id,),
    )["c"]
    return {
        "unread_messages": unread_messages,
        "refund_requests": refund_requests,
        "total": unread_messages + refund_requests,
    }


@app.context_processor
def inject_globals():
    """模板全局变量。"""
    user = current_user()
    return {
        "current_user": user,
        "notification_summary": notification_summary(user["id"]) if user else None,
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
    if isinstance(value, (list, tuple)):
        return [url for url in value if url]
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


def get_product_image_urls(product_id, fallback=None):
    """读取商品图片表中的图片，兼容旧的 products.image_url。"""
    rows = query_all(
        "SELECT image_url FROM product_images WHERE product_id=%s ORDER BY sort_no, id",
        (product_id,),
    )
    urls = [row["image_url"] for row in rows if row.get("image_url")]
    return urls or image_urls(fallback)


def hydrate_product_images(rows):
    """批量给商品或订单行补充图片列表和兼容 image_url。"""
    items = list(rows or [])
    product_ids = []
    for row in items:
        product_id = row.get("product_id") or row.get("id")
        if product_id:
            product_ids.append(product_id)
    product_ids = list(dict.fromkeys(product_ids))
    if not product_ids:
        return items

    placeholders = ",".join(["%s"] * len(product_ids))
    image_rows = query_all(
        "SELECT product_id, image_url FROM product_images "
        "WHERE product_id IN (%s) ORDER BY product_id, sort_no, id" % placeholders,
        product_ids,
    )
    grouped = {}
    for image in image_rows:
        grouped.setdefault(image["product_id"], []).append(image["image_url"])

    for row in items:
        product_id = row.get("product_id") or row.get("id")
        urls = grouped.get(product_id) or image_urls(row.get("image_url"))
        row["images"] = urls
        row["image_url"] = IMAGE_URL_SEPARATOR.join(urls) if urls else row.get("image_url")
    return items


def set_product_images(cur, product_id, urls):
    """同步商品图片表，并维护 products.image_url 兼容缓存。"""
    urls = [url for url in urls if url]
    cur.execute("DELETE FROM product_images WHERE product_id=%s", (product_id,))
    for index, url in enumerate(urls):
        cur.execute(
            "INSERT INTO product_images (product_id, image_url, is_cover, sort_no) "
            "VALUES (%s, %s, %s, %s)",
            (product_id, url, 1 if index == 0 else 0, index),
        )
    cur.execute(
        "UPDATE products SET image_url=%s WHERE id=%s",
        (IMAGE_URL_SEPARATOR.join(urls) or None, product_id),
    )


def validate_product_form(form):
    if not form["title"] or form["price"] is None or form["price"] <= 0:
        return "标题必填，价格须大于 0"
    return None


def other_order_user(order, uid):
    """返回订单中与当前用户相对的一方用户 id。"""
    if uid == order["buyer_id"]:
        return order["seller_id"]
    if uid == order["seller_id"]:
        return order["buyer_id"]
    return None


def seller_review_summary(user_id):
    row = query_one(
        "SELECT COUNT(*) AS c, AVG(rating) AS avg_rating "
        "FROM reviews WHERE target_user_id=%s",
        (user_id,),
    )
    return {
        "count": row["c"] or 0,
        "avg": float(row["avg_rating"]) if row and row["avg_rating"] is not None else None,
    }


def build_message_conversations(uid):
    """按联系人聚合当前用户可见的消息，最新对话排在前面。"""
    rows = query_all(
        "SELECT m.*, su.nickname AS sender_name, ru.nickname AS receiver_name, "
        "p.title AS product_title "
        "FROM messages m "
        "JOIN users su ON m.sender_id = su.id "
        "JOIN users ru ON m.receiver_id = ru.id "
        "LEFT JOIN products p ON m.product_id = p.id "
        "WHERE (m.sender_id=%s AND m.sender_deleted=0) "
        "OR (m.receiver_id=%s AND m.receiver_deleted=0) "
        "ORDER BY m.created_at DESC, m.id DESC LIMIT 300",
        (uid, uid),
    )
    conversations = []
    by_user = {}
    for message in rows:
        other_id = message["receiver_id"] if message["sender_id"] == uid else message["sender_id"]
        if other_id not in by_user:
            conversation = {
                "other_user_id": other_id,
                "other_name": message["receiver_name"] if message["sender_id"] == uid else message["sender_name"],
                "last_message": message,
                "last_content": message["content"],
                "last_at": message["created_at"],
                "product_title": message.get("product_title"),
                "unread_count": 0,
            }
            by_user[other_id] = conversation
            conversations.append(conversation)
        if message["receiver_id"] == uid and not message["is_read"]:
            by_user[other_id]["unread_count"] += 1
    return conversations


def get_conversation_messages(uid, other_id):
    return query_all(
        "SELECT m.*, su.nickname AS sender_name, ru.nickname AS receiver_name, "
        "p.title AS product_title "
        "FROM messages m "
        "JOIN users su ON m.sender_id = su.id "
        "JOIN users ru ON m.receiver_id = ru.id "
        "LEFT JOIN products p ON m.product_id = p.id "
        "WHERE (m.sender_id=%s AND m.receiver_id=%s AND m.sender_deleted=0) "
        "OR (m.sender_id=%s AND m.receiver_id=%s AND m.receiver_deleted=0) "
        "ORDER BY m.created_at ASC, m.id ASC",
        (uid, other_id, other_id, uid),
    )


def build_unread_message_conversations(uid):
    rows = query_all(
        "SELECT m.*, su.nickname AS sender_name, p.title AS product_title "
        "FROM messages m "
        "JOIN users su ON m.sender_id = su.id "
        "LEFT JOIN products p ON m.product_id = p.id "
        "WHERE m.receiver_id=%s AND m.is_read=0 AND m.receiver_deleted=0 "
        "ORDER BY m.created_at DESC, m.id DESC LIMIT 100",
        (uid,),
    )
    conversations = []
    by_user = {}
    for message in rows:
        other_id = message["sender_id"]
        if other_id not in by_user:
            conversation = {
                "other_user_id": other_id,
                "sender_name": message["sender_name"],
                "latest_message": message,
                "latest_content": message["content"],
                "latest_at": message["created_at"],
                "product_title": message.get("product_title"),
                "unread_count": 0,
            }
            by_user[other_id] = conversation
            conversations.append(conversation)
        by_user[other_id]["unread_count"] += 1
    return conversations


def column_exists(cur, table_name, column_name):
    cur.execute(
        "SELECT COUNT(*) AS c FROM information_schema.columns "
        "WHERE table_schema=DATABASE() AND table_name=%s AND column_name=%s",
        (table_name, column_name),
    )
    return cur.fetchone()["c"] > 0


def add_column_if_missing(cur, table_name, column_name, definition):
    if not column_exists(cur, table_name, column_name):
        try:
            cur.execute("ALTER TABLE %s ADD COLUMN %s %s" % (table_name, column_name, definition))
        except Exception as exc:
            if getattr(exc, "args", [None])[0] != 1060:
                raise


def sync_order_schema(cur):
    cur.execute(
        "ALTER TABLE orders MODIFY status "
        "ENUM('created','paid','refund_requested','refunded','completed','cancelled') "
        "NOT NULL DEFAULT 'created'"
    )
    add_column_if_missing(cur, "orders", "refund_reason", "VARCHAR(255) DEFAULT NULL COMMENT '退款原因'")
    add_column_if_missing(cur, "orders", "refund_requested_at", "DATETIME DEFAULT NULL")
    add_column_if_missing(cur, "orders", "refunded_at", "DATETIME DEFAULT NULL")


def cancel_expired_unpaid_orders():
    """把超过付款时限的待支付订单自动取消，并释放商品。"""
    with get_cursor(commit=True) as cur:
        cur.execute(
            "UPDATE orders o JOIN products p ON p.id = o.product_id "
            "SET o.status='cancelled', o.cancelled_at=NOW(), p.status='on_sale' "
            "WHERE o.status='created' "
            "AND o.created_at <= DATE_SUB(NOW(), INTERVAL %s MINUTE)",
            (ORDER_PAYMENT_TIMEOUT_MINUTES,),
        )


def ensure_runtime_schema():
    """兼容已经初始化过的旧数据库：补建新表，并迁移旧 image_url。"""
    global RUNTIME_SCHEMA_READY
    if RUNTIME_SCHEMA_READY:
        return
    with get_cursor(commit=True) as cur:
        sync_order_schema(cur)
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS product_images (
              id INT UNSIGNED NOT NULL AUTO_INCREMENT,
              product_id INT UNSIGNED NOT NULL,
              image_url VARCHAR(500) NOT NULL,
              is_cover TINYINT(1) NOT NULL DEFAULT 0,
              sort_no INT UNSIGNED NOT NULL DEFAULT 0,
              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (id),
              KEY idx_product_images_product (product_id, sort_no, id),
              CONSTRAINT fk_product_images_product
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS favorites (
              id INT UNSIGNED NOT NULL AUTO_INCREMENT,
              user_id INT UNSIGNED NOT NULL,
              product_id INT UNSIGNED NOT NULL,
              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (id),
              UNIQUE KEY uk_favorites_user_product (user_id, product_id),
              KEY idx_favorites_user (user_id, created_at),
              KEY idx_favorites_product (product_id),
              CONSTRAINT fk_favorites_user
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
              CONSTRAINT fk_favorites_product
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS reviews (
              id INT UNSIGNED NOT NULL AUTO_INCREMENT,
              order_id INT UNSIGNED NOT NULL,
              reviewer_id INT UNSIGNED NOT NULL,
              target_user_id INT UNSIGNED NOT NULL,
              rating TINYINT UNSIGNED NOT NULL,
              content VARCHAR(500) DEFAULT NULL,
              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (id),
              UNIQUE KEY uk_reviews_order_reviewer (order_id, reviewer_id),
              KEY idx_reviews_target (target_user_id, created_at),
              CONSTRAINT fk_review_order
                FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
              CONSTRAINT fk_review_reviewer
                FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE,
              CONSTRAINT fk_review_target
                FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS messages (
              id INT UNSIGNED NOT NULL AUTO_INCREMENT,
              sender_id INT UNSIGNED NOT NULL,
              receiver_id INT UNSIGNED NOT NULL,
              product_id INT UNSIGNED DEFAULT NULL,
              content VARCHAR(500) NOT NULL,
              is_read TINYINT(1) NOT NULL DEFAULT 0,
              sender_deleted TINYINT(1) NOT NULL DEFAULT 0,
              receiver_deleted TINYINT(1) NOT NULL DEFAULT 0,
              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (id),
              KEY idx_messages_receiver_read (receiver_id, is_read, created_at),
              KEY idx_messages_sender_time (sender_id, created_at),
              KEY idx_messages_product_time (product_id, created_at),
              CONSTRAINT fk_message_sender
                FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
              CONSTRAINT fk_message_receiver
                FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
              CONSTRAINT fk_message_product
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """
        )
        add_column_if_missing(cur, "messages", "sender_deleted", "TINYINT(1) NOT NULL DEFAULT 0")
        add_column_if_missing(cur, "messages", "receiver_deleted", "TINYINT(1) NOT NULL DEFAULT 0")
        cur.execute(
            "SELECT id, image_url FROM products "
            "WHERE image_url IS NOT NULL AND image_url <> '' "
            "AND id NOT IN (SELECT DISTINCT product_id FROM product_images)"
        )
        for product in cur.fetchall():
            for index, url in enumerate(image_urls(product["image_url"])):
                cur.execute(
                    "INSERT INTO product_images (product_id, image_url, is_cover, sort_no) "
                    "VALUES (%s, %s, %s, %s)",
                    (product["id"], url, 1 if index == 0 else 0, index),
                )
    RUNTIME_SCHEMA_READY = True


@app.before_request
def prepare_runtime_schema():
    ensure_runtime_schema()
    cancel_expired_unpaid_orders()


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

    products = hydrate_product_images(query_all(sql, params))
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
    product_images = get_product_image_urls(pid, product.get("image_url"))
    product["images"] = product_images
    product["image_url"] = IMAGE_URL_SEPARATOR.join(product_images) if product_images else product.get("image_url")
    product["favorite_count"] = query_one(
        "SELECT COUNT(*) AS c FROM favorites WHERE product_id=%s",
        (pid,),
    )["c"]
    product["is_favorited"] = False
    if session.get("user_id"):
        product["is_favorited"] = bool(query_one(
            "SELECT id FROM favorites WHERE user_id=%s AND product_id=%s",
            (session["user_id"], pid),
        ))
    review_summary = seller_review_summary(product["seller_id"])
    product["seller_review_count"] = review_summary["count"]
    product["seller_avg_rating"] = review_summary["avg"]
    product["recent_reviews"] = query_all(
        "SELECT r.*, u.nickname AS reviewer_name "
        "FROM reviews r "
        "JOIN orders o ON r.order_id = o.id "
        "JOIN users u ON r.reviewer_id = u.id "
        "WHERE o.product_id=%s AND r.target_user_id=%s "
        "ORDER BY r.created_at DESC LIMIT 5",
        (pid, product["seller_id"]),
    )
    # 浏览量 +1
    with get_cursor(commit=True) as cur:
        cur.execute("UPDATE products SET view_count = view_count + 1 WHERE id=%s", (pid,))
    return render_template("product_detail.html", product=product)


@app.route("/product/<int:pid>/favorite", methods=["POST"])
@login_required
def favorite_product(pid):
    product = query_one("SELECT id, seller_id FROM products WHERE id=%s", (pid,))
    if not product:
        abort(404)
    if product["seller_id"] == session["user_id"]:
        flash("不能收藏自己发布的商品", "warning")
        return redirect(url_for("product_detail", pid=pid))

    with get_cursor(commit=True) as cur:
        cur.execute(
            "INSERT IGNORE INTO favorites (user_id, product_id) VALUES (%s, %s)",
            (session["user_id"], pid),
        )
    flash("已加入收藏", "success")
    return redirect(url_for("product_detail", pid=pid))


@app.route("/product/<int:pid>/unfavorite", methods=["POST"])
@login_required
def unfavorite_product(pid):
    product = query_one("SELECT id FROM products WHERE id=%s", (pid,))
    if not product:
        abort(404)

    with get_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM favorites WHERE user_id=%s AND product_id=%s",
            (session["user_id"], pid),
        )
    flash("已取消收藏", "info")
    return redirect(url_for("product_detail", pid=pid))


@app.route("/product/<int:pid>/message", methods=["POST"])
@login_required
def send_product_message(pid):
    product = query_one("SELECT id, seller_id FROM products WHERE id=%s", (pid,))
    if not product:
        abort(404)
    if product["seller_id"] == session["user_id"]:
        flash("不能给自己发布的商品留言", "warning")
        return redirect(url_for("product_detail", pid=pid))

    content = request.form.get("content", "").strip()
    if not content:
        flash("消息内容不能为空", "danger")
        return redirect(url_for("product_detail", pid=pid))
    if len(content) > 500:
        flash("消息内容最多 500 字", "danger")
        return redirect(url_for("product_detail", pid=pid))

    with get_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO messages (sender_id, receiver_id, product_id, content) "
            "VALUES (%s, %s, %s, %s)",
            (session["user_id"], product["seller_id"], pid, content),
        )
    flash("消息已发送给卖家", "success")
    return redirect(url_for("product_detail", pid=pid))


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
            all_image_urls = uploaded_image_urls or ([image_url] if image_url else [])
            cur.execute(
                "INSERT INTO products "
                "(seller_id, category_id, title, description, price, condition_level, image_url) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (session["user_id"], form["category_id"], form["title"], form["description"],
                 form["price"], form["condition_level"],
                 IMAGE_URL_SEPARATOR.join(all_image_urls) or None),
            )
            set_product_images(cur, cur.lastrowid, all_image_urls)
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

    current_images = get_product_image_urls(pid, product.get("image_url"))
    product["images"] = current_images
    product["image_url"] = IMAGE_URL_SEPARATOR.join(current_images) if current_images else product.get("image_url")
    categories = query_all("SELECT * FROM categories ORDER BY id")
    if request.method == "POST":
        form = read_product_form()
        image_files = read_image_files()

        error = validate_product_form(form)
        if error:
            flash(error, "danger")
            return render_template("edit_product.html", product=product, categories=categories)

        try:
            existing_images = get_product_image_urls(pid, product.get("image_url"))
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
        with get_cursor(commit=True) as cur:
            cur.execute(
                "UPDATE products SET category_id=%s, title=%s, description=%s, "
                "price=%s, condition_level=%s WHERE id=%s",
                (form["category_id"], form["title"], form["description"],
                 form["price"], form["condition_level"], pid),
            )
            set_product_images(cur, pid, merged_images)
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
    order = hydrate_product_images([order])[0]
    payment_deadline = None
    payment_deadline_ms = None
    if order["status"] == "created" and order.get("created_at"):
        payment_deadline = order["created_at"] + timedelta(minutes=ORDER_PAYMENT_TIMEOUT_MINUTES)
        payment_deadline_ms = int(payment_deadline.timestamp() * 1000)
    payments = query_all("SELECT * FROM payments WHERE order_id=%s ORDER BY id", (oid,))
    reviews = query_all(
        "SELECT r.*, ru.nickname AS reviewer_name, tu.nickname AS target_name "
        "FROM reviews r "
        "JOIN users ru ON r.reviewer_id = ru.id "
        "JOIN users tu ON r.target_user_id = tu.id "
        "WHERE r.order_id=%s ORDER BY r.created_at",
        (oid,),
    )
    my_review = query_one(
        "SELECT id FROM reviews WHERE order_id=%s AND reviewer_id=%s",
        (oid, uid),
    )
    return render_template(
        "order_detail.html", order=order, payments=payments,
        reviews=reviews, my_review=my_review,
        review_target_id=other_order_user(order, uid),
        payment_deadline=payment_deadline,
        payment_deadline_ms=payment_deadline_ms,
        server_now_ms=int(datetime.now().timestamp() * 1000),
    )


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
            if order["created_at"] <= datetime.now() - timedelta(minutes=ORDER_PAYMENT_TIMEOUT_MINUTES):
                cur.execute("UPDATE products SET status='on_sale' WHERE id=%s", (order["product_id"],))
                cur.execute(
                    "UPDATE orders SET status='cancelled', cancelled_at=NOW() WHERE id=%s",
                    (oid,),
                )
                flash("订单超过 10 分钟未付款，已自动取消", "warning")
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


@app.route("/order/<int:oid>/refund/request", methods=["POST"])
@login_required
def request_refund(oid):
    buyer_id = session["user_id"]
    reason = request.form.get("reason", "").strip()
    if len(reason) > 255:
        flash("退款原因最多 255 字", "danger")
        return redirect(url_for("order_detail", oid=oid))

    order = query_one("SELECT * FROM orders WHERE id=%s", (oid,))
    if not order:
        abort(404)
    if order["buyer_id"] != buyer_id:
        abort(403)
    if order["status"] != "paid":
        flash("只有已付款且未确认收货的订单可以申请退款", "warning")
        return redirect(url_for("order_detail", oid=oid))

    with get_cursor(commit=True) as cur:
        cur.execute(
            "UPDATE orders SET status='refund_requested', refund_reason=%s, "
            "refund_requested_at=NOW() WHERE id=%s",
            (reason or None, oid),
        )
    flash("退款申请已提交，等待卖家同意", "success")
    return redirect(url_for("order_detail", oid=oid))


@app.route("/order/<int:oid>/refund/approve", methods=["POST"])
@login_required
def approve_refund(oid):
    seller_id = session["user_id"]
    try:
        with get_cursor(commit=True) as cur:
            cur.execute("SELECT * FROM orders WHERE id=%s FOR UPDATE", (oid,))
            order = cur.fetchone()
            if not order:
                flash("订单不存在", "danger")
                return redirect(url_for("index"))
            if order["seller_id"] != seller_id:
                abort(403)
            if order["status"] != "refund_requested":
                flash("当前订单没有待处理的退款申请", "warning")
                return redirect(url_for("order_detail", oid=oid))

            cur.execute(
                "UPDATE users SET balance = balance + %s WHERE id=%s",
                (order["amount"], order["buyer_id"]),
            )
            cur.execute("UPDATE products SET status='on_sale' WHERE id=%s", (order["product_id"],))
            cur.execute(
                "UPDATE orders SET status='refunded', refunded_at=NOW() WHERE id=%s",
                (oid,),
            )
        flash("退款已同意，金额已退回买家余额", "success")
    except Exception:
        flash("退款处理失败，请重试", "danger")
    return redirect(url_for("order_detail", oid=oid))


@app.route("/order/<int:oid>/review", methods=["POST"])
@login_required
def review_order(oid):
    uid = session["user_id"]
    order = query_one("SELECT * FROM orders WHERE id=%s", (oid,))
    if not order:
        abort(404)
    target_user_id = other_order_user(order, uid)
    if not target_user_id:
        abort(403)
    if order["status"] != "completed":
        flash("订单完成后才可以评价", "warning")
        return redirect(url_for("order_detail", oid=oid))
    if query_one("SELECT id FROM reviews WHERE order_id=%s AND reviewer_id=%s", (oid, uid)):
        flash("这个订单你已经评价过了", "warning")
        return redirect(url_for("order_detail", oid=oid))

    rating = request.form.get("rating", type=int)
    content = request.form.get("content", "").strip()
    if rating is None or rating < 1 or rating > 5:
        flash("请选择 1 到 5 分评价", "danger")
        return redirect(url_for("order_detail", oid=oid))
    if len(content) > 500:
        flash("评价内容最多 500 字", "danger")
        return redirect(url_for("order_detail", oid=oid))

    with get_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO reviews (order_id, reviewer_id, target_user_id, rating, content) "
            "VALUES (%s, %s, %s, %s, %s)",
            (oid, uid, target_user_id, rating, content or None),
        )
    flash("评价已提交", "success")
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
    favorite_cnt = query_one("SELECT COUNT(*) AS c FROM favorites WHERE user_id=%s", (uid,))["c"]
    unread_message_cnt = query_one(
        "SELECT COUNT(*) AS c FROM messages "
        "WHERE receiver_id=%s AND is_read=0 AND receiver_deleted=0",
        (uid,),
    )["c"]
    return render_template(
        "me.html", selling_cnt=selling_cnt, bought_cnt=bought_cnt,
        sold_cnt=sold_cnt, favorite_cnt=favorite_cnt,
        unread_message_cnt=unread_message_cnt)


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
    products = hydrate_product_images(query_all(
        "SELECT p.*, c.name AS category_name, "
        "(SELECT COUNT(*) FROM orders o WHERE o.product_id = p.id) AS order_count "
        "FROM products p "
        "LEFT JOIN categories c ON p.category_id = c.id "
        "WHERE p.seller_id=%s ORDER BY p.created_at DESC",
        (session["user_id"],),
    ))
    return render_template("my_selling.html", products=products)


@app.route("/me/favorites")
@login_required
def my_favorites():
    products = hydrate_product_images(query_all(
        "SELECT p.*, u.nickname AS seller_name, c.name AS category_name, "
        "f.created_at AS favorited_at "
        "FROM favorites f "
        "JOIN products p ON f.product_id = p.id "
        "JOIN users u ON p.seller_id = u.id "
        "LEFT JOIN categories c ON p.category_id = c.id "
        "WHERE f.user_id=%s "
        "ORDER BY f.created_at DESC",
        (session["user_id"],),
    ))
    return render_template("my_favorites.html", products=products)


@app.route("/me/messages")
@login_required
def my_messages():
    uid = session["user_id"]
    selected_user_id = request.args.get("with_user", type=int)
    selected_user = None
    selected_messages = []
    reply_product_id = None

    if selected_user_id and selected_user_id != uid:
        selected_user = query_one(
            "SELECT id, username, nickname FROM users WHERE id=%s",
            (selected_user_id,),
        )
        if selected_user:
            with get_cursor(commit=True) as cur:
                cur.execute(
                    "UPDATE messages SET is_read=1 "
                    "WHERE sender_id=%s AND receiver_id=%s "
                    "AND receiver_deleted=0 AND is_read=0",
                    (selected_user_id, uid),
                )
            selected_messages = get_conversation_messages(uid, selected_user_id)
            for message in reversed(selected_messages):
                if message.get("product_id"):
                    reply_product_id = message["product_id"]
                    break

    conversations = build_message_conversations(uid)
    if selected_user_id and not selected_user:
        flash("这个联系人不存在", "warning")
    return render_template(
        "my_messages.html",
        conversations=conversations,
        selected_user=selected_user,
        selected_user_id=selected_user_id,
        selected_messages=selected_messages,
        reply_product_id=reply_product_id,
    )


@app.route("/me/notifications")
@login_required
def my_notifications():
    uid = session["user_id"]
    unread_conversations = build_unread_message_conversations(uid)
    refund_orders = query_all(
        "SELECT o.*, p.title, bu.nickname AS buyer_name "
        "FROM orders o "
        "JOIN products p ON o.product_id = p.id "
        "JOIN users bu ON o.buyer_id = bu.id "
        "WHERE o.seller_id=%s AND o.status='refund_requested' "
        "ORDER BY o.refund_requested_at DESC, o.created_at DESC LIMIT 20",
        (uid,),
    )
    return render_template(
        "notifications.html",
        unread_conversations=unread_conversations,
        refund_orders=refund_orders,
    )


@app.route("/message/<int:mid>/reply", methods=["POST"])
@login_required
def reply_message(mid):
    uid = session["user_id"]
    message = query_one("SELECT * FROM messages WHERE id=%s", (mid,))
    if not message:
        abort(404)
    if uid not in (message["sender_id"], message["receiver_id"]):
        abort(403)
    if uid == message["sender_id"] and message.get("sender_deleted"):
        abort(404)
    if uid == message["receiver_id"] and message.get("receiver_deleted"):
        abort(404)

    receiver_id = message["sender_id"] if uid == message["receiver_id"] else message["receiver_id"]
    content = request.form.get("content", "").strip()
    if not content:
        flash("回复内容不能为空", "danger")
        return redirect(url_for("my_messages", with_user=receiver_id))
    if len(content) > 500:
        flash("回复内容最多 500 字", "danger")
        return redirect(url_for("my_messages", with_user=receiver_id))

    with get_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO messages (sender_id, receiver_id, product_id, content) "
            "VALUES (%s, %s, %s, %s)",
            (uid, receiver_id, message.get("product_id"), content),
        )
    flash("回复已发送", "success")
    return redirect(url_for("my_messages", with_user=receiver_id))


@app.route("/message/conversation/<int:other_id>/reply", methods=["POST"])
@login_required
def reply_conversation(other_id):
    uid = session["user_id"]
    if other_id == uid:
        abort(403)
    other_user = query_one("SELECT id FROM users WHERE id=%s", (other_id,))
    if not other_user:
        abort(404)

    content = request.form.get("content", "").strip()
    product_id = request.form.get("product_id", type=int)
    if not content:
        flash("回复内容不能为空", "danger")
        return redirect(url_for("my_messages", with_user=other_id))
    if len(content) > 500:
        flash("回复内容最多 500 字", "danger")
        return redirect(url_for("my_messages", with_user=other_id))
    if product_id and not query_one("SELECT id FROM products WHERE id=%s", (product_id,)):
        product_id = None

    with get_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO messages (sender_id, receiver_id, product_id, content) "
            "VALUES (%s, %s, %s, %s)",
            (uid, other_id, product_id, content),
        )
    flash("回复已发送", "success")
    return redirect(url_for("my_messages", with_user=other_id))


@app.route("/message/conversation/<int:other_id>/delete", methods=["POST"])
@login_required
def delete_conversation(other_id):
    uid = session["user_id"]
    if other_id == uid:
        abort(403)
    with get_cursor(commit=True) as cur:
        cur.execute(
            "UPDATE messages SET sender_deleted=1 "
            "WHERE sender_id=%s AND receiver_id=%s",
            (uid, other_id),
        )
        cur.execute(
            "UPDATE messages SET receiver_deleted=1, is_read=1 "
            "WHERE receiver_id=%s AND sender_id=%s",
            (uid, other_id),
        )
    flash("对话已删除", "success")
    return redirect(url_for("my_messages"))


@app.route("/me/bought")
@login_required
def my_bought():
    orders = hydrate_product_images(query_all(
        "SELECT o.*, p.title, p.image_url, su.nickname AS seller_name "
        "FROM orders o JOIN products p ON o.product_id = p.id "
        "JOIN users su ON o.seller_id = su.id "
        "WHERE o.buyer_id=%s ORDER BY o.created_at DESC",
        (session["user_id"],),
    ))
    return render_template("my_orders.html", orders=orders, role="buyer")


@app.route("/me/sold")
@login_required
def my_sold():
    orders = hydrate_product_images(query_all(
        "SELECT o.*, p.title, p.image_url, bu.nickname AS buyer_name "
        "FROM orders o JOIN products p ON o.product_id = p.id "
        "JOIN users bu ON o.buyer_id = bu.id "
        "WHERE o.seller_id=%s ORDER BY o.created_at DESC",
        (session["user_id"],),
    ))
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
