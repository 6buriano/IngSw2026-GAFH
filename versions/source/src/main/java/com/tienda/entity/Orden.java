package com.tienda.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList; // <--- Importante agregar esta importación
import java.util.List;      // <--- Importante agregar esta importación

@Entity
@Table(name = "Orden")
public class Orden {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String email;

    @Column(name = "direccion_envio")
    private String direccionEnvio;

    private String telefono;
    private String estado;

    @Column(name = "fecha_creacion")
    private LocalDateTime fechaCreacion;

    private BigDecimal total;

    // --- NUEVO CAMPO AÑADIDO AQUÍ ---
    @OneToMany(mappedBy = "orden", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrdenItem> items = new ArrayList<>();

    public Orden() {
        this.fechaCreacion = LocalDateTime.now();
        this.estado = "Created";
    }

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

    // --- NUEVOS GETTER Y SETTER AÑADIDOS AQUÍ ---
    public List<OrdenItem> getItems() { return items; }
    public void setItems(List<OrdenItem> items) { this.items = items; }
}