package com.tienda.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;

@Entity
@Table(name = "Orden_Producto")
public class OrdenItem {

    @EmbeddedId
    private OrdenItemId id = new OrdenItemId();

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("ordenId")
    @JoinColumn(name = "id_orden")
    @JsonIgnore
    private Orden orden;

    @ManyToOne(fetch = FetchType.EAGER)
    @MapsId("productoId")
    @JoinColumn(name = "id_producto")
    private Producto producto;

    @Column(name = "cantidad")
    private Integer cantidad;

    public OrdenItem() {}

    public OrdenItem(Orden orden, Producto producto, Integer cantidad) {
        this.orden = orden;
        this.producto = producto;
        this.cantidad = cantidad;
        this.id = new OrdenItemId(orden.getId(), producto.getId());
    }

    public OrdenItemId getId() { return id; }
    public void setId(OrdenItemId id) { this.id = id; }

    public Orden getOrden() { return orden; }
    public void setOrden(Orden orden) { this.orden = orden; }

    public Producto getProducto() { return producto; }
    public void setProducto(Producto producto) { this.producto = producto; }

    public Integer getCantidad() { return cantidad; }
    public void setCantidad(Integer cantidad) { this.cantidad = cantidad; }
}