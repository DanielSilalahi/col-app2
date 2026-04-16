-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               8.0.30 - MySQL Community Server - GPL
-- Server OS:                    Win64
-- HeidiSQL Version:             12.1.0.6537
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for collection_db
CREATE DATABASE IF NOT EXISTS `collection_db` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `collection_db`;

-- Dumping structure for table collection_db.activity_logs
CREATE TABLE IF NOT EXISTS `activity_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `detail` text COLLATE utf8mb4_unicode_ci,
  `ip_address` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `timestamp` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_activity_logs_action` (`action`),
  KEY `ix_activity_logs_user_id` (`user_id`),
  KEY `ix_activity_logs_timestamp` (`timestamp`),
  CONSTRAINT `activity_logs_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table collection_db.activity_logs: ~11 rows (approximately)
INSERT INTO `activity_logs` (`id`, `user_id`, `action`, `detail`, `ip_address`, `timestamp`) VALUES
	(1, 1, 'login', 'Login via mobile app', '127.0.0.1', '2026-04-10 15:30:23'),
	(2, 1, 'login', 'Login via dashboard', '127.0.0.1', '2026-04-10 15:51:47'),
	(3, 2, 'login', 'Login via mobile app', '127.0.0.1', '2026-04-10 16:27:58'),
	(4, 1, 'upload_customer', 'Upload 10 customers (batch: UPLOAD_20260410_163031)', NULL, '2026-04-10 16:30:31'),
	(5, 2, 'login', 'Login via mobile app', '127.0.0.1', '2026-04-10 16:31:58'),
	(6, 2, 'request_va', 'VA request untuk customer #1 (Budi Santoso)', NULL, '2026-04-10 16:32:08'),
	(7, 1, 'create_va', 'VA #1234567890 (BRI) untuk request #1', NULL, '2026-04-10 16:32:32'),
	(8, 2, 'collection_update', 'Customer #7 (Agus Wijaya): bayar', NULL, '2026-04-10 16:33:19'),
	(9, 2, 'collection_update', 'Customer #3 (Ahmad Ridwan): tidak_ketemu', NULL, '2026-04-10 16:43:15'),
	(10, 2, 'request_va', 'VA request untuk customer #4 (Dewi Lestari)', NULL, '2026-04-10 16:47:50'),
	(11, 1, 'create_va', 'VA #123456754321 (BRI) untuk request #2', NULL, '2026-04-10 16:48:14');

-- Dumping structure for table collection_db.collections
CREATE TABLE IF NOT EXISTS `collections` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `agent_id` int NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `photo_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gps_lat` float DEFAULT NULL,
  `gps_lng` float DEFAULT NULL,
  `timestamp` datetime NOT NULL,
  `synced_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_collections_status` (`status`),
  KEY `ix_collections_customer_id` (`customer_id`),
  KEY `ix_collections_agent_id` (`agent_id`),
  CONSTRAINT `collections_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`),
  CONSTRAINT `collections_ibfk_2` FOREIGN KEY (`agent_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table collection_db.collections: ~2 rows (approximately)
INSERT INTO `collections` (`id`, `customer_id`, `agent_id`, `status`, `notes`, `photo_url`, `gps_lat`, `gps_lng`, `timestamp`, `synced_at`, `created_at`) VALUES
	(1, 7, 2, 'bayar', 'Masok', NULL, NULL, NULL, '2026-04-10 09:33:18', NULL, '2026-04-10 16:33:19'),
	(2, 3, 2, 'tidak_ketemu', NULL, NULL, NULL, NULL, '2026-04-10 09:43:15', NULL, '2026-04-10 16:43:15');

-- Dumping structure for table collection_db.customers
CREATE TABLE IF NOT EXISTS `customers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `address` text COLLATE utf8mb4_unicode_ci,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lat` float DEFAULT NULL,
  `lng` float DEFAULT NULL,
  `assigned_agent_id` int DEFAULT NULL,
  `upload_batch` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_customers_upload_batch` (`upload_batch`),
  KEY `ix_customers_assigned_agent_id` (`assigned_agent_id`),
  KEY `ix_customers_status` (`status`),
  KEY `ix_customers_name` (`name`),
  CONSTRAINT `customers_ibfk_1` FOREIGN KEY (`assigned_agent_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table collection_db.customers: ~10 rows (approximately)
INSERT INTO `customers` (`id`, `name`, `address`, `phone`, `lat`, `lng`, `assigned_agent_id`, `upload_batch`, `status`, `notes`, `created_at`) VALUES
	(1, 'Budi Santoso', 'Jl. Merdeka No. 10, Jakarta Selatan', '081234567890', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'belum', NULL, '2026-04-10 16:30:31'),
	(2, 'Siti Aminah', 'Jl. Sudirman Blok A1, Bandung', '085678901234', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'belum', NULL, '2026-04-10 16:30:31'),
	(3, 'Ahmad Ridwan', 'Perumahan Griya Indah, Semarang', '08981234567', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'tidak_ketemu', NULL, '2026-04-10 16:30:31'),
	(4, 'Dewi Lestari', 'Jl. Diponegoro No. 45, Surabaya', '081122334455', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'belum', NULL, '2026-04-10 16:30:31'),
	(5, 'Rizky Pratama', 'Jl. Pahlawan No. 8, Medan', '082233445566', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'belum', NULL, '2026-04-10 16:30:31'),
	(6, 'Maya Sari', 'Apartemen Sudirman Park Tower B', '081345678912', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'belum', NULL, '2026-04-10 16:30:31'),
	(7, 'Agus Wijaya', 'Jl. Gajah Mada No. 12, Denpasar', '085755667788', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'bayar', 'Masok', '2026-04-10 16:30:31'),
	(8, 'Nurul Huda', 'Komp. Polri No. 99, Makassar', '081988776655', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'belum', NULL, '2026-04-10 16:30:31'),
	(9, 'Hendra Gunawan', 'Jl. Veteran No. 3, Palembang', '082199887766', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'belum', NULL, '2026-04-10 16:30:31'),
	(10, 'Rina Wati', 'Perum Bukit Asri Blok D4, Malang', '087811223344', NULL, NULL, 2, 'UPLOAD_20260410_163031', 'belum', NULL, '2026-04-10 16:30:31');

-- Dumping structure for table collection_db.users
CREATE TABLE IF NOT EXISTS `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `username` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fcm_token` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ix_users_username` (`username`),
  KEY `ix_users_role` (`role`),
  KEY `ix_users_is_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table collection_db.users: ~2 rows (approximately)
INSERT INTO `users` (`id`, `name`, `username`, `password`, `role`, `phone`, `fcm_token`, `is_active`, `created_at`) VALUES
	(1, 'Administrator', 'admin', '$2b$12$r.bNV1tNaCzzVkjV/QfY7u58OFqPxP24dEoLcAKDpi.xf0oq2y4j2', 'admin', NULL, NULL, 1, '2026-04-10 15:27:49'),
	(2, 'Agent Demo', 'agent1', '$2b$12$XGprGYI7PCjGz.WWlPTfOuASQNvHWN.ESVoMVTOzsRP4F9FNNMmrm', 'agent', '08123456789', NULL, 1, '2026-04-10 15:27:49');

-- Dumping structure for table collection_db.va_data
CREATE TABLE IF NOT EXISTS `va_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `va_request_id` int NOT NULL,
  `va_number` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `bank_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` bigint DEFAULT NULL,
  `created_by_admin` int NOT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ix_va_data_va_request_id` (`va_request_id`),
  KEY `created_by_admin` (`created_by_admin`),
  CONSTRAINT `va_data_ibfk_1` FOREIGN KEY (`va_request_id`) REFERENCES `va_requests` (`id`),
  CONSTRAINT `va_data_ibfk_2` FOREIGN KEY (`created_by_admin`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table collection_db.va_data: ~2 rows (approximately)
INSERT INTO `va_data` (`id`, `va_request_id`, `va_number`, `bank_name`, `amount`, `created_by_admin`, `created_at`) VALUES
	(1, 1, '1234567890', 'BRI', 1500000, 1, '2026-04-10 16:32:32'),
	(2, 2, '123456754321', 'BRI', 100000, 1, '2026-04-10 16:48:14');

-- Dumping structure for table collection_db.va_requests
CREATE TABLE IF NOT EXISTS `va_requests` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `agent_id` int NOT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_va_requests_agent_id` (`agent_id`),
  KEY `ix_va_requests_customer_id` (`customer_id`),
  KEY `ix_va_requests_status` (`status`),
  CONSTRAINT `va_requests_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`),
  CONSTRAINT `va_requests_ibfk_2` FOREIGN KEY (`agent_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table collection_db.va_requests: ~2 rows (approximately)
INSERT INTO `va_requests` (`id`, `customer_id`, `agent_id`, `notes`, `status`, `created_at`, `updated_at`) VALUES
	(1, 1, 2, 'kirim va', 'completed', '2026-04-10 16:32:08', '2026-04-10 16:32:32'),
	(2, 4, 2, NULL, 'completed', '2026-04-10 16:47:50', '2026-04-10 16:48:14');

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
