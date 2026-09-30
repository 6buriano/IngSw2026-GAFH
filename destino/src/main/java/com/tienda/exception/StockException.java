package com.tienda.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.CONFLICT) // <-- Esto mapea la excepción automáticamente a un HTTP 409
public class StockException extends RuntimeException {
    public StockException(String message) {
        super(message);
    }
}