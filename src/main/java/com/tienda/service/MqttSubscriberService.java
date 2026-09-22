package com.tienda.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.tienda.dto.OrdenEventDTO;
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

@Service
public class MqttSubscriberService implements MqttCallback {

    @Value("${mqtt.broker.url:tcp://mosquitto:1883}")
    private String brokerUrl;

    private final ObjectMapper objectMapper;
    private final FacturaService facturaService;

    public MqttSubscriberService(FacturaService facturaService) {
        this.facturaService = facturaService;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    @EventListener(ApplicationReadyEvent.class)
    public void suscribir() {
        try {
            String clientId = "SubscriberService-" + System.currentTimeMillis();
            MqttClient client = new MqttClient(brokerUrl, clientId);
            client.setCallback(this);
            client.connect();
            
            String topic = "ordenes/creadas";
            client.subscribe(topic, 1);
            System.out.println(">>> [MQTT Sub] Suscrito exitosamente al tópico '" + topic + "'");

        } catch (Exception e) {
            System.err.println(">>> [MQTT Sub Error] Error al suscribir al tópico MQTT: " + e.getMessage());
        }
    }

    @Override
    public void connectionLost(Throwable cause) {
        System.err.println(">>> [MQTT Sub] Conexión perdida con el broker MQTT: " + cause.getMessage());
    }

    @Override
    public void messageArrived(String topic, MqttMessage message) {
        String payload = new String(message.getPayload());
        System.out.println(">>> [MQTT Recibido] Mensaje del tópico '" + topic + "': " + payload);

        try {
            OrdenEventDTO event = objectMapper.readValue(payload, OrdenEventDTO.class);
            System.out.println(">>> [MQTT Procesado] Orden ID: " + event.getId() 
                    + " | Estado: " + event.getEstado() 
                    + " | Fecha: " + event.getFechaCreacion());
            
            if (event.getId() != null) {
                // Invocación del servicio para facturar y actualizar estado a 'Ready to Delivery'
                facturaService.procesarYFacturarOrden(event.getId());
            }

        } catch (Exception e) {
            System.err.println(">>> [MQTT Sub Error] Error al procesar el mensaje MQTT: " + e.getMessage());
            e.printStackTrace();
        }
    }

    @Override
    public void deliveryComplete(IMqttDeliveryToken token) {
        // No aplica para el suscriptor
    }
}