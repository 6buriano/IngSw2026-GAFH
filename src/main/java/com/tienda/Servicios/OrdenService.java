package com.tienda.Servicios;

import java.util.List;

import org.springframework.stereotype.Service;

import com.tienda.DTOs.OrdenDTO;
import com.tienda.DTOs.OrdenDetalleDTO;
import com.tienda.DTOs.ProductoDetalleDTO;
import com.tienda.Orden;
import com.tienda.Orden_Producto;
import com.tienda.Producto;
import com.tienda.Repositorios.OrdenProductoRepository;
import com.tienda.Repositorios.OrdenRepository;

@Service
public class OrdenService {

    private final OrdenRepository ordenRepository;
    private final OrdenProductoRepository ordenProductoRepository;

    public OrdenService(
            OrdenRepository ordenRepository,
            OrdenProductoRepository ordenProductoRepository) {

        this.ordenRepository = ordenRepository;
        this.ordenProductoRepository = ordenProductoRepository;
    }

    public List<OrdenDTO> listarOrdenes() {

        return ordenRepository.findAll()
                .stream()
                .map(this::convertirOrdenDTO)
                .toList();
    }

    public OrdenDTO obtenerOrden(Integer id) {

        Orden orden = ordenRepository.findById(id)
                .orElseThrow(() ->
                        new RuntimeException("Orden no encontrada"));

        return convertirOrdenDTO(orden);
    }

    private OrdenDTO convertirOrdenDTO(Orden orden) {

        OrdenDTO dto = new OrdenDTO();

        dto.setId(orden.getId());
        dto.setEmail(orden.getEmail());
        dto.setDireccionEnvio(orden.getDireccionEnvio());
        dto.setTelefono(orden.getTelefono());
        dto.setEstado(orden.getEstado());
        dto.setFechaCreacion(orden.getFechaCreacion());

        return dto;
    }

    public OrdenDetalleDTO obtenerDetalle(Integer id) {

        Orden orden = ordenRepository.findById(id)
                .orElseThrow(() ->
                        new RuntimeException("Orden no encontrada"));

        List<Orden_Producto> relaciones =
                ordenProductoRepository.findByOrdenId(id);

        List<ProductoDetalleDTO> productos =
                relaciones.stream()
                        .map(op -> {

                            Producto producto = op.getProducto();

                            ProductoDetalleDTO dto =
                                    new ProductoDetalleDTO();

                            dto.setId(producto.getId());
                            dto.setNombre(producto.getNombre());
                            dto.setDescripcion(producto.getDescripcion());
                            dto.setPrecioUnitario(producto.getPrecioUnitario());
                            dto.setCantidad(op.getCantidad());
                            dto.setImagenes(producto.getImagenes());

                            return dto;
                        })
                        .toList();

        OrdenDetalleDTO dto = new OrdenDetalleDTO();

        dto.setId(orden.getId());
        dto.setEmail(orden.getEmail());
        dto.setDireccionEnvio(orden.getDireccionEnvio());
        dto.setTelefono(orden.getTelefono());
        dto.setEstado(orden.getEstado());
        dto.setFechaCreacion(orden.getFechaCreacion());
        dto.setProductos(productos);

        return dto;
    }
}
