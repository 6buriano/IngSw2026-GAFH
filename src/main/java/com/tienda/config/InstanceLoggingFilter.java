package com.tienda.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.net.InetAddress;

/**
 * Filtro de trazabilidad para el cluster (Laboratorio 5).
 *
 * <p>Agrega a cada request un log con el nombre/hostname de la instancia que atendió
 * la petición y devuelve el header HTTP {@code X-Instancia}. Como las 3 réplicas del
 * servicio corren la MISMA imagen, esta marca es la que permite verificar en los logs
 * de Docker Swarm que el balanceador de carga está repartiendo las solicitudes entre
 * los distintos nodos/instancias.</p>
 *
 * <p>No modifica el comportamiento de la API: sólo agrega el header y una línea de log.</p>
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class InstanceLoggingFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(InstanceLoggingFilter.class);

    private final String instancia = resolverNombreInstancia();

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        // Identifica la réplica en la respuesta (útil para verificar el balanceo con `curl -i`).
        response.setHeader("X-Instancia", instancia);

        long inicio = System.nanoTime();
        try {
            filterChain.doFilter(request, response);
        } finally {
            long duracionMs = (System.nanoTime() - inicio) / 1_000_000;
            if (request.getRequestURI().startsWith("/api")) {
                log.info("[REQ] {} {} -> {} | instancia={} | {} ms",
                        request.getMethod(),
                        request.getRequestURI(),
                        response.getStatus(),
                        instancia,
                        duracionMs);
            }
        }
    }

    /**
     * En Docker Swarm el hostname del contenedor identifica a la tarea (réplica) que
     * atendió el request. En ejecución local se usa el nombre de la máquina.
     */
    private static String resolverNombreInstancia() {
        String porVariable = System.getenv("INSTANCIA");
        if (porVariable != null && !porVariable.isBlank()) {
            return porVariable.trim();
        }
        String hostname = System.getenv("HOSTNAME");
        if (hostname != null && !hostname.isBlank()) {
            return hostname.trim();
        }
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            return "instancia-desconocida";
        }
    }
}
