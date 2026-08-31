-- =============================================
-- Script MER → MySQL (Alineado con Java JPA)
-- =============================================

DROP TABLE IF EXISTS Orden_Producto;
DROP TABLE IF EXISTS imagenes_producto;
DROP TABLE IF EXISTS Orden;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS Producto;

-- 1. TABLA PRODUCTOS (Alineada con Producto.java)
CREATE TABLE IF NOT EXISTS productos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL CHECK (precio >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    categoria VARCHAR(50)
);

-- 2. TABLA IMAGENES_PRODUCTO
CREATE TABLE IF NOT EXISTS imagenes_producto (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    producto_id BIGINT NOT NULL,
    url VARCHAR(500) NOT NULL,
    FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE
);

-- 3. TABLA ORDEN
CREATE TABLE IF NOT EXISTS Orden (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    direccion_envio VARCHAR(500) NOT NULL,
    telefono VARCHAR(50),
    estado VARCHAR(50) NOT NULL DEFAULT 'Created',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10,2) NOT NULL DEFAULT 0.00
);

-- 4. TABLA INTERMEDIA ORDEN_PRODUCTO
CREATE TABLE IF NOT EXISTS Orden_Producto (
    id_producto BIGINT NOT NULL,
    id_orden BIGINT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    PRIMARY KEY (id_producto, id_orden),
    CONSTRAINT fk_orden_producto_producto FOREIGN KEY (id_producto) REFERENCES productos(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orden_producto_orden FOREIGN KEY (id_orden) REFERENCES Orden(id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Índices recomendados
CREATE INDEX idx_orden_producto_producto ON Orden_Producto(id_producto);
CREATE INDEX idx_orden_producto_orden    ON Orden_Producto(id_orden);
CREATE INDEX idx_orden_email             ON Orden(email);
CREATE INDEX idx_orden_estado            ON Orden(estado);

-- Datos iniciales de prueba permanentes
INSERT INTO productos (nombre, descripcion, precio, stock, categoria) 
VALUES ('Producto de prueba', 'aDescripción del producto', 100.00, 10, 'General');