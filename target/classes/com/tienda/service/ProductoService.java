package com.tienda.service;

import com.tienda.dto.ProductoDTO;
import com.tienda.dto.ProductoPatchDTO;
import com.tienda.entity.Producto;
import com.tienda.entity.ProductoImagen;
import com.tienda.repository.ProductoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class ProductoService {

    private final ProductoRepository productoRepository;

    public ProductoService(ProductoRepository productoRepository) {
        this.productoRepository = productoRepository;
    }

    public List<Producto> obtenerTodos() {
        return productoRepository.findAll();
    }

    public Optional<Producto> obtenerPorId(Long id) {
        return productoRepository.findById(id);
    }

    @Transactional
    public Producto crearProducto(ProductoDTO dto) {
        Producto producto = new Producto(
                dto.getNombre(),
                dto.getDescripcion(),
                dto.getPrecio(),
                dto.getStock(),
                dto.getCategoria()
        );

        if (dto.getImagenes() != null) {
            List<ProductoImagen> imagenes = dto.getImagenes().stream()
                    .map(ProductoImagen::new)
                    .collect(Collectors.toList());
            producto.setImagenes(imagenes);
        }

        return productoRepository.save(producto);
    }

    @Transactional
    public Optional<Producto> reemplazarProducto(Long id, ProductoDTO dto) {
        return productoRepository.findById(id).map(producto -> {
            producto.setNombre(dto.getNombre());
            producto.setDescripcion(dto.getDescripcion());
            producto.setPrecio(dto.getPrecio());
            producto.setStock(dto.getStock());
            producto.setCategoria(dto.getCategoria());

            if (dto.getImagenes() != null) {
                List<ProductoImagen> imagenes = dto.getImagenes().stream()
                        .map(ProductoImagen::new)
                        .collect(Collectors.toList());
                producto.setImagenes(imagenes);
            } else {
                producto.getImagenes().clear();
            }

            return productoRepository.save(producto);
        });
    }

    @Transactional
    public Optional<Producto> actualizarParcialProducto(Long id, ProductoPatchDTO dto) {
        return productoRepository.findById(id).map(producto -> {
            if (dto.getNombre() != null) producto.setNombre(dto.getNombre());
            if (dto.getDescripcion() != null) producto.setDescripcion(dto.getDescripcion());
            if (dto.getPrecio() != null) producto.setPrecio(dto.getPrecio());
            if (dto.getStock() != null) producto.setStock(dto.getStock());
            if (dto.getCategoria() != null) producto.setCategoria(dto.getCategoria());

            if (dto.getImagenes() != null) {
                List<ProductoImagen> imagenes = dto.getImagenes().stream()
                        .map(ProductoImagen::new)
                        .collect(Collectors.toList());
                producto.setImagenes(imagenes);
            }

            return productoRepository.save(producto);
        });
    }
}