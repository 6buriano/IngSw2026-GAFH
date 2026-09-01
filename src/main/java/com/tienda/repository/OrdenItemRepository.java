package com.tienda.repository;

import com.tienda.entity.OrdenItem;
import com.tienda.entity.OrdenItemId;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrdenItemRepository extends JpaRepository<OrdenItem, OrdenItemId> {
}