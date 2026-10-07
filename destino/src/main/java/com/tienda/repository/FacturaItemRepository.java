package com.tienda.repository;

import com.tienda.entity.FacturaItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FacturaItemRepository extends JpaRepository<FacturaItem, Long> {
}