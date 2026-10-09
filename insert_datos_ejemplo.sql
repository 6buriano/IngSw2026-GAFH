-- ========================================================
-- Script de Inserción de Datos de Prueba (Imágenes Gratis)
-- Alineado con el MER provisto por el usuario
-- ========================================================


-- 1. INSERTAR PRODUCTOS EJEMPLO
INSERT INTO productos (id, nombre, descripcion, precio, stock, categoria) VALUES
(1, 'Camiseta Minimalista Algodón', 'Camiseta 100% algodón orgánico de corte moderno y estilo minimalista.', 25.99, 50, 'Ropa'),
(2, 'Tenis Deportivos Urban', 'Zapatillas deportivas ideales para el uso diario y caminatas urbanas.', 79.95, 30, 'Calzado'),
(3, 'Mochila Porta Laptop Impermeable', 'Mochila con compartimento acolchado para laptop de hasta 15 pulgadas.', 45.0, 20, 'Accesorios'),
(4, 'Reloj de Pulsera Clásico', 'Reloj analógico con correa de cuero legítimo y diseño elegante.', 120.0, 15, 'Accesorios'),
(5, 'Cafetera de Goteo Automática', 'Cafetera con filtro permanente y capacidad para 12 tazas.', 59.99, 10, 'Hogar'),
(6, 'Audífonos Inalámbricos Bluetooth', 'Audífonos de diadema con cancelación de ruido activa.', 89.99, 25, 'Tecnología'),
(7, 'Lámpara de Escritorio LED', 'Lámpara con brazo articulado y 3 niveles de intensidad táctil.', 29.95, 40, 'Hogar'),
(8, 'Termo Acero Inoxidable 1L', 'Termo de doble capa que mantiene bebidas frías o calientes por 24 horas.', 19.99, 100, 'Accesorios'),
(9, 'Silla de Oficina Ergonómica', 'Silla con soporte lumbar ajustable y reposabrazos cómodos.', 145.5, 8, 'Muebles'),
(10, 'Teclado Mecánico RGB', 'Teclado con switches mecánicos ideal para programar o gaming.', 69.99, 18, 'Tecnología');

-- 2. INSERTAR IMÁGENES ASOCIADAS (URLs libres de derechos de Pexels)
INSERT INTO imagenes_producto (id, producto_id, url) VALUES
(1, 1, 'https://images.pexels.com/photos/1656684/pexels-photo-1656684.jpeg?auto=compress&cs=tinysrgb&w=600'),
(2, 2, 'https://images.pexels.com/photos/1464625/pexels-photo-1464625.jpeg?auto=compress&cs=tinysrgb&w=600'),
(3, 3, 'https://images.pexels.com/photos/2905238/pexels-photo-2905238.jpeg?auto=compress&cs=tinysrgb&w=600'),
(4, 4, 'https://images.pexels.com/photos/1908188/pexels-photo-1908188.jpeg?auto=compress&cs=tinysrgb&w=600'),
(5, 5, 'https://images.pexels.com/photos/2142414/pexels-photo-2142414.jpeg?auto=compress&cs=tinysrgb&w=600'),
(6, 6, 'https://images.pexels.com/photos/1649771/pexels-photo-1649771.jpeg?auto=compress&cs=tinysrgb&w=600'),
(7, 7, 'https://images.pexels.com/photos/11125923/pexels-photo-11125923.jpeg?auto=compress&cs=tinysrgb&w=600'),
(8, 8, 'https://images.pexels.com/photos/4000014/pexels-photo-4000014.jpeg?auto=compress&cs=tinysrgb&w=600'),
(9, 9, 'https://images.pexels.com/photos/3773581/pexels-photo-3773581.jpeg?auto=compress&cs=tinysrgb&w=600'),
(10, 10, 'https://images.pexels.com/photos/1772123/pexels-photo-1772123.jpeg?auto=compress&cs=tinysrgb&w=600');

-- Restaurar contadores AUTO_INCREMENT para futuras inserciones manuales
ALTER TABLE productos AUTO_INCREMENT = 11;
ALTER TABLE imagenes_producto AUTO_INCREMENT = 11;