const mysql = require('mysql2/promise');
require('dotenv').config();

const initData = async () => {
  console.log('开始初始化数据库...');

  const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5733,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '123456',
    waitForConnections: true,
    connectionLimit: 10
  });

  try {
    // 创建数据库
    await pool.query('CREATE DATABASE IF NOT EXISTS volunteer_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    await pool.query('USE volunteer_db');
    console.log('✅ 数据库创建完成');

    // 创建用户表
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        phone VARCHAR(20) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        name VARCHAR(50) NOT NULL,
        role ENUM('volunteer', 'resident') NOT NULL,
        skills VARCHAR(500),
        address VARCHAR(500),
        lat DECIMAL(10, 7) DEFAULT 0,
        lng DECIMAL(10, 7) DEFAULT 0,
        points INT DEFAULT 0,
        service_hours DECIMAL(8, 2) DEFAULT 0,
        avatar VARCHAR(500),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_role (role),
        INDEX idx_phone (phone)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✅ 用户表创建完成');

    // 创建需求表
    await pool.query(`
      CREATE TABLE IF NOT EXISTS needs (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NOT NULL,
        title VARCHAR(200) NOT NULL,
        description TEXT,
        type VARCHAR(50) NOT NULL,
        address VARCHAR(500),
        lat DECIMAL(10, 7) DEFAULT 0,
        lng DECIMAL(10, 7) DEFAULT 0,
        expected_time DATETIME,
        volunteer_id INT,
        status ENUM('pending', 'accepted', 'completed', 'cancelled') DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (volunteer_id) REFERENCES users(id),
        INDEX idx_status (status),
        INDEX idx_type (type),
        INDEX idx_user_id (user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✅ 需求表创建完成');

    // 创建订单表
    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id INT PRIMARY KEY AUTO_INCREMENT,
        need_id INT NOT NULL,
        user_id INT NOT NULL,
        volunteer_id INT NOT NULL,
        status ENUM('in_progress', 'completed', 'cancelled') DEFAULT 'in_progress',
        service_hours DECIMAL(8, 2) DEFAULT 0,
        start_time DATETIME,
        end_time DATETIME,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (need_id) REFERENCES needs(id),
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (volunteer_id) REFERENCES users(id),
        INDEX idx_status (status),
        INDEX idx_user_id (user_id),
        INDEX idx_volunteer_id (volunteer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✅ 订单表创建完成');

    // 创建评价表
    await pool.query(`
      CREATE TABLE IF NOT EXISTS reviews (
        id INT PRIMARY KEY AUTO_INCREMENT,
        order_id INT NOT NULL,
        reviewer_id INT NOT NULL,
        target_id INT NOT NULL,
        rating TINYINT NOT NULL,
        comment TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (order_id) REFERENCES orders(id),
        FOREIGN KEY (reviewer_id) REFERENCES users(id),
        FOREIGN KEY (target_id) REFERENCES users(id),
        INDEX idx_target_id (target_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✅ 评价表创建完成');

    // 创建消息表
    await pool.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id INT PRIMARY KEY AUTO_INCREMENT,
        sender_id INT NOT NULL,
        receiver_id INT NOT NULL,
        content TEXT NOT NULL,
        is_read TINYINT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sender_id) REFERENCES users(id),
        FOREIGN KEY (receiver_id) REFERENCES users(id),
        INDEX idx_sender_receiver (sender_id, receiver_id),
        INDEX idx_receiver (receiver_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✅ 消息表创建完成');

    // 创建礼品表
    await pool.query(`
      CREATE TABLE IF NOT EXISTS gifts (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) NOT NULL,
        description VARCHAR(500),
        image VARCHAR(500),
        points_required INT NOT NULL,
        stock INT DEFAULT 100,
        is_active TINYINT DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✅ 礼品表创建完成');

    // 创建兑换记录表
    await pool.query(`
      CREATE TABLE IF NOT EXISTS exchanges (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NOT NULL,
        gift_id INT NOT NULL,
        points INT NOT NULL,
        status ENUM('pending', 'shipped', 'completed') DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (gift_id) REFERENCES gifts(id),
        INDEX idx_user_id (user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('✅ 兑换记录表创建完成');

    // 清空旧数据
    await pool.query('SET FOREIGN_KEY_CHECKS = 0');
    await pool.query('TRUNCATE TABLE exchanges');
    await pool.query('TRUNCATE TABLE gifts');
    await pool.query('TRUNCATE TABLE messages');
    await pool.query('TRUNCATE TABLE reviews');
    await pool.query('TRUNCATE TABLE orders');
    await pool.query('TRUNCATE TABLE needs');
    await pool.query('TRUNCATE TABLE users');
    await pool.query('SET FOREIGN_KEY_CHECKS = 1');
    console.log('✅ 旧数据清空完成');

    // 密码哈希 (123456)
    const pwdHash = '$2a$10$8OgNyMetWSC05tEgwJvGTe7a6knQkr29APVcmDL2ptUD1we0XKJj6';

    // 插入用户数据
    const users = [
      ['13800138001', pwdHash, '张志愿', 'volunteer', '陪聊,陪诊,代买', '北京市朝阳区建国路88号', 39.9042, 116.4074, 560, 56],
      ['13800138002', pwdHash, '李热心', 'volunteer', '家电维修,家政服务', '北京市海淀区中关村大街1号', 39.9842, 116.3074, 320, 32],
      ['13800138003', pwdHash, '王帮忙', 'volunteer', '代买代办,家政服务', '北京市西城区金融街15号', 39.9142, 116.3674, 480, 48],
      ['13900139001', pwdHash, '刘奶奶', 'resident', null, '北京市朝阳区光华路2号', 39.9122, 116.4574, 0, 0],
      ['13900139002', pwdHash, '陈爷爷', 'resident', null, '北京市海淀区学院路30号', 39.9922, 116.3474, 0, 0],
      ['13900139003', pwdHash, '赵阿姨', 'resident', null, '北京市西城区月坛南街1号', 39.9222, 116.3574, 0, 0]
    ];

    for (const user of users) {
      await pool.query(
        'INSERT INTO users (phone, password, name, role, skills, address, lat, lng, points, service_hours) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        user
      );
    }
    console.log('✅ 用户数据插入完成');

    // 插入需求数据
    const needs = [
      [4, '需要陪同去医院复查', '高血压需要去医院复查，希望有人陪同', 'accompany', '北京市朝阳区光华路2号', 39.9122, 116.4574, '2026-05-20 09:00:00'],
      [5, '帮忙买降压药', '腿脚不方便，需要帮忙买降压药', 'shopping', '北京市海淀区学院路30号', 39.9922, 116.3474, '2026-05-20 10:00:00'],
      [6, '电视机坏了需要维修', '家里电视机打不开了，需要懂家电的人帮忙看看', 'repair', '北京市西城区月坛南街1号', 39.9222, 116.3574, '2026-05-21 14:00:00'],
      [4, '周末想找人聊天解闷', '子女不在身边，周末想找人聊聊天', 'accompany', '北京市朝阳区光华路2号', 39.9122, 116.4574, '2026-05-24 15:00:00'],
      [5, '需要帮忙打扫卫生', '年纪大了，打扫不动了，需要帮忙打扫卫生', 'housework', '北京市海淀区学院路30号', 39.9922, 116.3474, '2026-05-22 09:00:00']
    ];

    for (const need of needs) {
      await pool.query(
        'INSERT INTO needs (user_id, title, description, type, address, lat, lng, expected_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        need
      );
    }
    console.log('✅ 需求数据插入完成');

    // 插入礼品数据
    const gifts = [
      ['精美保温杯', '500ml大容量保温杯，保温效果好', 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=400', 100, 50],
      ['大米10斤装', '优质东北大米，口感软糯', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400', 200, 30],
      ['食用油5L装', '非转基因大豆油，健康营养', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400', 300, 20],
      ['牛奶礼盒装', '纯牛奶礼盒装，送礼佳品', 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400', 250, 40],
      ['床上四件套', '纯棉舒适床上四件套', 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?w=400', 500, 15],
      ['养生壶', '多功能养生壶，煮茶煲汤', 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=400', 400, 25]
    ];

    for (const gift of gifts) {
      await pool.query(
        'INSERT INTO gifts (name, description, image, points_required, stock) VALUES (?, ?, ?, ?, ?)',
        gift
      );
    }
    console.log('✅ 礼品数据插入完成');

    console.log('\n🎉 数据库初始化完成！');
    console.log('');
    console.log('📝 演示账号：');
    console.log('   志愿者：13800138001 / 123456');
    console.log('   居  民：13900139001 / 123456');
    console.log('');

  } catch (err) {
    console.error('❌ 初始化失败:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
};

initData();
