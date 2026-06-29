# -*- coding: utf-8 -*-
"""项目配置：数据库连接与 Flask 密钥。

数据库环境（与本机一致）：
    MySQL 5.6  ->  D:\\BtSoft\\mysql\\MySQL5.6\\bin
    端口 3306，用户 root，密码 414290
    服务管理： Win+R -> services.msc -> 启动/停止 MySQL 服务

生产或部署环境可通过环境变量覆盖默认配置：
    SECONDHAND_DB_HOST / SECONDHAND_DB_PORT / SECONDHAND_DB_USER
    SECONDHAND_DB_PASSWORD / SECONDHAND_DB_NAME / SECONDHAND_SECRET_KEY
    SECONDHAND_DEBUG
"""

import os


def _env_int(name, default):
    value = os.environ.get(name)
    if not value:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def _env_bool(name, default=False):
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in ("1", "true", "yes", "on")

# 数据库连接配置
DB_CONFIG = {
    "host": os.environ.get("SECONDHAND_DB_HOST", "127.0.0.1"),
    "port": _env_int("SECONDHAND_DB_PORT", 3306),
    "user": os.environ.get("SECONDHAND_DB_USER", "root"),
    "password": os.environ.get("SECONDHAND_DB_PASSWORD", "414290"),
    "database": os.environ.get("SECONDHAND_DB_NAME", "secondhand"),
    "charset": os.environ.get("SECONDHAND_DB_CHARSET", "utf8mb4"),
}

# Flask 会话加密密钥（生产环境请改为随机值）
SECRET_KEY = os.environ.get("SECONDHAND_SECRET_KEY", "secondhand-market-secret-key-2026")

# 本机调试可设 SECONDHAND_DEBUG=1；默认关闭，避免部署时暴露调试信息。
DEBUG = _env_bool("SECONDHAND_DEBUG", False)
