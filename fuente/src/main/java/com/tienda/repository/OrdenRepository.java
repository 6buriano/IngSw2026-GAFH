package com.tienda.repository;

import com.tienda.entity.Orden;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface OrdenRepository extends JpaRepository<Orden, Long> {
    List<Orden> findAllByOrderByFechaCreacionDesc();
}