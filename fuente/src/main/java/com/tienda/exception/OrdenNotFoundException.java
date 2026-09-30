package com.tienda.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class OrdenNotFoundException extends RuntimeException {
    public OrdenNotFoundException(String message) {
        super(message);
    }
}