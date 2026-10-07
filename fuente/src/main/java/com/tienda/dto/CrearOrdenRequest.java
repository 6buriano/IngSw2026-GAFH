package com.tienda.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public class CrearOrdenRequest {

    @NotBlank(message = "El email es obligatorio")
    @Email(message = "Formato de email inválido")
    private String email;

    @NotBlank(message = "La dirección es obligatoria")
    private String direccionEnvio;

    @NotBlank(message = "El teléfono es obligatorio")
    private String telefono;

    @NotEmpty(message = "La orden debe contener al menos un producto")
    @Valid
    private List<OrdenItemRequest> productos; // Mapea la lista "productos" del JSON

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getDireccionEnvio() { return direccionEnvio; }
    public void setDireccionEnvio(String direccionEnvio) { this.direccionEnvio = direccionEnvio; }

    public String getTelefono() { return telefono; }
    public void setTelefono(String telefono) { this.telefono = telefono; }

    public List<OrdenItemRequest> getProductos() { return productos; }
    public void setProductos(List<OrdenItemRequest> productos) { this.productos = productos; }
}