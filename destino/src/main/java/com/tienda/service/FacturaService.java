package com.tienda.service;

import com.tienda.dto.FacturaResponse;
import com.tienda.entity.Factura;
import com.tienda.entity.FacturaItem;
import com.tienda.entity.Orden;
import com.tienda.entity.OrdenItem;
import com.tienda.entity.Producto;
import com.tienda.repository.FacturaRepository;
import com.tienda.repository.OrdenRepository;
import com.tienda.repository.ProductoRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class FacturaService {

    private final OrdenRepository ordenRepository;
    private final ProductoRepository productoRepository;
    private final FacturaRepository facturaRepository;

    public FacturaService(OrdenRepository ordenRepository,
                          ProductoRepository productoRepository,
                          FacturaRepository facturaRepository) {
        this.ordenRepository = ordenRepository;
        this.productoRepository = productoRepository;
        this.facturaRepository = facturaRepository;
    }

    @Transactional(readOnly = true)
    public FacturaResponse obtenerFacturaPorOrdenId(Long ordenId) {
        Factura factura = facturaRepository.findByOrdenId(ordenId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, 
                        "No existe factura emitida para la orden ID: " + ordenId
                ));

        List<FacturaResponse.ItemFacturaResponse> items = factura.getItems().stream()
                .map(item -> new FacturaResponse.ItemFacturaResponse(
                        item.getProducto().getId(),
                        item.getProducto().getNombre(),
                        item.getCantidad(),
                        item.getPrecioUnitario(),
                        item.getSubtotal()
                )).toList();

        return new FacturaResponse(
                factura.getId(),
                factura.getOrden().getId(),
                factura.getFechaEmision(),
                factura.getMontoTotal(),
                items
        );
    }

    @Transactional
    public void procesarYFacturarOrden(Long ordenId) {
        Orden orden = ordenRepository.findById(ordenId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, 
                        "Orden no encontrada con ID: " + ordenId
                ));

        // Evitar procesar dos veces la misma orden
        if (!"Created".equalsIgnoreCase(orden.getEstado())) {
            System.out.println(">>> [Procesamiento] La orden " + ordenId + " ya fue procesada. Estado actual: " + orden.getEstado());
            return;
        }

        // 1. Validar si hay stock disponible para TODOS los productos de la orden
        boolean stockSuficiente = true;

        for (OrdenItem item : orden.getItems()) {
            Producto producto = item.getProducto();
            if (producto.getStock() < item.getCantidad()) {
                stockSuficiente = false;
                break;
            }
        }

        // 2. Si NO hay stock suficiente -> cambiar estado a 'No Stock'
        if (!stockSuficiente) {
            orden.setEstado("No Stock");
            ordenRepository.save(orden);
            System.out.println(">>> [Procesamiento] Orden " + ordenId + " rechazada por stock insuficiente. Estado actualizado a 'No Stock'.");
            return;
        }

        // 3. Si HAY stock -> Descontar stock, generar Factura y actualizar estado
        Factura factura = new Factura();
        factura.setOrden(orden);
        factura.setFechaEmision(LocalDateTime.now());
        factura.setMontoTotal(orden.getTotal());

        for (OrdenItem item : orden.getItems()) {
            Producto producto = item.getProducto();

            // Descontar stock
            producto.setStock(producto.getStock() - item.getCantidad());
            productoRepository.save(producto);

            // Crear renglón/ítem de la factura
            FacturaItem facturaItem = new FacturaItem();
            facturaItem.setFactura(factura);
            facturaItem.setProducto(producto);
            facturaItem.setCantidad(item.getCantidad());
            facturaItem.setPrecioUnitario(producto.getPrecio());
            facturaItem.setSubtotal(producto.getPrecio().multiply(java.math.BigDecimal.valueOf(item.getCantidad())));

            factura.getItems().add(facturaItem);
        }

        // Guardar factura (en cascada guarda sus ítems)
        facturaRepository.save(factura);

        // Actualizar estado de la orden
        orden.setEstado("Ready to Delivery");
        ordenRepository.save(orden);

        System.out.println(">>> [Facturación] Orden " + ordenId + " procesada exitosamente. Factura #" + factura.getId() + " generada. Estado: 'Ready to Delivery'.");
    }
}