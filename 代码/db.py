# -*- coding: utf-8 -*-
"""数据库访问层：连接、查询与事务封装（基于 PyMySQL）。"""

from contextlib import contextmanager

import pymysql
from pymysql.cursors import DictCursor

from config import DB_CONFIG


def get_connection(use_database=True):
    """创建一个新的数据库连接。

    use_database=False 时不选择具体数据库（用于初始化建库）。
    """
    params = dict(
        host=DB_CONFIG["host"],
        port=DB_CONFIG["port"],
        user=DB_CONFIG["user"],
        password=DB_CONFIG["password"],
        charset=DB_CONFIG["charset"],
        cursorclass=DictCursor,
        autocommit=False,
    )
    if use_database:
        params["database"] = DB_CONFIG["database"]
    return pymysql.connect(**params)


@contextmanager
def get_cursor(commit=False):
    """游标上下文管理器。

    在 with 代码块内的多条语句处于同一事务：
    - 正常结束时若 commit=True 则提交；
    - 出现异常则回滚并向上抛出。
    """
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            yield cur
        if commit:
            conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def query_all(sql, args=None):
    """查询多行。"""
    with get_cursor() as cur:
        cur.execute(sql, args)
        return cur.fetchall()


def query_one(sql, args=None):
    """查询单行。"""
    with get_cursor() as cur:
        cur.execute(sql, args)
        return cur.fetchone()


def execute(sql, args=None):
    """执行单条写语句（自动提交），返回自增主键。"""
    with get_cursor(commit=True) as cur:
        cur.execute(sql, args)
        return cur.lastrowid