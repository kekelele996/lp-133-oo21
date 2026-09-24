-- 志愿者互助平台数据库
-- 数据库端口: 5733
-- 字符集: utf8mb4
-- 注意：推荐使用 backend/init-db.js 进行初始化，避免中文乱码问题

CREATE DATABASE IF NOT EXISTS volunteer_db 
DEFAULT CHARACTER SET utf8mb4 
DEFAULT COLLATE utf8mb4_unicode_ci;

USE volunteer_db;

SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  phone VARCHAR(20) UNIQUE NOT NULL COMMENT '手机号',
  password VARCHAR(255) NOT NULL COMMENT '密码',
  name VARCHAR(50) NOT NULL COMMENT '姓名',
  role ENUM('volunteer', 'resident') NOT NULL COMMENT '角色: volunteer-志愿者, resident-居民',
  skills VARCHAR(500) COMMENT '擅长领域(志愿者)',
  address VARCHAR(500) COMMENT '地址',
  lat DECIMAL(10, 7) DEFAULT 0 COMMENT '纬度',
  lng DECIMAL(10, 7) DEFAULT 0 COMMENT '经度',
  points INT DEFAULT 0 COMMENT '积分',
  service_hours DECIMAL(8, 2) DEFAULT 0 COMMENT '服务时长(小时)',
  avatar VARCHAR(500) COMMENT '头像',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_role (role),
  INDEX idx_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- 需求表
CREATE TABLE IF NOT EXISTS needs (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL COMMENT '发布者ID',
  title VARCHAR(200) NOT NULL COMMENT '需求标题',
  description TEXT COMMENT '需求描述',
  type VARCHAR(50) NOT NULL COMMENT '需求类型',
  address VARCHAR(500) COMMENT '服务地址',
  lat DECIMAL(10, 7) DEFAULT 0 COMMENT '纬度',
  lng DECIMAL(10, 7) DEFAULT 0 COMMENT '经度',
  expected_time DATETIME COMMENT '期望时间',
  volunteer_id INT COMMENT '接单志愿者ID',
  status ENUM('pending', 'accepted', 'completed', 'cancelled') DEFAULT 'pending' COMMENT '状态',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (volunteer_id) REFERENCES users(id),
  INDEX idx_status (status),
  INDEX idx_type (type),
  INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='需求表';

-- 订单表
CREATE TABLE IF NOT EXISTS orders (
  id INT PRIMARY KEY AUTO_INCREMENT,
  need_id INT NOT NULL COMMENT '需求ID',
  user_id INT NOT NULL COMMENT '需求发布者ID',
  volunteer_id INT NOT NULL COMMENT '志愿者ID',
  status ENUM('in_progress', 'completed', 'cancelled') DEFAULT 'in_progress' COMMENT '状态',
  service_hours DECIMAL(8, 2) DEFAULT 0 COMMENT '服务时长(小时)',
  start_time DATETIME COMMENT '开始时间',
  end_time DATETIME COMMENT '结束时间',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (need_id) REFERENCES needs(id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (volunteer_id) REFERENCES users(id),
  INDEX idx_status (status),
  INDEX idx_user_id (user_id),
  INDEX idx_volunteer_id (volunteer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表';

-- 评价表
CREATE TABLE IF NOT EXISTS reviews (
  id INT PRIMARY KEY AUTO_INCREMENT,
  order_id INT NOT NULL COMMENT '订单ID',
  reviewer_id INT NOT NULL COMMENT '评价者ID',
  target_id INT NOT NULL COMMENT '被评价者ID',
  rating TINYINT NOT NULL COMMENT '评分: 1-5',
  comment TEXT COMMENT '评价内容',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (reviewer_id) REFERENCES users(id),
  FOREIGN KEY (target_id) REFERENCES users(id),
  INDEX idx_target_id (target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评价表';

-- 消息表
CREATE TABLE IF NOT EXISTS messages (
  id INT PRIMARY KEY AUTO_INCREMENT,
  sender_id INT NOT NULL COMMENT '发送者ID',
  receiver_id INT NOT NULL COMMENT '接收者ID',
  content TEXT NOT NULL COMMENT '消息内容',
  is_read TINYINT DEFAULT 0 COMMENT '是否已读: 0-未读, 1-已读',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sender_id) REFERENCES users(id),
  FOREIGN KEY (receiver_id) REFERENCES users(id),
  INDEX idx_sender_receiver (sender_id, receiver_id),
  INDEX idx_receiver (receiver_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息表';

-- 礼品表
CREATE TABLE IF NOT EXISTS gifts (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL COMMENT '礼品名称',
  description VARCHAR(500) COMMENT '礼品描述',
  image VARCHAR(500) COMMENT '礼品图片',
  points_required INT NOT NULL COMMENT '所需积分',
  stock INT DEFAULT 100 COMMENT '库存',
  is_active TINYINT DEFAULT 1 COMMENT '是否上架',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='礼品表';

-- 兑换记录表
CREATE TABLE IF NOT EXISTS exchanges (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL COMMENT '用户ID',
  gift_id INT NOT NULL COMMENT '礼品ID',
  points INT NOT NULL COMMENT '消耗积分',
  status ENUM('pending', 'shipped', 'completed') DEFAULT 'pending' COMMENT '状态',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (gift_id) REFERENCES gifts(id),
  INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='兑换记录表';

-- 清空旧数据 - 按外键依赖的反顺序删除
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE exchanges;
TRUNCATE TABLE gifts;
TRUNCATE TABLE messages;
TRUNCATE TABLE reviews;
TRUNCATE TABLE orders;
TRUNCATE TABLE needs;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

-- 重置自增ID
ALTER TABLE users AUTO_INCREMENT = 1;
ALTER TABLE needs AUTO_INCREMENT = 1;
ALTER TABLE orders AUTO_INCREMENT = 1;
ALTER TABLE reviews AUTO_INCREMENT = 1;
ALTER TABLE messages AUTO_INCREMENT = 1;
ALTER TABLE gifts AUTO_INCREMENT = 1;
ALTER TABLE exchanges AUTO_INCREMENT = 1;

-- 密码: 123456 的 bcrypt 哈希
SET @pwd_hash = '$2a$10$8OgNyMetWSC05tEgwJvGTe7a6knQkr29APVcmDL2ptUD1we0XKJj6';

-- 志愿者用户
INSERT INTO users (phone, password, name, role, skills, address, lat, lng, points, service_hours) VALUES
('13800138001', @pwd_hash, 'Zhang Zhiyuan', 'volunteer', 'PeiLiao,PeiZhen,DaiMai', 'Beijing Chaoyang Jianguo Road 88', 39.9042, 116.4074, 560, 56),
('13800138002', @pwd_hash, 'Li Rexin', 'volunteer', 'JiaDianWeiXiu,JiaZhengFuWu', 'Beijing Haidian Zhongguancun Street 1', 39.9842, 116.3074, 320, 32),
('13800138003', @pwd_hash, 'Wang Bamang', 'volunteer', 'DaiMaiDaiBan,JiaZhengFuWu', 'Beijing Xicheng Finance Street 15', 39.9142, 116.3674, 480, 48);

-- 居民用户
INSERT INTO users (phone, password, name, role, address, lat, lng) VALUES
('13900139001', @pwd_hash, 'Liu Nainai', 'resident', 'Beijing Chaoyang Guanghua Road 2', 39.9122, 116.4574),
('13900139002', @pwd_hash, 'Chen Yeye', 'resident', 'Beijing Haidian Xueyuan Road 30', 39.9922, 116.3474),
('13900139003', @pwd_hash, 'Zhao Ayi', 'resident', 'Beijing Xicheng Yuetan South Street 1', 39.9222, 116.3574);

-- 需求数据
INSERT INTO needs (user_id, title, description, type, address, lat, lng, expected_time, status) VALUES
(4, 'Need accompany to hospital for checkup', 'Hypertension need hospital checkup, need someone to accompany', 'accompany', 'Beijing Chaoyang Guanghua Road 2', 39.9122, 116.4574, '2026-05-20 09:00:00', 'pending'),
(5, 'Help buy hypertension medicine', 'Legs not convenient, need help buy medicine', 'shopping', 'Beijing Haidian Xueyuan Road 30', 39.9922, 116.3474, '2026-05-20 10:00:00', 'pending'),
(6, 'TV broken need repair', 'TV cannot turn on, need help', 'repair', 'Beijing Xicheng Yuetan South Street 1', 39.9222, 116.3574, '2026-05-21 14:00:00', 'pending'),
(4, 'Want someone to chat on weekend', 'Children not at home, want someone to chat', 'accompany', 'Beijing Chaoyang Guanghua Road 2', 39.9122, 116.4574, '2026-05-24 15:00:00', 'pending'),
(5, 'Need help cleaning house', 'Old age, cannot clean, need help', 'housework', 'Beijing Haidian Xueyuan Road 30', 39.9922, 116.3474, '2026-05-22 09:00:00', 'pending');

-- 礼品数据
INSERT INTO gifts (name, description, image, points_required, stock) VALUES
('Premium Thermos Cup', '500ml large capacity thermos cup, good insulation', 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=400', 100, 50),
('Rice 10kg Pack', 'Premium Northeast rice, soft and delicious', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400', 200, 30),
('Cooking Oil 5L', 'Non-GMO soybean oil, healthy and nutritious', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400', 300, 20),
('Milk Gift Box', 'Pure milk gift box, perfect gift', 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400', 250, 40),
('Bedding 4-piece Set', 'Pure cotton comfortable bedding set', 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?w=400', 500, 15),
('Health Pot', 'Multi-function health pot, make tea and soup', 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=400', 400, 25);
