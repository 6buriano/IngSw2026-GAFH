package com.tienda.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public class OrdenResumenResponse {
    private Long id;
    private String email;
    private String estado;
    private LocalDateTime fechaCreacion;
    private BigDecimal total;
    private List<Long> productoIds;

    // Constructor, getters y setters
    public OrdenResumenResponse(Long id, String email, String estado, LocalDateTime fechaCreacion, BigDecimal total, List<Long> productoIds) {
        this.id = id;
        this.email = email;
        this.estado = estado;
        this.fechaCreacion = fechaCreacion;
        this.total = total;
        this.productoIds = productoIds;
    }

    public Long getId() { return id; }
    public String getEmail() { return email; }
    public String getEstado() { return estado; }
    public LocalDateTime getFechaCreacion() { return fechaCreacion; }
    public BigDecimal getTotal() { return total; }
    public List<Long> getProductoIds() { return productoIds; }
}