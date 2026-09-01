package com.tienda.dto;

import com.tienda.entity.Producto;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public class OrdenDetalleResponse {
    private Long id;
    private String email;
    private String direccionEnvio;
    private String telefono;
    private String estado;
    private LocalDateTime fechaCreacion;
    private BigDecimal total;
    private List<ItemDetalle> items;

    public static class ItemDetalle {
        private Producto producto;
        private Integer cantidad;

        public ItemDetalle(Producto producto, Integer cantidad) {
            this.producto = producto;
            this.cantidad = cantidad;
        }

        public Producto getProducto() { return producto; }
        public Integer getCantidad() { return cantidad; }
    }

    // Getters y Setters principales
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getDireccionEnvio() { return direccionEnvio; }
    public void setDireccionEnvio(String direccionEnvio) { this.direccionEnvio = direccionEnvio; }
    public String getTelefono() { return telefono; }
    public void setTelefono(String telefono) { this.telefono = telefono; }
    public String getEstado() { return estado; }
    public void setEstado(String estado) { this.estado = estado; }
    public LocalDateTime getFechaCreacion() { return fechaCreacion; }
    public void setFechaCreacion(LocalDateTime fechaCreacion) { this.fechaCreacion = fechaCreacion; }
    public BigDecimal getTotal() { return total; }
    public void setTotal(BigDecimal total) { this.total = total; }
    public List<ItemDetalle> getItems() { return items; }
    public void setItems(List<ItemDetalle> items) { this.items = items; }
}