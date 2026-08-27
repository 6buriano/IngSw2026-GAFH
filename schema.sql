-- =============================================
-- Script MER → MySQL
-- =============================================

-- Tabla Producto
CREATE TABLE Producto (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(255) NOT NULL,
    descripcion     TEXT,
    precioUnitario  INT NOT NULL CHECK (precioUnitario >= 0),
    stock           INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    imagenes        JSON                    -- Array de URLs/nombres de imagen (MySQL 5.7+)
);

-- Tabla Orden
CREATE TABLE Orden (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    email           VARCHAR(255) NOT NULL,
    direccionEnvio  VARCHAR(500) NOT NULL,
    telefono        VARCHAR(50),
    estado          VARCHAR(50) NOT NULL DEFAULT 'pendiente',
    fechaCreacion   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Tabla intermedia Orden_Producto (relación N:M)
CREATE TABLE Orden_Producto (
    id_producto     INT NOT NULL,
    id_pedido       INT NOT NULL,           -- Según el diagrama (corresponde a Orden.id)
    cantidad        INT NOT NULL CHECK (cantidad > 0),

    -- Clave primaria compuesta
    PRIMARY KEY (id_producto, id_pedido),

    -- Foreign Keys
    CONSTRAINT fk_orden_producto_producto
        FOREIGN KEY (id_producto) REFERENCES Producto(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_orden_producto_orden
        FOREIGN KEY (id_pedido) REFERENCES Orden(id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Índices recomendados
CREATE INDEX idx_orden_producto_producto ON Orden_Producto(id_producto);
CREATE INDEX idx_orden_producto_pedido   ON Orden_Producto(id_pedido);
CREATE INDEX idx_orden_email             ON Orden(email);
CREATE INDEX idx_orden_estado            ON Orden(estado);