package com.tienda.entity;

import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;

@Embeddable
public class OrdenItemId implements Serializable {

    private Long ordenId;
    private Long productoId;

    public OrdenItemId() {}

    public OrdenItemId(Long ordenId, Long productoId) {
        this.ordenId = ordenId;
        this.productoId = productoId;
    }

    public Long getOrdenId() { return ordenId; }
    public void setOrdenId(Long ordenId) { this.ordenId = ordenId; }

    public Long getProductoId() { return productoId; }
    public void setProductoId(Long productoId) { this.productoId = productoId; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        OrdenItemId that = (OrdenItemId) o;
        return Objects.equals(ordenId, that.ordenId) && Objects.equals(productoId, that.productoId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(ordenId, productoId);
    }
}