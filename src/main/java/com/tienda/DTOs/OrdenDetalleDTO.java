package com.tienda.DTOs;

import java.time.LocalDateTime;
import java.util.List;

public class OrdenDetalleDTO {

    private Integer id;
    private String email;
    private String direccionEnvio;
    private String telefono;
    private String estado;
    private LocalDateTime fechaCreacion;

    private List<ProductoDetalleDTO> productos;

    // getters y setters

    /**
     * @return Integer return the id
     */
    public Integer getId() {
        return id;
    }

    /**
     * @param id the id to set
     */
    public void setId(Integer id) {
        this.id = id;
    }

    /**
     * @return String return the email
     */
    public String getEmail() {
        return email;
    }

    /**
     * @param email the email to set
     */
    public void setEmail(String email) {
        this.email = email;
    }

    /**
     * @return String return the direccionEnvio
     */
    public String getDireccionEnvio() {
        return direccionEnvio;
    }

    /**
     * @param direccionEnvio the direccionEnvio to set
     */
    public void setDireccionEnvio(String direccionEnvio) {
        this.direccionEnvio = direccionEnvio;
    }

    /**
     * @return String return the telefono
     */
    public String getTelefono() {
        return telefono;
    }

    /**
     * @param telefono the telefono to set
     */
    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }

    /**
     * @return String return the estado
     */
    public String getEstado() {
        return estado;
    }

    /**
     * @param estado the estado to set
     */
    public void setEstado(String estado) {
        this.estado = estado;
    }

    /**
     * @return LocalDateTime return the fechaCreacion
     */
    public LocalDateTime getFechaCreacion() {
        return fechaCreacion;
    }

    /**
     * @param fechaCreacion the fechaCreacion to set
     */
    public void setFechaCreacion(LocalDateTime fechaCreacion) {
        this.fechaCreacion = fechaCreacion;
    }

    /**
     * @return List<ProductoDetalleDTO> return the productos
     */
    public List<ProductoDetalleDTO> getProductos() {
        return productos;
    }

    /**
     * @param productos the productos to set
     */
    public void setProductos(List<ProductoDetalleDTO> productos) {
        this.productos = productos;
    }

}
