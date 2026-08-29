package com.tienda.Repositorios;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.tienda.Orden_Producto;

@Repository
public interface OrdenProductoRepository
        extends JpaRepository<Orden_Producto, Integer> {

    List<Orden_Producto> findByOrdenId(Integer idOrden);
}
