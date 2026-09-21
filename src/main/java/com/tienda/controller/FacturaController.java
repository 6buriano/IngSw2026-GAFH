package com.tienda.controller;

import com.tienda.dto.FacturaResponse;
import com.tienda.service.FacturaService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/facturas")
public class FacturaController {

    private final FacturaService facturaService;

    public FacturaController(FacturaService facturaService) {
        this.facturaService = facturaService;
    }

    @GetMapping("/orden/{ordenId}")
    public ResponseEntity<FacturaResponse> obtenerFacturaPorOrden(@PathVariable Long ordenId) {
        FacturaResponse factura = facturaService.obtenerFacturaPorOrdenId(ordenId);
        return ResponseEntity.ok(factura);
    }
}