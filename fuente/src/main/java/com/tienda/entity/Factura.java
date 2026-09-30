package com.tienda.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "factura")
public class Factura {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "orden_id", nullable = false, unique = true)
    private Orden orden;

    @Column(name = "fecha_emision", nullable = false)
    private LocalDateTime fechaEmision;

    @Column(name = "monto_total", nullable = false)
    private BigDecimal montoTotal;

    @OneToMany(mappedBy = "factura", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<FacturaItem> items = new ArrayList<>();

    public Factura() {
        this.fechaEmision = LocalDateTime.now();
    }

    public Factura(Orden orden, BigDecimal montoTotal) {
        this();
        this.orden = orden;
        this.montoTotal = montoTotal;
    }

    // Getters y Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Orden getOrden() { return orden; }
    public void setOrden(Orden orden) { this.orden = orden; }

    public LocalDateTime getFechaEmision() { return fechaEmision; }
    public void setFechaEmision(LocalDateTime fechaEmision) { this.fechaEmision = fechaEmision; }

    public BigDecimal getMontoTotal() { return montoTotal; }
    public void setMontoTotal(BigDecimal montoTotal) { this.montoTotal = montoTotal; }

    public List<FacturaItem> getItems() { return items; }
    public void setItems(List<FacturaItem> items) { this.items = items; }
}