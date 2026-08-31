package com.tienda.service;

import com.tienda.dto.CrearOrdenRequest;
import com.tienda.dto.OrdenDetalleResponse;
import com.tienda.dto.OrdenItemRequest;
import com.tienda.dto.OrdenResumenResponse;
import com.tienda.entity.Orden;
import com.tienda.entity.OrdenItem;
import com.tienda.entity.Producto;
import com.tienda.exception.OrdenNotFoundException;
import com.tienda.exception.StockException;
import com.tienda.repository.OrdenRepository;
import com.tienda.repository.ProductoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

import java.math.BigDecimal;

@Service
public class OrdenService {

    private final OrdenRepository ordenRepository;
    private final ProductoRepository productoRepository;

    public OrdenService(OrdenRepository ordenRepository, 
                        ProductoRepository productoRepository) {
        this.ordenRepository = ordenRepository;
        this.productoRepository = productoRepository;
    }

    @Transactional
    public Orden crearOrden(CrearOrdenRequest request) {
        // 1. Instanciar objeto base de la orden
        Orden orden = new Orden();
        orden.setEmail(request.getEmail());
        orden.setDireccionEnvio(request.getDireccionEnvio());
        orden.setTelefono(request.getTelefono());
        orden.setEstado("Created");

        BigDecimal total = BigDecimal.ZERO;

        // 2. Procesar ítems y validar reglas de negocio (Stock y Existencia)
        if (request.getProductos() != null && !request.getProductos().isEmpty()) {
            for (OrdenItemRequest itemReq : request.getProductos()) {
                Long productoId = itemReq.getProductoId();

                // Buscar el producto; si no existe lanza StockException (HTTP 409 Conflict)
                Producto producto = productoRepository.findById(productoId)
                        .orElseThrow(() -> new StockException("El producto con ID " + productoId + " no existe."));

                // Validar stock disponible
                if (producto.getStock() < itemReq.getCantidad()) {
                    throw new StockException("Stock insuficiente para '" + producto.getNombre() + "'. Disponible: " + producto.getStock());
                }

                // Descontar stock del producto
                producto.setStock(producto.getStock() - itemReq.getCantidad());
                productoRepository.save(producto);

                // Acumular total
                BigDecimal subtotal = producto.getPrecio().multiply(BigDecimal.valueOf(itemReq.getCantidad()));
                total = total.add(subtotal);

                // Asociar el ítem
                OrdenItem item = new OrdenItem(orden, producto, itemReq.getCantidad());
                orden.getItems().add(item);
            }
        }

        // 3. Asignar total y guardar la orden una sola vez con sus ítems asociados
        orden.setTotal(total);
        return ordenRepository.save(orden);
    }

    @Transactional(readOnly = true)
public List<OrdenResumenResponse> obtenerTodasLasOrdenes() {
    return ordenRepository.findAll().stream().map(orden -> {
        List<Long> productoIds = orden.getItems().stream()
                .map(item -> item.getProducto().getId())
                .toList();
        return new OrdenResumenResponse(
                orden.getId(),
                orden.getEmail(),
                orden.getEstado(),
                orden.getFechaCreacion(),
                orden.getTotal(),
                productoIds
        );
    }).toList();
}

@Transactional(readOnly = true)
public Orden obtenerOrdenPorId(Long id) {
    return ordenRepository.findById(id)
            .orElseThrow(() -> new OrdenNotFoundException("Orden no encontrada con ID: " + id));
}

@Transactional(readOnly = true)
public OrdenDetalleResponse obtenerOrdenConDetalle(Long id) {
    Orden orden = obtenerOrdenPorId(id);

    OrdenDetalleResponse response = new OrdenDetalleResponse();
    response.setId(orden.getId());
    response.setEmail(orden.getEmail());
    response.setDireccionEnvio(orden.getDireccionEnvio());
    response.setTelefono(orden.getTelefono());
    response.setEstado(orden.getEstado());
    response.setFechaCreacion(orden.getFechaCreacion());
    response.setTotal(orden.getTotal());

    List<OrdenDetalleResponse.ItemDetalle> itemsDetalle = orden.getItems().stream()
            .map(item -> new OrdenDetalleResponse.ItemDetalle(item.getProducto(), item.getCantidad()))
            .toList();

    response.setItems(itemsDetalle);
    return response;
}

}