package com.tienda.Repositorios;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.tienda.Orden;

@Repository
public interface OrdenRepository extends JpaRepository<Orden, Integer> {
}
