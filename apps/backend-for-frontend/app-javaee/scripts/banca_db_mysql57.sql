-- ============================================================
-- BANCO NACIONAL - Script de Base de Datos
-- Motor:   MySQL 5.7.44
-- Charset: utf8mb4
-- ============================================================

CREATE DATABASE IF NOT EXISTS banca_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE banca_db;

-- Usuario de BD
CREATE USER IF NOT EXISTS 'banca_user'@'localhost'
    IDENTIFIED BY 'banca_pass123';
GRANT ALL PRIVILEGES ON banca_db.* TO 'banca_user'@'localhost';
FLUSH PRIVILEGES;

-- ============================================================
-- TABLAS
-- ============================================================

DROP TABLE IF EXISTS transferencia;
DROP TABLE IF EXISTS cuenta;
DROP TABLE IF EXISTS usuario;

-- USUARIO
CREATE TABLE usuario (
    id                BIGINT          NOT NULL AUTO_INCREMENT,
    username          VARCHAR(50)     NOT NULL,
    password          VARCHAR(255)    NOT NULL,
    nombres           VARCHAR(100)    NOT NULL,
    apellidos         VARCHAR(100)    NOT NULL,
    email             VARCHAR(150)    NOT NULL,
    telefono          VARCHAR(20)     DEFAULT NULL,
    estado            VARCHAR(20)     NOT NULL DEFAULT 'ACTIVO',
    rol               VARCHAR(20)     NOT NULL DEFAULT 'CLIENTE',
    intentos_fallidos TINYINT         NOT NULL DEFAULT 0,
    fecha_creacion    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- MySQL 5.7: solo una columna puede tener DEFAULT CURRENT_TIMESTAMP
    -- por eso ultimo_acceso es NULL por defecto
    ultimo_acceso     DATETIME        DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_username (username),
    UNIQUE KEY uq_email (email),
    CONSTRAINT ck_usuario_estado CHECK (estado IN ('ACTIVO','INACTIVO','BLOQUEADO')),
    CONSTRAINT ck_usuario_rol   CHECK (rol IN ('CLIENTE','ADMIN'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- CUENTA
CREATE TABLE cuenta (
    id                BIGINT          NOT NULL AUTO_INCREMENT,
    numero_cuenta     VARCHAR(13)     NOT NULL,
    cci               VARCHAR(20)     NOT NULL,
    tipo_cuenta       VARCHAR(20)     NOT NULL,
    moneda            VARCHAR(3)      NOT NULL DEFAULT 'PEN',
    saldo             DECIMAL(15,2)   NOT NULL DEFAULT 0.00,
    saldo_disponible  DECIMAL(15,2)   NOT NULL DEFAULT 0.00,
    estado            VARCHAR(20)     NOT NULL DEFAULT 'ACTIVA',
    usuario_id        BIGINT          NOT NULL,
    fecha_apertura    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_numero_cuenta (numero_cuenta),
    UNIQUE KEY uq_cci (cci),
    CONSTRAINT fk_cuenta_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuario (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_tipo_cuenta CHECK (tipo_cuenta IN ('AHORROS','CORRIENTE')),
    CONSTRAINT ck_moneda       CHECK (moneda IN ('PEN','USD')),
    CONSTRAINT ck_cuenta_estado CHECK (estado IN ('ACTIVA','INACTIVA','BLOQUEADA')),
    INDEX idx_cuenta_usuario (usuario_id),
    INDEX idx_cuenta_estado  (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TRANSFERENCIA
CREATE TABLE transferencia (
    id                    BIGINT          NOT NULL AUTO_INCREMENT,
    numero_operacion      VARCHAR(20)     NOT NULL,
    tipo_transferencia    VARCHAR(20)     NOT NULL,
    cuenta_origen_id      BIGINT          NOT NULL,
    cuenta_origen_numero  VARCHAR(13)     NOT NULL,
    cuenta_destino_id     BIGINT          DEFAULT NULL,
    cuenta_destino_numero VARCHAR(13)     DEFAULT NULL,
    cuenta_destino_cci    VARCHAR(20)     DEFAULT NULL,
    banco_destino         VARCHAR(100)    DEFAULT NULL,
    titular_destino       VARCHAR(200)    DEFAULT NULL,
    monto                 DECIMAL(15,2)   NOT NULL,
    moneda                VARCHAR(3)      NOT NULL DEFAULT 'PEN',
    glosa                 VARCHAR(200)    DEFAULT NULL,
    estado                VARCHAR(20)     NOT NULL DEFAULT 'PENDIENTE',
    motivo_rechazo        VARCHAR(300)    DEFAULT NULL,
    -- MySQL 5.7: fecha_operacion tiene DEFAULT CURRENT_TIMESTAMP
    fecha_operacion       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- fecha_valor se actualiza en el INSERT explícitamente desde Java
    fecha_valor           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_id            BIGINT          NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_numero_operacion (numero_operacion),
    CONSTRAINT fk_transf_origen  FOREIGN KEY (cuenta_origen_id)
        REFERENCES cuenta (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_transf_destino FOREIGN KEY (cuenta_destino_id)
        REFERENCES cuenta (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_transf_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuario (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_tipo_transf CHECK (tipo_transferencia IN ('PROPIA','MISMO_BANCO','OTRO_BANCO')),
    CONSTRAINT ck_transf_estado CHECK (estado IN ('PENDIENTE','PROCESADA','RECHAZADA')),
    INDEX idx_transf_usuario (usuario_id),
    INDEX idx_transf_origen  (cuenta_origen_id),
    INDEX idx_transf_fecha   (fecha_operacion),
    INDEX idx_transf_estado  (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DATOS DE PRUEBA
-- Contraseña para todos: Admin123*
-- Hash BCrypt generado con factor 10
-- ============================================================

INSERT INTO usuario (username, password, nombres, apellidos, email, telefono, estado, rol)
VALUES
('admin',
 '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWu',
 'Administrador', 'Sistema', 'admin@banconacional.com', '999000001', 'ACTIVO', 'ADMIN'),

('jgarcia',
 '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWu',
 'Juan Carlos', 'García López', 'jgarcia@email.com', '987654321', 'ACTIVO', 'CLIENTE'),

('mramirez',
 '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWu',
 'María Elena', 'Ramírez Torres', 'mramirez@email.com', '987123456', 'ACTIVO', 'CLIENTE');

-- Cuentas de jgarcia (id=2)
INSERT INTO cuenta (numero_cuenta, cci, tipo_cuenta, moneda, saldo, saldo_disponible, estado, usuario_id)
VALUES
('1234567890001', '00212345678900010000', 'AHORROS',   'PEN', 15420.50, 14920.50, 'ACTIVA', 2),
('1234567890002', '00212345678900020000', 'CORRIENTE',  'PEN',  8300.00,  8300.00, 'ACTIVA', 2),
('1234567890003', '00212345678900030000', 'AHORROS',   'USD',  2500.00,  2500.00, 'ACTIVA', 2);

-- Cuentas de mramirez (id=3)
INSERT INTO cuenta (numero_cuenta, cci, tipo_cuenta, moneda, saldo, saldo_disponible, estado, usuario_id)
VALUES
('9876543210001', '00298765432100010000', 'AHORROS',   'PEN', 6200.00, 6200.00, 'ACTIVA', 3),
('9876543210002', '00298765432100020000', 'CORRIENTE',  'PEN', 1500.00, 1500.00, 'ACTIVA', 3);

-- Transferencias de ejemplo
INSERT INTO transferencia
  (numero_operacion, tipo_transferencia, cuenta_origen_id, cuenta_origen_numero,
   cuenta_destino_id, cuenta_destino_numero, titular_destino, banco_destino,
   monto, moneda, glosa, estado, usuario_id)
VALUES
('OP20240101001A', 'PROPIA', 1, '1234567890001',
 2, '1234567890002', 'Juan Carlos García López', 'Banco Nacional',
 500.00, 'PEN', 'Traslado a cuenta corriente', 'PROCESADA', 2),

('OP20240102002B', 'MISMO_BANCO', 1, '1234567890001',
 4, '9876543210001', 'María Elena Ramírez Torres', 'Banco Nacional',
 200.00, 'PEN', 'Pago préstamo', 'PROCESADA', 2),

('OP20240103003C', 'OTRO_BANCO', 2, '1234567890002',
 NULL, NULL, 'Pedro Flores Torres', 'BCP - Banco de Crédito del Perú',
 350.00, 'PEN', 'Pago servicios', 'PROCESADA', 2);

-- ============================================================
-- VERIFICACIÓN
-- ============================================================
SELECT 'usuarios'       AS tabla, COUNT(*) AS registros FROM usuario
UNION ALL
SELECT 'cuentas',       COUNT(*) FROM cuenta
UNION ALL
SELECT 'transferencias', COUNT(*) FROM transferencia;
