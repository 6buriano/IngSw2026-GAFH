package com.tienda.controller;

import com.tienda.dto.ProductoDTO;
import com.tienda.dto.ProductoPatchDTO;
import com.tienda.entity.Producto;
import com.tienda.service.ProductoService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/productos")
public class ProductoController {

    private final ProductoService productoService;

    public ProductoController(ProductoService productoService) {
        this.productoService = productoService;
    }

    // GET /api/productos (Lista completa)
    @GetMapping
    public ResponseEntity<List<Producto>> listarProductos() {
        return ResponseEntity.ok(productoService.obtenerTodos());
    }

    // GET /api/productos/{id} (Individual o 404)
    @GetMapping("/{id}")
    public ResponseEntity<Producto> obtenerProductoPorId(@PathVariable Long id) {
        return productoService.obtenerPorId(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // POST /api/productos (Creación o 400 Bad Request)
    @PostMapping
    public ResponseEntity<Producto> crearProducto(@Valid @RequestBody ProductoDTO dto) {
        Producto nuevoProducto = productoService.crearProducto(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(nuevoProducto);
    }

    // PUT /api/productos/{id} (Reemplazo total)
    @PutMapping("/{id}")
    public ResponseEntity<Producto> reemplazarProducto(
            @PathVariable Long id,
            @Valid @RequestBody ProductoDTO dto) {
        return productoService.reemplazarProducto(id, dto)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // PATCH /api/productos/{id} (Actualización parcial)
    @PatchMapping("/{id}")
    public ResponseEntity<Producto> actualizarParcialProducto(
            @PathVariable Long id,
            @Valid @RequestBody ProductoPatchDTO dto) {
        return productoService.actualizarParcialProducto(id, dto)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}