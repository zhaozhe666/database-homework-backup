# -*- coding: utf-8 -*-
"""项目配置：数据库连接与 Flask 密钥。

数据库环境（与本机一致）：
    MySQL 5.6  ->  D:\\BtSoft\\mysql\\MySQL5.6\\bin
    端口 3306，用户 root，密码 414290
    服务管理： Win+R -> services.msc -> 启动/停止 MySQL 服务
"""

# 数据库连接配置
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 3306,
    "user": "root",
    "password": "414290",
    "database": "secondhand",
    "charset": "utf8mb4",
}

# Flask 会话加密密钥（生产环境请改为随机值）
SECRET_KEY = "secondhand-market-secret-key-2026"