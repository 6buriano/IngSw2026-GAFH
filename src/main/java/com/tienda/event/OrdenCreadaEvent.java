package com.tienda.event;

import com.tienda.entity.Orden;

public class OrdenCreadaEvent {
    private final Orden orden;

    public OrdenCreadaEvent(Orden orden) {
        this.orden = orden;
    }

    public Orden getOrden() {
        return orden;
    }
}