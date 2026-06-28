-- MySQL dump 10.13  Distrib 5.6.51, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: secondhand
-- ------------------------------------------------------
-- Server version	5.6.51-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `admin_logs`
--

DROP TABLE IF EXISTS `admin_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_logs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int(10) unsigned NOT NULL,
  `action` varchar(60) NOT NULL,
  `target_type` varchar(40) NOT NULL,
  `target_id` int(10) unsigned DEFAULT NULL,
  `detail` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin_logs_admin` (`admin_id`,`created_at`),
  KEY `idx_admin_logs_target` (`target_type`,`target_id`),
  CONSTRAINT `fk_admin_logs_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=78 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_logs`
--

LOCK TABLES `admin_logs` WRITE;
/*!40000 ALTER TABLE `admin_logs` DISABLE KEYS */;
INSERT INTO `admin_logs` VALUES (1,8,'product_report_resolved','product_report',1,'演示验收：举报成立，下架核实','2026-06-26 03:11:14'),(2,8,'product_remove','product',3,'演示验收：举报成立，下架核实','2026-06-26 03:11:14'),(3,8,'order_appeal_resolved','order_appeal',1,'演示验收：建议双方线下补充凭证','2026-06-26 03:11:14'),(4,8,'product_report_rejected','product_report',2,'不符合','2026-06-26 08:34:03'),(5,8,'product_restore','product',13,'分隔符','2026-06-27 06:21:49'),(69,8,'product_report_rejected','product_report',10,'????????2','2026-06-27 12:21:49'),(70,8,'product_report_rejected','product_report',9,'????????','2026-06-27 12:21:50'),(71,8,'product_report_rejected','product_report',8,'11111','2026-06-27 12:21:52'),(72,8,'product_report_rejected','product_report',7,'测试举报弹窗展示','2026-06-27 12:21:54'),(73,8,'product_report_rejected','product_report',6,'??????','2026-06-27 14:03:18'),(74,8,'product_report_rejected','product_report',5,'??????','2026-06-27 14:03:20'),(75,8,'product_report_rejected','product_report',4,'??????','2026-06-27 14:03:22'),(76,8,'product_report_rejected','product_report',3,'111111111','2026-06-27 14:03:23'),(77,8,'product_report_rejected','product_report',12,'说的啥啊','2026-06-27 14:04:36');
/*!40000 ALTER TABLE `admin_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admins`
--

DROP TABLE IF EXISTS `admins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admins` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `can_manage_products` tinyint(1) NOT NULL DEFAULT '1',
  `can_manage_users` tinyint(1) NOT NULL DEFAULT '1',
  `can_manage_admin_register` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(10) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_user` (`user_id`),
  KEY `idx_admin_created_by` (`created_by`),
  CONSTRAINT `fk_admin_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_admin_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admins`
--

LOCK TABLES `admins` WRITE;
/*!40000 ALTER TABLE `admins` DISABLE KEYS */;
INSERT INTO `admins` VALUES (1,8,1,1,1,NULL,'2026-05-30 15:51:29');
/*!40000 ALTER TABLE `admins` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `app_settings`
--

DROP TABLE IF EXISTS `app_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `app_settings` (
  `setting_key` varchar(80) NOT NULL,
  `setting_value` varchar(255) NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `app_settings`
--

LOCK TABLES `app_settings` WRITE;
/*!40000 ALTER TABLE `app_settings` DISABLE KEYS */;
INSERT INTO `app_settings` VALUES ('admin_registration_enabled','1','2026-06-27 09:00:20');
/*!40000 ALTER TABLE `app_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `categories`
--

DROP TABLE IF EXISTS `categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `categories` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COMMENT='商品分类';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `categories`
--

LOCK TABLES `categories` WRITE;
/*!40000 ALTER TABLE `categories` DISABLE KEYS */;
INSERT INTO `categories` VALUES (7,'其他'),(2,'图书教材'),(1,'数码电子'),(3,'服饰鞋包'),(5,'生活家居'),(6,'美妆个护'),(4,'运动户外');
/*!40000 ALTER TABLE `categories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `favorites`
--

DROP TABLE IF EXISTS `favorites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `favorites` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `product_id` int(10) unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_favorites_user_product` (`user_id`,`product_id`),
  KEY `idx_favorites_user` (`user_id`,`created_at`),
  KEY `idx_favorites_product` (`product_id`),
  CONSTRAINT `fk_favorites_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_favorites_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `favorites`
--

LOCK TABLES `favorites` WRITE;
/*!40000 ALTER TABLE `favorites` DISABLE KEYS */;
INSERT INTO `favorites` VALUES (5,2,5,'2026-05-30 13:37:15'),(14,1,5,'2026-06-26 04:50:54');
/*!40000 ALTER TABLE `favorites` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `messages` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sender_id` int(10) unsigned NOT NULL,
  `receiver_id` int(10) unsigned NOT NULL,
  `product_id` int(10) unsigned DEFAULT NULL,
  `content` varchar(500) NOT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `sender_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `receiver_deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_messages_receiver_read` (`receiver_id`,`is_read`,`created_at`),
  KEY `idx_messages_sender_time` (`sender_id`,`created_at`),
  KEY `idx_messages_product_time` (`product_id`,`created_at`),
  CONSTRAINT `fk_message_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_message_receiver` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_message_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=78 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `messages`
--

LOCK TABLES `messages` WRITE;
/*!40000 ALTER TABLE `messages` DISABLE KEYS */;
INSERT INTO `messages` VALUES (3,2,1,1,'支持面交吗',1,'2026-05-30 13:52:17',0,1),(4,1,2,1,'可以的',1,'2026-05-30 13:52:58',1,0),(8,3,2,12,'erwrtertyrtuy',1,'2026-05-30 14:21:19',0,0),(9,3,2,15,'jkhdfsgdfhiuv',1,'2026-05-30 14:25:23',0,0),(14,2,1,55,'可以小刀吗',1,'2026-06-01 08:24:25',0,1),(15,1,2,55,'最低价了，兄弟',1,'2026-06-01 08:24:55',1,0),(16,2,1,55,'求求你了',1,'2026-06-01 08:25:20',0,1),(17,1,3,57,'古代封建快攻打法上课了国家的反馈',1,'2026-06-25 15:31:20',0,0),(18,3,1,57,'咖啡机尽快落实',1,'2026-06-25 15:32:09',0,0),(19,1,2,12,'可以小刀吗',1,'2026-06-26 08:32:13',1,0),(20,2,1,12,'最低价了，兄弟',1,'2026-06-26 08:35:14',0,1),(40,1,2,4,'????????',1,'2026-06-26 15:56:54',1,0),(45,8,1,1,'测试一下，发完直接跳对话',1,'2026-06-26 15:59:49',0,1),(46,1,3,57,'你好',0,'2026-06-26 16:02:19',0,0),(51,1,2,4,'??????????',1,'2026-06-26 16:16:30',1,0),(56,1,2,4,'??????????2',1,'2026-06-26 16:18:11',1,0),(57,2,1,NULL,'验收消息 2026-06-27 contact redirect',1,'2026-06-26 16:18:35',0,1),(77,1,2,56,'你好',0,'2026-06-27 13:37:09',0,0);
/*!40000 ALTER TABLE `messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `actor_id` int(10) unsigned DEFAULT NULL,
  `order_id` int(10) unsigned DEFAULT NULL,
  `product_id` int(10) unsigned DEFAULT NULL,
  `notice_type` varchar(40) NOT NULL,
  `title` varchar(120) NOT NULL,
  `content` text,
  `is_read` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notifications_user_read` (`user_id`,`is_read`,`created_at`),
  KEY `idx_notifications_order` (`order_id`),
  KEY `idx_notifications_product` (`product_id`),
  KEY `fk_notification_actor` (`actor_id`),
  CONSTRAINT `fk_notification_actor` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notification_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_notification_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notification_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=353 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1,1,8,NULL,3,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：已处理。演示验收：举报成立，下架核实',1,'2026-06-26 03:11:14'),(2,2,8,NULL,3,'product_report_handled','商品举报处理结果','商品《罗技 MX Master 3 鼠标》的举报已处理，结果：已处理。演示验收：举报成立，下架核实',0,'2026-06-26 03:11:14'),(3,2,8,43,1,'order_appeal_handled','交易申诉已有仲裁结果','订单 202606011628034600 的申诉结果：已处理。演示验收：建议双方线下补充凭证',0,'2026-06-26 03:11:14'),(4,1,8,43,1,'order_appeal_handled','交易申诉已有仲裁结果','订单 202606011628034600 的申诉结果：已处理。演示验收：建议双方线下补充凭证',1,'2026-06-26 03:11:14'),(5,1,8,NULL,12,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。不符合',1,'2026-06-26 08:34:03'),(6,2,8,NULL,12,'product_report_handled','商品举报处理结果','商品《宿舍折叠小桌板》的举报已处理，结果：不成立。不符合',0,'2026-06-26 08:34:03'),(7,3,1,44,57,'order_created','有人下单，等待付款','你的商品《宿舍小容量电热水壶》已被买家下单，付款前商品会暂时锁定。',0,'2026-06-26 09:03:13'),(8,3,1,44,57,'order_paid','买家已付款，等待发货','订单 202606261703136070 已支付成功，请及时发货。',0,'2026-06-26 09:03:21'),(9,1,NULL,44,57,'order_paid','支付成功，等待卖家发货','订单 202606261703136070 已支付成功，卖家发货后会继续提醒你。',1,'2026-06-26 09:03:21'),(16,1,2,47,36,'order_created','有人下单，等待付款','你的商品《儿童健康乐观和肉体哦·》已被买家下单，付款前商品会暂时锁定。',1,'2026-06-26 09:28:15'),(17,1,2,48,58,'order_created','有人下单，等待付款','你的商品《大学英语六级真题资料》已被买家下单，付款前商品会暂时锁定。',1,'2026-06-26 09:29:10'),(18,1,2,48,58,'order_paid','买家已付款，等待发货','订单 202606261729105800 已支付成功，请及时发货。',1,'2026-06-26 09:29:11'),(19,2,NULL,48,58,'order_paid','支付成功，等待卖家发货','订单 202606261729105800 已支付成功，卖家发货后会继续提醒你。',0,'2026-06-26 09:29:11'),(82,3,2,59,59,'order_created','有人下单，等待付款','你的商品《深蓝色上课双肩包》已被买家下单，付款前商品会暂时锁定。',0,'2026-06-26 09:37:43'),(83,3,2,59,59,'order_paid','买家已付款，等待发货','订单 202606261737433463 已支付成功，请及时发货。',0,'2026-06-26 09:37:43'),(84,2,NULL,59,59,'order_paid','支付成功，等待卖家发货','订单 202606261737433463 已支付成功，卖家发货后会继续提醒你。',0,'2026-06-26 09:37:43'),(85,2,NULL,47,36,'order_timeout_cancelled','订单已超时取消','订单 202606261728152563 超过 10 分钟未付款，系统已自动取消。',0,'2026-06-26 09:38:17'),(86,1,NULL,47,36,'order_timeout_cancelled','待付款订单已超时取消','商品《儿童健康乐观和肉体哦·》的待付款订单已超时取消，商品已恢复在售。',1,'2026-06-26 09:38:17'),(87,2,8,NULL,13,'product_restored_by_admin','你的商品已恢复上架','商品《分隔符》已由管理员恢复上架。',0,'2026-06-27 06:21:49'),(153,2,27,71,15,'order_created','有人下单，等待付款','你的商品《古典风格》已被买家下单，付款前商品会暂时锁定。',0,'2026-06-27 07:14:07'),(154,27,NULL,71,15,'order_timeout_cancelled','订单已超时取消','订单 202606271514070620 超过 10 分钟未付款，系统已自动取消。',1,'2026-06-27 07:35:22'),(155,2,NULL,71,15,'order_timeout_cancelled','待付款订单已超时取消','商品《古典风格》的待付款订单已超时取消，商品已恢复在售。',0,'2026-06-27 07:35:22'),(272,2,1,48,58,'order_shipped','卖家已发货','订单 202606261729105800 已发货，请收到商品后及时确认收货。',0,'2026-06-27 08:41:57'),(335,1,8,NULL,4,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。',1,'2026-06-27 12:21:49'),(336,2,8,NULL,4,'product_report_handled','商品举报处理结果','商品《迪卡侬 折叠自行车》的举报已处理，结果：不成立。',0,'2026-06-27 12:21:49'),(337,1,8,NULL,4,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。',1,'2026-06-27 12:21:50'),(338,2,8,NULL,4,'product_report_handled','商品举报处理结果','商品《迪卡侬 折叠自行车》的举报已处理，结果：不成立。',0,'2026-06-27 12:21:50'),(339,8,8,NULL,4,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。',1,'2026-06-27 12:21:52'),(340,2,8,NULL,4,'product_report_handled','商品举报处理结果','商品《迪卡侬 折叠自行车》的举报已处理，结果：不成立。',0,'2026-06-27 12:21:52'),(341,8,8,NULL,4,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。',1,'2026-06-27 12:21:54'),(342,2,8,NULL,4,'product_report_handled','商品举报处理结果','商品《迪卡侬 折叠自行车》的举报已处理，结果：不成立。',0,'2026-06-27 12:21:54'),(343,1,8,NULL,4,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。',1,'2026-06-27 14:03:18'),(344,2,8,NULL,4,'product_report_handled','商品举报处理结果','商品《迪卡侬 折叠自行车》的举报已处理，结果：不成立。',0,'2026-06-27 14:03:18'),(345,1,8,NULL,4,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。',1,'2026-06-27 14:03:20'),(346,2,8,NULL,4,'product_report_handled','商品举报处理结果','商品《迪卡侬 折叠自行车》的举报已处理，结果：不成立。',0,'2026-06-27 14:03:20'),(347,1,8,NULL,4,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。',1,'2026-06-27 14:03:22'),(348,2,8,NULL,4,'product_report_handled','商品举报处理结果','商品《迪卡侬 折叠自行车》的举报已处理，结果：不成立。',0,'2026-06-27 14:03:22'),(349,8,8,NULL,57,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。',1,'2026-06-27 14:03:23'),(350,3,8,NULL,57,'product_report_handled','商品举报处理结果','商品《宿舍小容量电热水壶》的举报已处理，结果：不成立。',0,'2026-06-27 14:03:23'),(351,1,8,NULL,57,'product_report_handled','商品举报已处理','你提交的商品举报已处理，结果：不成立。说的啥啊',1,'2026-06-27 14:04:36'),(352,3,8,NULL,57,'product_report_handled','商品举报处理结果','商品《宿舍小容量电热水壶》的举报已处理，结果：不成立。说的啥啊',0,'2026-06-27 14:04:36');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_appeals`
--

DROP TABLE IF EXISTS `order_appeals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `order_appeals` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `order_id` int(10) unsigned NOT NULL,
  `appellant_id` int(10) unsigned NOT NULL,
  `reason` varchar(255) NOT NULL,
  `status` enum('pending','resolved','rejected') NOT NULL DEFAULT 'pending',
  `admin_id` int(10) unsigned DEFAULT NULL,
  `resolution` varchar(255) DEFAULT NULL,
  `handled_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order_appeals_status` (`status`,`created_at`),
  KEY `idx_order_appeals_order` (`order_id`),
  KEY `fk_order_appeal_appellant` (`appellant_id`),
  KEY `fk_order_appeal_admin` (`admin_id`),
  CONSTRAINT `fk_order_appeal_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_order_appeal_appellant` FOREIGN KEY (`appellant_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_order_appeal_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_appeals`
--

LOCK TABLES `order_appeals` WRITE;
/*!40000 ALTER TABLE `order_appeals` DISABLE KEYS */;
INSERT INTO `order_appeals` VALUES (1,43,2,'演示验收：交易双方协商无果','resolved',8,'演示验收：建议双方线下补充凭证','2026-06-26 11:11:14','2026-06-26 03:11:14');
/*!40000 ALTER TABLE `order_appeals` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orders`
--

DROP TABLE IF EXISTS `orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `orders` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `order_no` varchar(32) NOT NULL COMMENT '订单号',
  `product_id` int(10) unsigned NOT NULL,
  `buyer_id` int(10) unsigned NOT NULL,
  `seller_id` int(10) unsigned NOT NULL,
  `amount` decimal(10,2) NOT NULL COMMENT '成交金额',
  `status` enum('created','paid','shipped','refund_requested','refunded','completed','cancelled') NOT NULL DEFAULT 'created',
  `address` varchar(255) DEFAULT NULL COMMENT '收货地址',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `paid_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `cancelled_at` datetime DEFAULT NULL,
  `refund_reason` varchar(255) DEFAULT NULL COMMENT '退款原因',
  `refund_requested_at` datetime DEFAULT NULL,
  `refunded_at` datetime DEFAULT NULL,
  `shipped_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_buyer` (`buyer_id`),
  KEY `idx_seller` (`seller_id`),
  KEY `idx_product` (`product_id`),
  CONSTRAINT `fk_order_buyer` FOREIGN KEY (`buyer_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_order_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
  CONSTRAINT `fk_order_seller` FOREIGN KEY (`seller_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=72 DEFAULT CHARSET=utf8mb4 COMMENT='订单';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orders`
--

LOCK TABLES `orders` WRITE;
/*!40000 ALTER TABLE `orders` DISABLE KEYS */;
INSERT INTO `orders` VALUES (3,'202605301438042240',6,1,3,45.00,'completed','数据分类','2026-05-30 06:38:04','2026-05-30 14:38:06','2026-05-30 14:38:18',NULL,NULL,NULL,NULL,NULL),(4,'202605301438470959',1,2,1,3200.00,'refunded',NULL,'2026-05-30 06:38:47','2026-05-30 14:38:49',NULL,NULL,NULL,'2026-05-30 22:06:37','2026-05-30 22:07:48',NULL),(9,'202605302154156559',15,1,2,34.00,'cancelled',NULL,'2026-05-30 13:54:15',NULL,NULL,'2026-05-30 21:54:26',NULL,NULL,NULL,NULL),(16,'202605302208180163',15,1,2,34.00,'cancelled',NULL,'2026-05-30 14:08:18',NULL,NULL,'2026-05-30 22:18:19',NULL,NULL,NULL,NULL),(21,'202605302219329755',5,1,3,350.00,'refunded',NULL,'2026-05-30 14:19:32','2026-05-30 22:19:41',NULL,NULL,NULL,'2026-05-30 22:20:05','2026-05-30 22:20:39',NULL),(32,'202606011625307103',55,2,1,180.00,'completed',NULL,'2026-06-01 08:25:30','2026-06-01 16:25:38','2026-06-01 16:26:33',NULL,NULL,NULL,NULL,NULL),(43,'202606011628034600',1,2,1,3200.00,'completed',NULL,'2026-06-01 08:28:03','2026-06-01 16:28:11','2026-06-01 16:28:49',NULL,NULL,NULL,NULL,NULL),(44,'202606261703136070',57,1,3,55.00,'paid',NULL,'2026-06-26 09:03:13','2026-06-26 17:03:21',NULL,NULL,NULL,NULL,NULL,NULL),(47,'202606261728152563',36,2,1,11414.00,'cancelled','????','2026-06-26 09:28:15',NULL,NULL,'2026-06-26 17:38:17',NULL,NULL,NULL,NULL),(48,'202606261729105800',58,2,1,30.00,'shipped','????','2026-06-26 09:29:10','2026-06-26 17:29:11',NULL,NULL,NULL,NULL,NULL,'2026-06-27 16:41:57'),(59,'202606261737433463',59,2,3,68.00,'paid','????','2026-06-26 09:37:43','2026-06-26 17:37:43',NULL,NULL,NULL,NULL,NULL,NULL),(71,'202606271514070620',15,27,2,34.00,'cancelled',NULL,'2026-06-27 07:14:07',NULL,NULL,'2026-06-27 15:35:22',NULL,NULL,NULL,NULL);
/*!40000 ALTER TABLE `orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `payments`
--

DROP TABLE IF EXISTS `payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `payments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `order_id` int(10) unsigned NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `method` enum('balance') NOT NULL DEFAULT 'balance' COMMENT '支付方式',
  `status` enum('success','failed','refunded') NOT NULL DEFAULT 'success',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order` (`order_id`),
  CONSTRAINT `fk_payment_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=49 DEFAULT CHARSET=utf8mb4 COMMENT='支付流水';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `payments`
--

LOCK TABLES `payments` WRITE;
/*!40000 ALTER TABLE `payments` DISABLE KEYS */;
INSERT INTO `payments` VALUES (3,3,45.00,'balance','success','2026-05-30 06:38:06'),(4,4,3200.00,'balance','success','2026-05-30 06:38:49'),(15,21,350.00,'balance','success','2026-05-30 14:19:41'),(24,32,180.00,'balance','success','2026-06-01 08:25:38'),(33,43,3200.00,'balance','success','2026-06-01 08:28:11'),(34,44,55.00,'balance','success','2026-06-26 09:03:21'),(37,48,30.00,'balance','success','2026-06-26 09:29:11'),(48,59,68.00,'balance','success','2026-06-26 09:37:43');
/*!40000 ALTER TABLE `payments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `product_images`
--

DROP TABLE IF EXISTS `product_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `product_images` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `product_id` int(10) unsigned NOT NULL,
  `image_url` varchar(500) NOT NULL,
  `is_cover` tinyint(1) NOT NULL DEFAULT '0',
  `sort_no` int(10) unsigned NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_product_images_product` (`product_id`,`sort_no`,`id`),
  CONSTRAINT `fk_product_images_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=99 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `product_images`
--

LOCK TABLES `product_images` WRITE;
/*!40000 ALTER TABLE `product_images` DISABLE KEYS */;
INSERT INTO `product_images` VALUES (1,1,'/static/product_images/iphone13-blue.jpg',1,0,'2026-05-30 13:20:21'),(3,3,'/static/product_images/mouse.jpg',1,0,'2026-05-30 13:20:21'),(4,4,'/static/product_images/folding-bike.jpg',1,0,'2026-05-30 13:20:21'),(5,5,'/static/product_images/white-sneakers.jpg',1,0,'2026-05-30 13:20:21'),(6,6,'/static/product_images/desk-lamp.jpg',1,0,'2026-05-30 13:20:21'),(7,12,'/static/product_images/dorm-desk.jpg',1,0,'2026-05-30 13:20:21'),(8,13,'/static/uploads/fd53f6e4389940b192e79d775072c678.png',1,0,'2026-05-30 13:20:21'),(9,13,'/static/uploads/f08fbf79486a4c04887b4ca57855a73d.png',0,1,'2026-05-30 13:20:21'),(10,13,'/static/uploads/b78dd2f18eb34593ab784d4206f2b95c.png',0,2,'2026-05-30 13:20:21'),(11,13,'/static/uploads/8d965b9c168148b38a9aa926d9353dba.png',0,3,'2026-05-30 13:20:21'),(12,15,'/static/uploads/4909bc32c8cd43c39ca6244f298e4552.png',1,0,'2026-05-30 13:20:21'),(13,15,'/static/uploads/e6a3e31499244102b6f783f326fa1769.png',0,1,'2026-05-30 13:20:21'),(14,15,'/static/uploads/424239a98b704fa0ad184a2a95ff3d08.png',0,2,'2026-05-30 13:20:21'),(15,15,'/static/uploads/d6f07b59ccd548b0a1ad0f1e3221faf4.png',0,3,'2026-05-30 13:20:21'),(24,36,'/static/uploads/27e61c2f5a3f4bb88e81c34870994886.png',1,0,'2026-05-30 14:19:10'),(25,36,'/static/uploads/f3a2a6a108e143839e74a16752a1a7fa.png',0,1,'2026-05-30 14:19:10'),(26,36,'/static/uploads/7fe99d560d3542f69c04847e1de9016c.png',0,2,'2026-05-30 14:19:10'),(27,36,'/static/uploads/46e6d5ffd28a4d94a295e8fc27348f76.png',0,3,'2026-05-30 14:19:10'),(46,55,'/static/product_images/wireless-headphones.jpg',1,0,'2026-05-31 08:34:24'),(47,56,'/static/product_images/mechanical-keyboard.jpg',1,0,'2026-05-31 08:34:24'),(48,57,'/static/product_images/dorm-kettle.jpg',1,0,'2026-05-31 08:34:24'),(49,58,'/static/product_images/cet6-books.jpg',1,0,'2026-05-31 08:34:24'),(50,59,'/static/product_images/navy-backpack.jpg',1,0,'2026-05-31 08:34:24'),(51,60,'/static/product_images/xianyu_seed/laptop_1.webp?v=imgfix20260628',1,0,'2026-06-28 03:05:36'),(52,60,'/static/product_images/xianyu_seed/laptop_2.webp?v=imgfix20260628',0,1,'2026-06-28 03:05:36'),(53,60,'/static/product_images/xianyu_seed/laptop_3.webp?v=imgfix20260628',0,2,'2026-06-28 03:05:36'),(54,60,'/static/product_images/xianyu_seed/laptop_4.webp?v=imgfix20260628',0,3,'2026-06-28 03:05:36'),(55,61,'/static/product_images/xianyu_seed/book_1.webp?v=imgfix20260628',1,0,'2026-06-28 03:05:36'),(56,61,'/static/product_images/xianyu_seed/book_2.webp?v=imgfix20260628',0,1,'2026-06-28 03:05:36'),(57,61,'/static/product_images/xianyu_seed/book_3.webp?v=imgfix20260628',0,2,'2026-06-28 03:05:36'),(58,61,'/static/product_images/xianyu_seed/book_4.webp?v=imgfix20260628',0,3,'2026-06-28 03:05:36'),(59,62,'/static/product_images/xianyu_seed/lamp_1.webp?v=imgfix20260628',1,0,'2026-06-28 03:05:36'),(60,62,'/static/product_images/xianyu_seed/lamp_2.webp?v=imgfix20260628',0,1,'2026-06-28 03:05:36'),(61,62,'/static/product_images/xianyu_seed/lamp_3.webp?v=imgfix20260628',0,2,'2026-06-28 03:05:36'),(62,62,'/static/product_images/xianyu_seed/lamp_4.webp?v=imgfix20260628',0,3,'2026-06-28 03:05:36'),(63,63,'/static/product_images/xianyu_seed/mouse_1.webp?v=imgfix20260628',1,0,'2026-06-28 03:05:36'),(64,63,'/static/product_images/xianyu_seed/mouse_2.webp?v=imgfix20260628',0,1,'2026-06-28 03:05:36'),(65,63,'/static/product_images/xianyu_seed/mouse_3.webp?v=imgfix20260628',0,2,'2026-06-28 03:05:36'),(66,63,'/static/product_images/xianyu_seed/mouse_4.webp?v=imgfix20260628',0,3,'2026-06-28 03:05:36'),(67,64,'/static/product_images/xianyu_seed/bike_1.webp?v=imgfix20260628',1,0,'2026-06-28 03:05:36'),(68,64,'/static/product_images/xianyu_seed/bike_2.webp?v=imgfix20260628',0,1,'2026-06-28 03:05:36'),(69,64,'/static/product_images/xianyu_seed/bike_3.webp?v=imgfix20260628',0,2,'2026-06-28 03:05:36'),(70,64,'/static/product_images/xianyu_seed/bike_4.webp?v=imgfix20260628',0,3,'2026-06-28 03:05:36'),(71,65,'/static/product_images/xianyu_seed/shoes_1.webp?v=imgfix20260628',1,0,'2026-06-28 03:05:36'),(72,65,'/static/product_images/xianyu_seed/shoes_2.webp?v=imgfix20260628',0,1,'2026-06-28 03:05:36'),(73,65,'/static/product_images/xianyu_seed/shoes_3.webp?v=imgfix20260628',0,2,'2026-06-28 03:05:36'),(74,65,'/static/product_images/xianyu_seed/shoes_4.webp?v=imgfix20260628',0,3,'2026-06-28 03:05:36'),(75,66,'/static/product_images/xianyu_seed/kettle_1.webp?v=imgfix20260628',1,0,'2026-06-28 03:05:36'),(76,66,'/static/product_images/xianyu_seed/kettle_2.webp?v=imgfix20260628',0,1,'2026-06-28 03:05:36'),(77,66,'/static/product_images/xianyu_seed/kettle_3.webp?v=imgfix20260628',0,2,'2026-06-28 03:05:36'),(78,66,'/static/product_images/xianyu_seed/kettle_4.webp?v=imgfix20260628',0,3,'2026-06-28 03:05:36'),(79,67,'/static/product_images/xianyu_seed/keyboard_1.webp?v=imgfix20260628',1,0,'2026-06-28 03:05:36'),(80,67,'/static/product_images/xianyu_seed/keyboard_2.webp?v=imgfix20260628',0,1,'2026-06-28 03:05:36'),(81,67,'/static/product_images/xianyu_seed/keyboard_3.webp?v=imgfix20260628',0,2,'2026-06-28 03:05:36'),(82,67,'/static/product_images/xianyu_seed/keyboard_4.webp?v=imgfix20260628',0,3,'2026-06-28 03:05:36'),(83,68,'/static/product_images/xianyu_seed_more/backpack_1.webp?v=more20260628',1,0,'2026-06-28 03:32:48'),(84,68,'/static/product_images/xianyu_seed_more/backpack_2.webp?v=more20260628',0,1,'2026-06-28 03:32:48'),(85,68,'/static/product_images/xianyu_seed_more/backpack_3.webp?v=more20260628',0,2,'2026-06-28 03:32:48'),(86,68,'/static/product_images/xianyu_seed_more/backpack_4.webp?v=more20260628',0,3,'2026-06-28 03:32:48'),(87,69,'/static/product_images/xianyu_seed_more/desk_1.webp?v=more20260628',1,0,'2026-06-28 03:32:48'),(88,69,'/static/product_images/xianyu_seed_more/desk_2.webp?v=more20260628',0,1,'2026-06-28 03:32:48'),(89,69,'/static/product_images/xianyu_seed_more/desk_3.webp?v=more20260628',0,2,'2026-06-28 03:32:48'),(90,69,'/static/product_images/xianyu_seed_more/desk_4.webp?v=more20260628',0,3,'2026-06-28 03:32:48'),(91,70,'/static/product_images/xianyu_seed_more/powerbank_1.webp?v=more20260628',1,0,'2026-06-28 03:32:48'),(92,70,'/static/product_images/xianyu_seed_more/powerbank_2.webp?v=more20260628',0,1,'2026-06-28 03:32:48'),(93,70,'/static/product_images/xianyu_seed_more/powerbank_3.webp?v=more20260628',0,2,'2026-06-28 03:32:48'),(94,70,'/static/product_images/xianyu_seed_more/powerbank_4.webp?v=more20260628',0,3,'2026-06-28 03:32:48'),(95,71,'/static/product_images/xianyu_seed_more/calculator_1.webp?v=more20260628',1,0,'2026-06-28 03:32:48'),(96,71,'/static/product_images/xianyu_seed_more/calculator_2.webp?v=more20260628',0,1,'2026-06-28 03:32:48'),(97,71,'/static/product_images/xianyu_seed_more/calculator_3.webp?v=more20260628',0,2,'2026-06-28 03:32:48'),(98,71,'/static/product_images/xianyu_seed_more/calculator_4.webp?v=more20260628',0,3,'2026-06-28 03:32:48');
/*!40000 ALTER TABLE `product_images` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `product_reports`
--

DROP TABLE IF EXISTS `product_reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `product_reports` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `product_id` int(10) unsigned NOT NULL,
  `reporter_id` int(10) unsigned NOT NULL,
  `reason` varchar(255) NOT NULL,
  `status` enum('pending','resolved','rejected') NOT NULL DEFAULT 'pending',
  `admin_id` int(10) unsigned DEFAULT NULL,
  `admin_note` varchar(255) DEFAULT NULL,
  `handled_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_product_reports_status` (`status`,`created_at`),
  KEY `idx_product_reports_product` (`product_id`),
  KEY `fk_product_report_reporter` (`reporter_id`),
  KEY `fk_product_report_admin` (`admin_id`),
  CONSTRAINT `fk_product_report_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_product_report_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_product_report_reporter` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `product_reports`
--

LOCK TABLES `product_reports` WRITE;
/*!40000 ALTER TABLE `product_reports` DISABLE KEYS */;
INSERT INTO `product_reports` VALUES (1,3,1,'演示验收：商品描述可能不实','resolved',8,'演示验收：举报成立，下架核实','2026-06-26 11:11:14','2026-06-26 03:11:14'),(2,12,1,'太假了','rejected',8,'不符合','2026-06-26 16:34:03','2026-06-26 08:33:26'),(3,57,8,'111111111','rejected',8,NULL,'2026-06-27 22:03:23','2026-06-26 16:06:45'),(4,4,1,'??????','rejected',8,NULL,'2026-06-27 22:03:22','2026-06-26 16:09:08'),(5,4,1,'??????','rejected',8,NULL,'2026-06-27 22:03:20','2026-06-26 16:09:27'),(6,4,1,'??????','rejected',8,NULL,'2026-06-27 22:03:18','2026-06-26 16:09:59'),(7,4,8,'测试举报弹窗展示','rejected',8,NULL,'2026-06-27 20:21:54','2026-06-26 16:12:47'),(8,4,8,'11111','rejected',8,NULL,'2026-06-27 20:21:52','2026-06-26 16:14:27'),(9,4,1,'????????','rejected',8,NULL,'2026-06-27 20:21:50','2026-06-26 16:16:31'),(10,4,1,'????????2','rejected',8,NULL,'2026-06-27 20:21:49','2026-06-26 16:18:11'),(12,57,1,'德怀特还挺好的天','rejected',8,'说的啥啊','2026-06-27 22:04:36','2026-06-27 14:04:12');
/*!40000 ALTER TABLE `product_reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `products`
--

DROP TABLE IF EXISTS `products`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `products` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seller_id` int(10) unsigned NOT NULL COMMENT '卖家',
  `category_id` int(10) unsigned DEFAULT NULL COMMENT '分类',
  `title` varchar(100) NOT NULL COMMENT '标题',
  `description` text COMMENT '描述',
  `price` decimal(10,2) NOT NULL COMMENT '售价',
  `condition_level` varchar(20) NOT NULL DEFAULT '9成新' COMMENT '新旧程度',
  `image_url` text,
  `status` enum('on_sale','locked','sold','removed') NOT NULL DEFAULT 'on_sale',
  `view_count` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '浏览量',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `removal_reason` varchar(255) DEFAULT NULL COMMENT '下架原因',
  `removed_by` int(10) unsigned DEFAULT NULL COMMENT '下架操作人',
  `removed_at` datetime DEFAULT NULL COMMENT '下架时间',
  PRIMARY KEY (`id`),
  KEY `idx_seller` (`seller_id`),
  KEY `idx_category` (`category_id`),
  KEY `idx_status` (`status`),
  CONSTRAINT `fk_product_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`),
  CONSTRAINT `fk_product_seller` FOREIGN KEY (`seller_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=72 DEFAULT CHARSET=utf8mb4 COMMENT='商品';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `products`
--

LOCK TABLES `products` WRITE;
/*!40000 ALTER TABLE `products` DISABLE KEYS */;
INSERT INTO `products` VALUES (1,1,1,'iPhone 13 128G 蓝色','国行正品，电池健康 89%，无磕碰，配原装充电线。',3200.00,'95新','/static/product_images/iphone13-blue.jpg','sold',31,'2026-05-30 06:18:01',NULL,NULL,NULL),(3,2,1,'罗技 MX Master 3 鼠标','办公神器，手感极佳，含 USB 接收器。',320.00,'95新','/static/product_images/mouse.jpg','removed',7,'2026-05-30 06:18:01','演示验收：举报成立，下架核实',8,'2026-06-26 11:11:14'),(4,2,4,'迪卡侬 折叠自行车','通勤代步，已骑半年，刹车变速正常。',480.00,'8成新','/static/product_images/folding-bike.jpg','on_sale',18,'2026-05-30 06:18:01',NULL,NULL,NULL),(5,3,3,'Nike Air Force 1 白色 42码','正品，穿过两次，鞋盒齐全。',350.00,'99新','/static/product_images/white-sneakers.jpg','on_sale',30,'2026-05-30 06:18:01',NULL,NULL,NULL),(6,3,5,'宜家台灯 暖光','护眼台灯，三档亮度，搬家出。',45.00,'9成新','/static/product_images/desk-lamp.jpg','sold',1,'2026-05-30 06:18:01',NULL,NULL,NULL),(12,2,7,'宿舍折叠小桌板','适合床上看书和放电脑，桌腿稳，桌面有轻微使用痕迹。西区宿舍楼下可自提。',28.00,'9成新','/static/product_images/dorm-desk.jpg','on_sale',23,'2026-05-30 09:03:52',NULL,NULL,NULL),(13,2,7,'分隔符','法国撒',23.00,'9成新','/static/uploads/fd53f6e4389940b192e79d775072c678.png|/static/uploads/f08fbf79486a4c04887b4ca57855a73d.png|/static/uploads/b78dd2f18eb34593ab784d4206f2b95c.png|/static/uploads/8d965b9c168148b38a9aa926d9353dba.png','on_sale',16,'2026-05-30 10:17:49',NULL,NULL,NULL),(15,2,1,'古典风格','南方国家',34.00,'95新','/static/uploads/4909bc32c8cd43c39ca6244f298e4552.png|/static/uploads/e6a3e31499244102b6f783f326fa1769.png|/static/uploads/424239a98b704fa0ad184a2a95ff3d08.png|/static/uploads/d6f07b59ccd548b0a1ad0f1e3221faf4.png','on_sale',21,'2026-05-30 10:42:34',NULL,NULL,NULL),(36,1,1,'儿童健康乐观和肉体哦·','',11414.00,'95新','/static/uploads/27e61c2f5a3f4bb88e81c34870994886.png|/static/uploads/f3a2a6a108e143839e74a16752a1a7fa.png|/static/uploads/7fe99d560d3542f69c04847e1de9016c.png|/static/uploads/46e6d5ffd28a4d94a295e8fc27348f76.png','on_sale',4,'2026-05-30 14:19:10',NULL,NULL,NULL),(55,1,1,'头戴式无线降噪耳机','银色头戴式耳机，降噪和蓝牙连接正常，适合自习室和通勤使用。',180.00,'9成新','/static/product_images/wireless-headphones.jpg','sold',4,'2026-05-31 08:34:24',NULL,NULL,NULL),(56,2,1,'87键机械键盘 茶轴','黑色小配列键盘，键帽无明显打油，适合宿舍桌面和编程作业。',120.00,'9成新','/static/product_images/mechanical-keyboard.jpg','on_sale',6,'2026-05-31 08:34:24',NULL,NULL,NULL),(57,3,5,'宿舍小容量电热水壶','1L 左右容量，烧水正常，壶身干净，搬宿舍闲置出。',55.00,'8成新','/static/product_images/dorm-kettle.jpg','locked',18,'2026-05-31 08:34:24',NULL,NULL,NULL),(58,1,2,'大学英语六级真题资料','近几年真题加词汇资料，附便签标注，备考六级够用。',30.00,'9成新','/static/product_images/cet6-books.jpg','locked',26,'2026-05-31 08:34:24',NULL,NULL,NULL),(59,3,3,'深蓝色上课双肩包','容量够放电脑和教材，肩带完好，外观干净，适合日常上课。',68.00,'9成新','/static/product_images/navy-backpack.jpg','locked',1,'2026-05-31 08:34:24',NULL,NULL,NULL),(60,1,1,'得峰 14 寸笔记本电脑','14 寸得峰笔记本，卖家描述接近全新，无拆修。适合日常办公、网课和轻量学习使用，带基础配件。',380.00,'几乎全新','/static/product_images/xianyu_seed/laptop_1.webp?v=imgfix20260628|/static/product_images/xianyu_seed/laptop_2.webp?v=imgfix20260628|/static/product_images/xianyu_seed/laptop_3.webp?v=imgfix20260628|/static/product_images/xianyu_seed/laptop_4.webp?v=imgfix20260628','on_sale',1,'2026-06-28 03:05:36',NULL,NULL,NULL),(61,1,2,'数据库系统原理微课版二手教材','人民邮电出版社《数据库系统原理（微课版）》二手教材，林子雨编著。适合数据库课程学习，书况约 85-95 新，可能有少量笔记。',16.56,'9成新','/static/product_images/xianyu_seed/book_1.webp?v=imgfix20260628|/static/product_images/xianyu_seed/book_2.webp?v=imgfix20260628|/static/product_images/xianyu_seed/book_3.webp?v=imgfix20260628|/static/product_images/xianyu_seed/book_4.webp?v=imgfix20260628','on_sale',3,'2026-06-28 03:05:36',NULL,NULL,NULL),(62,2,5,'美式长臂夹子台灯','长臂夹子台灯，USB 供电，三档色温、十级亮度调节。灯臂可调节，适合宿舍书桌、床边阅读和自习使用。',17.00,'全新','/static/product_images/xianyu_seed/lamp_1.webp?v=imgfix20260628|/static/product_images/xianyu_seed/lamp_2.webp?v=imgfix20260628|/static/product_images/xianyu_seed/lamp_3.webp?v=imgfix20260628|/static/product_images/xianyu_seed/lamp_4.webp?v=imgfix20260628','on_sale',0,'2026-06-28 03:05:36',NULL,NULL,NULL),(63,2,1,'无线蓝牙鼠标','无线蓝牙鼠标，支持笔记本和平板日常办公使用。静音按键，轻便小巧，适合宿舍、图书馆和课堂携带。',14.90,'全新','/static/product_images/xianyu_seed/mouse_1.webp?v=imgfix20260628|/static/product_images/xianyu_seed/mouse_2.webp?v=imgfix20260628|/static/product_images/xianyu_seed/mouse_3.webp?v=imgfix20260628|/static/product_images/xianyu_seed/mouse_4.webp?v=imgfix20260628','on_sale',1,'2026-06-28 03:05:36',NULL,NULL,NULL),(64,3,4,'BATTLE 26 寸山地自行车','26 寸 BATTLE 山地车，21 速，铝合金车架，带后货架。刹车正常，适合校园通勤、买菜和短途代步。',100.00,'轻微使用痕迹','/static/product_images/xianyu_seed/bike_1.webp?v=imgfix20260628|/static/product_images/xianyu_seed/bike_2.webp?v=imgfix20260628|/static/product_images/xianyu_seed/bike_3.webp?v=imgfix20260628|/static/product_images/xianyu_seed/bike_4.webp?v=imgfix20260628','on_sale',0,'2026-06-28 03:05:36',NULL,NULL,NULL),(65,3,3,'黑色网面运动鞋 41 码','黑色网面运动鞋，41 码，鞋面透气，适合日常运动、散步和校园通勤。鞋底有正常使用痕迹。',20.00,'轻微穿着痕迹','/static/product_images/xianyu_seed/shoes_1.webp?v=imgfix20260628|/static/product_images/xianyu_seed/shoes_2.webp?v=imgfix20260628|/static/product_images/xianyu_seed/shoes_3.webp?v=imgfix20260628|/static/product_images/xianyu_seed/shoes_4.webp?v=imgfix20260628','on_sale',0,'2026-06-28 03:05:36',NULL,NULL,NULL),(66,27,5,'米家电水壶 N1','米家电水壶 N1，1.5L 容量，1500W 功率，304 不锈钢内胆。适合宿舍、办公室和日常烧水使用。',50.00,'全新','/static/product_images/xianyu_seed/kettle_1.webp?v=imgfix20260628|/static/product_images/xianyu_seed/kettle_2.webp?v=imgfix20260628|/static/product_images/xianyu_seed/kettle_3.webp?v=imgfix20260628|/static/product_images/xianyu_seed/kettle_4.webp?v=imgfix20260628','on_sale',2,'2026-06-28 03:05:36',NULL,NULL,NULL),(67,27,1,'有线机械手感键盘','有线机械手感键盘，USB 接口，带背光，适合台式机和笔记本外接使用。适合宿舍学习、办公和轻度游戏。',27.00,'全新','/static/product_images/xianyu_seed/keyboard_1.webp?v=imgfix20260628|/static/product_images/xianyu_seed/keyboard_2.webp?v=imgfix20260628|/static/product_images/xianyu_seed/keyboard_3.webp?v=imgfix20260628|/static/product_images/xianyu_seed/keyboard_4.webp?v=imgfix20260628','on_sale',0,'2026-06-28 03:05:36',NULL,NULL,NULL),(68,1,3,'江利达浅绿色双肩包','江利达 JLD 浅绿色双肩包，OUR YOUTH 字母款。包身容量适中，日常可以放教材、笔记本、雨伞和水杯，适合上课、图书馆自习或短途通勤使用。肩带比较宽，背负感不勒肩，外观保存较好，适合想买一个轻便书包的同学。',19.00,'几乎全新','/static/product_images/xianyu_seed_more/backpack_1.webp?v=more20260628|/static/product_images/xianyu_seed_more/backpack_2.webp?v=more20260628|/static/product_images/xianyu_seed_more/backpack_3.webp?v=more20260628|/static/product_images/xianyu_seed_more/backpack_4.webp?v=more20260628','on_sale',3,'2026-06-28 03:32:48',NULL,NULL,NULL),(69,2,5,'宿舍可折叠床上小桌板','宿舍床上用可折叠小桌板，桌面约 60cm x 40cm，高约 28cm。桌腿可以折叠收纳，桌面带卡槽和防滑挡条，可以放平板、书本或轻薄笔记本电脑。适合床上看网课、临时办公、整理资料，也适合宿舍空间比较紧的场景。',28.60,'全新','/static/product_images/xianyu_seed_more/desk_1.webp?v=more20260628|/static/product_images/xianyu_seed_more/desk_2.webp?v=more20260628|/static/product_images/xianyu_seed_more/desk_3.webp?v=more20260628|/static/product_images/xianyu_seed_more/desk_4.webp?v=more20260628','on_sale',2,'2026-06-28 03:32:48',NULL,NULL,NULL),(70,3,1,'美团 22.5W 快充充电宝','美团共享款三线充电宝，容量约 7500mAh，支持 22.5W 快充。机身自带常用充电线，带 Type-C 充电口，可以反复充电使用。适合上课、图书馆自习、短途出门时给手机临时补电，页面标注带 3C 认证，可作为随身备用电源。',25.00,'95新','/static/product_images/xianyu_seed_more/powerbank_1.webp?v=more20260628|/static/product_images/xianyu_seed_more/powerbank_2.webp?v=more20260628|/static/product_images/xianyu_seed_more/powerbank_3.webp?v=more20260628|/static/product_images/xianyu_seed_more/powerbank_4.webp?v=more20260628','on_sale',1,'2026-06-28 03:32:48',NULL,NULL,NULL),(71,27,7,'DEXIN BST 科学函数计算器','DEXIN BST DC-1800N 科学函数计算器，浅蓝色外壳，带保护壳。支持三角函数、统计、排列组合、指数对数、双曲函数等常用计算，按键清晰，屏幕显示正常。适合高数、统计、工程计算和日常考试备考使用，价格低，作为备用计算器也合适。',4.90,'几乎全新','/static/product_images/xianyu_seed_more/calculator_1.webp?v=more20260628|/static/product_images/xianyu_seed_more/calculator_2.webp?v=more20260628|/static/product_images/xianyu_seed_more/calculator_3.webp?v=more20260628|/static/product_images/xianyu_seed_more/calculator_4.webp?v=more20260628','on_sale',1,'2026-06-28 03:32:48',NULL,NULL,NULL);
/*!40000 ALTER TABLE `products` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reviews`
--

DROP TABLE IF EXISTS `reviews`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `reviews` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `order_id` int(10) unsigned NOT NULL,
  `reviewer_id` int(10) unsigned NOT NULL,
  `target_user_id` int(10) unsigned NOT NULL,
  `rating` tinyint(3) unsigned NOT NULL,
  `content` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_reviews_order_reviewer` (`order_id`,`reviewer_id`),
  KEY `idx_reviews_target` (`target_user_id`,`created_at`),
  KEY `fk_review_reviewer` (`reviewer_id`),
  CONSTRAINT `fk_review_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_review_reviewer` FOREIGN KEY (`reviewer_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_review_target` FOREIGN KEY (`target_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reviews`
--

LOCK TABLES `reviews` WRITE;
/*!40000 ALTER TABLE `reviews` DISABLE KEYS */;
INSERT INTO `reviews` VALUES (3,3,1,3,5,'还行','2026-05-30 13:53:53'),(8,32,2,1,5,'可以','2026-06-01 08:27:02');
/*!40000 ALTER TABLE `reviews` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL COMMENT '登录账号',
  `password_hash` varchar(255) NOT NULL COMMENT '加密后的密码',
  `nickname` varchar(50) NOT NULL COMMENT '昵称',
  `phone` varchar(20) DEFAULT NULL COMMENT '联系电话',
  `balance` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '钱包余额',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_active` tinyint(1) NOT NULL DEFAULT '1' COMMENT '账号是否启用',
  `payment_password_hash` varchar(255) DEFAULT NULL COMMENT '支付密码哈希',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb4 COMMENT='用户';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'alice','scrypt:32768:8:1$jnTvIF3Mb5XnHa2W$ee941785cb6cb9342a16f2364882ec7bd4cb78279afe469b30f24a4d0fb3a73124a1d51b8078fa4406ffbb5f9382f18c991be4c1027a5cbde4cd8013dde2ee3a','爱丽丝','13800000001',8392.00,'2026-05-30 06:18:01',1,'scrypt:32768:8:1$LgrR3QQyV8n6gXvQ$bd6117a74a4c6cece99c10dff582619082c14cc31ca0f53468ddf94fb30f885272e1a677099cba6ad165c0a1624c2afeb9d7d46750d6e38700e9be8d81ba6b87'),(2,'bob','scrypt:32768:8:1$14zwRWSNnYwcbnqx$fa46e10c0e1d5e7c91e06b14e9a628311b5ac6c6be60eca7740736410e1ccd8638903f71a0f64ad033f1e8c6c0411ef17d46525fc6e675ac61f2d050095d7bf5','小波','13800000002',1522.00,'2026-05-30 06:18:01',1,'scrypt:32768:8:1$lTaRZf3yB46mkBGt$ab4334335a47ff7c818fc37708f052ccd5f559d7cfe45645f414c2bf3b95e43884c6630b028b5bfc33b87ae6d976436e0642cde66d70970c6f303ef4c535936a'),(3,'carol','scrypt:32768:8:1$OU6DSk2mqYebVEZe$54addbcc711fde091a44edba270393c8b9d9cf4b628405dbc95b680de2049d11046dc6f533f533789fc81e96b0107e6d0f359ec61984aa5f6ed2833df4d1d39d','卡罗尔','13800000003',5045.00,'2026-05-30 06:18:01',1,'scrypt:32768:8:1$zxkVz3nEmtElcvJT$480458e6b64ef8c21392c790523bf1b28de53aedf7967b8d3db14792bb62ef0f653a164f8737acc134538508194e84ecbf5c4af550bfd2e9ea04b6a8f035b276'),(8,'admin','scrypt:32768:8:1$48UcWPjlVs96UllE$e7549f6b2503402a73af614148b64819c3dfd6008723bc5777ad315cba3578af591d63263532bd0b281ddeafbf770fd2a3f78f8491e531a6c3c8385784a1440d','xixi',NULL,1000000.00,'2026-05-30 08:41:51',1,'scrypt:32768:8:1$Ve0oVHTyaMnIBv6G$0de3cbba2e20122c0529148958e41dee13331a4d362453eb878d093fa311bc140faa0150530ffb86f41f5b5eb6003a37e5ffe9e2b093fa85c3fc5513af1dc4d2'),(27,'jiji','scrypt:32768:8:1$yBF6ZMZja70jPPc8$704f0fef14a6809401f1c995ce42c24f56b31ef64472d93f40f63cbb01819997369b208ef378014afed28d8fceb680126e607c4f507b69363bfc6bf17a39885b','jiji','19848268065',100.00,'2026-06-27 07:12:58',1,'scrypt:32768:8:1$Uk8bYzj8uinwtZmt$dfd8ad114ac81577179ed9692b2513bbaaa00b39ee86c2b2d0cbf78de9d44ed7924f698e49af365c448ace544b8e80d03e9ba4e45911a437d904656200bee6e9');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'secondhand'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-06-28 11:46:17
