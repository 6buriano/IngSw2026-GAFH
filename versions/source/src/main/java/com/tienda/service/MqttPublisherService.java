package com.tienda.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.tienda.dto.OrdenEventDTO;
import com.tienda.entity.Orden;
import com.tienda.event.OrdenCreadaEvent;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Service
public class MqttPublisherService {

    @Value("${mqtt.broker.url:tcp://mosquitto:1883}")
    private String brokerUrl;

    private final ObjectMapper objectMapper;

    public MqttPublisherService() {
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
        // Desactiva la serialización como timestamps para generar formato ISO-8601 en la fecha
        this.objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }

    /**
     * Escucha el evento 'OrdenCreadaEvent' y ejecuta la publicación a MQTT
     * ÚNICAMENTE cuando la transacción de la base de datos se haya confirmado (COMMIT).
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleOrdenCreadaEvent(OrdenCreadaEvent event) {
        publicarOrdenCreada(event.getOrden());
    }

    public void publicarOrdenCreada(Orden orden) {
        String topic = "ordenes/creadas";
        MqttClient client = null;
        try {
            String clientId = "PublisherService-" + System.currentTimeMillis();
            client = new MqttClient(brokerUrl, clientId);
            client.connect();

            OrdenEventDTO eventDTO = new OrdenEventDTO();
            eventDTO.setId(orden.getId());
            eventDTO.setEstado(orden.getEstado());
            eventDTO.setFechaCreacion(orden.getFechaCreacion());

            String jsonPayload = objectMapper.writeValueAsString(eventDTO);

            MqttMessage message = new MqttMessage(jsonPayload.getBytes());
            message.setQos(1); // At least once

            client.publish(topic, message);

            System.out.println(">>> [MQTT] Orden publicada con éxito en el tópico '" + topic + "': " + jsonPayload);

        } catch (Exception e) {
            System.err.println(">>> [MQTT Error] Error al publicar orden " + orden.getId() + ": " + e.getMessage());
            e.printStackTrace();
        } finally {
            if (client != null && client.isConnected()) {
                try {
                    client.disconnect();
                    client.close();
                } catch (Exception ex) {
                    System.err.println(">>> [MQTT Error] Error al cerrar conexión del cliente: " + ex.getMessage());
                }
            }
        }
    }
}