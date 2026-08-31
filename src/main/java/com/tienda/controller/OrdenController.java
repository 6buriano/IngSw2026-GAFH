package com.tienda.controller;

import com.tienda.dto.CrearOrdenRequest;
import com.tienda.dto.OrdenDetalleResponse;
import com.tienda.dto.OrdenResumenResponse;
import com.tienda.entity.Orden;
import com.tienda.service.OrdenService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/ordenes")
public class OrdenController {

    private final OrdenService ordenService;

    public OrdenController(OrdenService ordenService) {
        this.ordenService = ordenService;
    }

@PostMapping
public ResponseEntity<Orden> crearOrden(@Valid @RequestBody CrearOrdenRequest request) {
    Orden nuevaOrden = ordenService.crearOrden(request);
    return ResponseEntity.status(HttpStatus.CREATED).body(nuevaOrden);
    }


@GetMapping
public ResponseEntity<List<OrdenResumenResponse>> obtenerOrdenes() {
return ResponseEntity.ok(ordenService.obtenerTodasLasOrdenes());
}

@GetMapping("/{id}")
public ResponseEntity<Orden> obtenerOrdenPorId(@PathVariable Long id) {
    return ResponseEntity.ok(ordenService.obtenerOrdenPorId(id));
}

@GetMapping("/{id}/detalle")
public ResponseEntity<OrdenDetalleResponse> obtenerOrdenDetalle(@PathVariable Long id) {
    return ResponseEntity.ok(ordenService.obtenerOrdenConDetalle(id));
}
}