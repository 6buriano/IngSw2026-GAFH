package com.tienda.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public class FacturaResponse {

    private Long id;
    private Long ordenId;
    private LocalDateTime fechaEmision;
    private BigDecimal montoTotal;
    private List<ItemFacturaResponse> items;

    public FacturaResponse() {}

    public FacturaResponse(Long id, Long ordenId, LocalDateTime fechaEmision, BigDecimal montoTotal, List<ItemFacturaResponse> items) {
        this.id = id;
        this.ordenId = ordenId;
        this.fechaEmision = fechaEmision;
        this.montoTotal = montoTotal;
        this.items = items;
    }

    public static class ItemFacturaResponse {
        private Long productoId;
        private String productoNombre;
        private Integer cantidad;
        private BigDecimal precioUnitario;
        private BigDecimal subtotal;

        public ItemFacturaResponse(Long productoId, String productoNombre, Integer cantidad, BigDecimal precioUnitario, BigDecimal subtotal) {
            this.productoId = productoId;
            this.productoNombre = productoNombre;
            this.cantidad = cantidad;
            this.precioUnitario = precioUnitario;
            this.subtotal = subtotal;
        }

        public Long getProductoId() { return productoId; }
        public String getProductoNombre() { return productoNombre; }
        public Integer getCantidad() { return cantidad; }
        public BigDecimal getPrecioUnitario() { return precioUnitario; }
        public BigDecimal getSubtotal() { return subtotal; }
    }

    // Getters y Setters de FacturaResponse
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getOrdenId() { return ordenId; }
    public void setOrdenId(Long ordenId) { this.ordenId = ordenId; }

    public LocalDateTime getFechaEmision() { return fechaEmision; }
    public void setFechaEmision(LocalDateTime fechaEmision) { this.fechaEmision = fechaEmision; }

    public BigDecimal getMontoTotal() { return montoTotal; }
    public void setMontoTotal(BigDecimal montoTotal) { this.montoTotal = montoTotal; }

    public List<ItemFacturaResponse> getItems() { return items; }
    public void setItems(List<ItemFacturaResponse> items) { this.items = items; }
}