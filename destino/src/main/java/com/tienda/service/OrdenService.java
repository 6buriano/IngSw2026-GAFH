package com.tienda.service;

import com.tienda.dto.CrearOrdenRequest;
import com.tienda.dto.OrdenDetalleResponse;
import com.tienda.dto.OrdenItemRequest;
import com.tienda.dto.OrdenResumenResponse;
import com.tienda.entity.Orden;
import com.tienda.entity.OrdenItem;
import com.tienda.entity.Producto;
import com.tienda.event.OrdenCreadaEvent;
import com.tienda.exception.OrdenNotFoundException;
import com.tienda.exception.StockException;
import com.tienda.repository.OrdenRepository;
import com.tienda.repository.ProductoRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class OrdenService {

    private final OrdenRepository ordenRepository;
    private final ProductoRepository productoRepository;
    private final ApplicationEventPublisher eventPublisher;

    public OrdenService(OrdenRepository ordenRepository, 
                        ProductoRepository productoRepository,
                        ApplicationEventPublisher eventPublisher) {
        this.ordenRepository = ordenRepository;
        this.productoRepository = productoRepository;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
public Orden crearOrden(CrearOrdenRequest request) {
    // 1. Instanciar objeto base de la orden
    Orden orden = new Orden();
    orden.setEmail(request.getEmail());
    orden.setDireccionEnvio(request.getDireccionEnvio());
    orden.setTelefono(request.getTelefono());
    orden.setEstado("Created");
    orden.setFechaCreacion(LocalDateTime.now());

    BigDecimal total = BigDecimal.ZERO;

    // 2. Procesar ítems (Validar producto, calcular total y armar relaciones)
    if (request.getProductos() != null && !request.getProductos().isEmpty()) {
        for (OrdenItemRequest itemReq : request.getProductos()) {
            Long productoId = itemReq.getProductoId();
            Integer cantidad = itemReq.getCantidad();

            Producto producto = productoRepository.findById(productoId)
                    .orElseThrow(() -> new StockException("El producto con ID " + productoId + " no existe."));

            // NOTA: No se valida ni se descuenta stock aquí.
            // Esa responsabilidad es del servicio receptor de mensajería (Requerimiento 2 del laboratorio).

            BigDecimal subtotal = producto.getPrecio().multiply(BigDecimal.valueOf(cantidad));
            total = total.add(subtotal);

            OrdenItem item = new OrdenItem(orden, producto, cantidad);
            orden.getItems().add(item);
        }
    }

    orden.setTotal(total);

    // 3. Guardar orden en BD en estado "Created"
    Orden ordenGuardada = ordenRepository.save(orden);

    // 4. Publicar evento interno que envía el JSON por MQTT
    eventPublisher.publishEvent(new OrdenCreadaEvent(ordenGuardada));

    return ordenGuardada;
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