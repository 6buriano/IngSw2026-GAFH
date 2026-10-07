package com.tienda;

import com.tienda.entity.Producto;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

public class ProductoUnitTest {

    @Test
    @DisplayName("Debe instanciar y asignar atributos de Producto correctamente")
    void testCreacionProducto() {
        Producto producto = new Producto("Teclado Mecanico", "Switch Blue RGB", new BigDecimal("75.50"), 20, "Perifericos");

        assertNotNull(producto);
        assertEquals("Teclado Mecanico", producto.getNombre());
        assertEquals("Switch Blue RGB", producto.getDescripcion());
        assertEquals(new BigDecimal("75.50"), producto.getPrecio());
        assertEquals(20, producto.getStock());
        assertEquals("Perifericos", producto.getCategoria());
    }

    @Test
    @DisplayName("Debe actualizar el stock y precio correctamente")
    void testModificacionProducto() {
        Producto producto = new Producto();
        producto.setNombre("Monitor 27");
        producto.setPrecio(new BigDecimal("299.99"));
        producto.setStock(5);

        assertEquals(5, producto.getStock());
        assertEquals(new BigDecimal("299.99"), producto.getPrecio());

        // Actualizar stock
        producto.setStock( producto.getStock() - 2 );
        assertEquals(3, producto.getStock());
    }
}
