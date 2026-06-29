"""只读冒烟检查：解析关键源码和模板，不写入业务数据库。"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
PY_FILES = [
    "app.py",
    "config.py",
    "db.py",
    "init_db.py",
    "_verify.py",
]
TEMPLATE_FILES = [
    "templates/base.html",
    "templates/index.html",
    "templates/login.html",
    "templates/register.html",
    "templates/product_detail.html",
    "templates/order_detail.html",
    "templates/recharge.html",
]


def main():
    for relative in PY_FILES:
        path = ROOT / relative
        compile(path.read_text(encoding="utf-8"), str(path), "exec")
    for relative in TEMPLATE_FILES:
        path = ROOT / relative
        if not path.exists():
            raise FileNotFoundError(path)
    print("smoke ok: source and templates are readable; database was not touched")


if __name__ == "__main__":
    main()
