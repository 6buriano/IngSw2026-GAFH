#!/bin/bash

# Configuración base
BASE_URL="http://localhost:8080/api"
BROKER_HOST="localhost"
BROKER_PORT="1883"
TOPIC="ordenes/creadas"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

probar_endpoint() {
  local descripcion="$1"
  local metodo="$2"
  local url="$3"
  local json_data="$4"
  local codigo_esperado="$5"

  echo -n "Probando: $descripcion... "

  if [ -n "$json_data" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X "$metodo" "$url" \
      -H "Content-Type: application/json" \
      -d "$json_data")
  else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X "$metodo" "$url" \
      -H "accept: */*")
  fi

  if [ "$HTTP_CODE" -eq "$codigo_esperado" ]; then
    echo -e "${GREEN}PASÓ (HTTP $HTTP_CODE)${NC}"
  else
    echo -e "${RED}FALLÓ (Obtenido: $HTTP_CODE | Esperado: $codigo_esperado)${NC}"
  fi
}

echo "=========================================================="
echo "    SUITE COMPLETA DE PRUEBAS DE INTEGRACIÓN (LAB 2 + LAB 3)"
echo "=========================================================="

# ---------------------------------------------------------
# BLOQUE 1: PRUEBAS DEL LABORATORIO 2 (REST & VALIDACIONES)
# ---------------------------------------------------------
echo -e "\n${YELLOW}--- [1] Pruebas REST de Productos (Lab 2) ---${NC}"
probar_endpoint "POST /productos (Creación exitosa)" "POST" "$BASE_URL/productos" \
  '{"nombre":"Laptop Test","descripcion":"Laptop de prueba","precio":1200.00,"stock":10,"categoria":"Tech","imagenes":[]}' 201

probar_endpoint "GET /productos (Listar productos)" "GET" "$BASE_URL/productos" "" 200
probar_endpoint "GET /productos/1 (Obtener producto por ID)" "GET" "$BASE_URL/productos/1" "" 200
probar_endpoint "GET /productos/9999 (Producto no encontrado)" "GET" "$BASE_URL/productos/9999" "" 404
probar_endpoint "POST /productos (Error 400 - Precio inválido)" "POST" "$BASE_URL/productos" \
  '{"nombre":"","descripcion":"Test","precio":-10.00,"stock":5,"categoria":"Tech","imagenes":[]}' 400

echo -e "\n${YELLOW}--- [2] Validaciones de Órdenes REST (Lab 2) ---${NC}"
probar_endpoint "POST /ordenes (Error 400 - Email vacío)" "POST" "$BASE_URL/ordenes" \
  '{"email":"","direccionEnvio":"Calle Test 123","telefono":"099111222","productos":[{"productoId":1,"cantidad":1}]}' 400

# ---------------------------------------------------------
# BLOQUE 2: PRUEBAS DEL LABORATORIO 3 (MQTT & FACTURACIÓN)
# ---------------------------------------------------------
echo -e "\n${YELLOW}--- [3] Flujo Asíncrono Happy Path (US9, US10, US12) ---${NC}"

echo -n "Enviando POST /ordenes (Petición válida)... "
RESPUESTA_ORDEN=$(curl -s -X POST "$BASE_URL/ordenes" \
  -H "Content-Type: application/json" \
  -d '{"email":"lab3.happy@example.com","direccionEnvio":"Av. Italia 2400","telefono":"099123456","productos":[{"productoId":1,"cantidad":2}]}')

ORDEN_ID=$(echo "$RESPUESTA_ORDEN" | grep -o '"id":[^,]*' | head -n 1 | cut -d':' -f2 | tr -d ' ')

if [ -n "$ORDEN_ID" ]; then
  echo -e "${GREEN}PASÓ (Orden ID: $ORDEN_ID generada - HTTP 201)${NC}"
else
  echo -e "${RED}FALLÓ (No se obtuvo ID de la orden)${NC}"
fi

echo -e "Esperando procesamiento asíncrono MQTT (2 segundos)..."
sleep 2

# Verificar cambio de estado a 'Ready to Delivery'
echo -n "Verificando cambio de estado de la orden... "
ESTADO_ORDEN=$(curl -s "$BASE_URL/ordenes/$ORDEN_ID" | grep -o '"estado":"[^"]*' | cut -d'"' -f4)

if [ "$ESTADO_ORDEN" == "Ready to Delivery" ] || [ "$ESTADO_ORDEN" == "READY_TO_DELIVERY" ]; then
  echo -e "${GREEN}PASÓ (Estado: $ESTADO_ORDEN)${NC}"
else
  echo -e "${RED}FALLÓ (Estado obtenido: $ESTADO_ORDEN | Esperado: Ready to Delivery)${NC}"
fi

# Consulta REST de la factura (US12)
probar_endpoint "GET /facturas/orden/$ORDEN_ID (Obtener factura)" "GET" "$BASE_URL/facturas/orden/$ORDEN_ID" "" 200

echo -e "\n${YELLOW}--- [4] Escenario Sin Stock (US11) ---${NC}"
echo -n "Enviando POST /ordenes con cantidad excesiva... "
RESPUESTA_SIN_STOCK=$(curl -s -X POST "$BASE_URL/ordenes" \
  -H "Content-Type: application/json" \
  -d '{"email":"sin.stock@example.com","direccionEnvio":"Calle Falsa 123","telefono":"099000000","productos":[{"productoId":1,"cantidad":9999}]}')

ORDEN_SIN_STOCK_ID=$(echo "$RESPUESTA_SIN_STOCK" | grep -o '"id":[^,]*' | head -n 1 | cut -d':' -f2 | tr -d ' ')

sleep 2

echo -n "Verificando que la orden haya pasado a estado 'No Stock'... "
ESTADO_SIN_STOCK=$(curl -s "$BASE_URL/ordenes/$ORDEN_SIN_STOCK_ID" | grep -o '"estado":"[^"]*' | cut -d'"' -f4)

if [ "$ESTADO_SIN_STOCK" == "No Stock" ] || [ "$ESTADO_SIN_STOCK" == "NO_STOCK" ]; then
  echo -e "${GREEN}PASÓ (Estado: $ESTADO_SIN_STOCK)${NC}"
else
  echo -e "${RED}FALLÓ (Estado obtenido: $ESTADO_SIN_STOCK | Esperado: No Stock)${NC}"
fi

# Verificar que NO se emitió factura
probar_endpoint "GET /facturas/orden/$ORDEN_SIN_STOCK_ID (Factura inexistente)" "GET" "$BASE_URL/facturas/orden/$ORDEN_SIN_STOCK_ID" "" 404

echo -e "\n${YELLOW}--- [5] Prueba de Idempotencia por MQTT (US11) ---${NC}"
if command -v mosquitto_pub &> /dev/null || docker exec tienda_mqtt mosquitto_pub --help &> /dev/null; then
  echo -n "Publicando evento duplicado para la Orden ID $ORDEN_ID vía MQTT... "
  PAYLOAD="{\"id\":$ORDEN_ID,\"estado\":\"Created\"}"
  
  if command -v mosquitto_pub &> /dev/null; then
    mosquitto_pub -h "$BROKER_HOST" -p "$BROKER_PORT" -t "$TOPIC" -m "$PAYLOAD"
  else
    docker exec tienda_mqtt mosquitto_pub -h localhost -p 1883 -t "$TOPIC" -m "$PAYLOAD"
  fi
  
  sleep 2
  
  ESTADO_POST_DUPLICADO=$(curl -s "$BASE_URL/ordenes/$ORDEN_ID" | grep -o '"estado":"[^"]*' | cut -d'"' -f4)
  if [ "$ESTADO_POST_DUPLICADO" == "Ready to Delivery" ] || [ "$ESTADO_POST_DUPLICADO" == "READY_TO_DELIVERY" ]; then
    echo -e "${GREEN}PASÓ (La orden mantuvo su estado original sin re-procesar)${NC}"
  else
    echo -e "${RED}FALLÓ (El estado fue alterado a: $ESTADO_POST_DUPLICADO)${NC}"
  fi
else
  echo -e "${RED}Omitido: 'mosquitto_pub' o contenedor 'tienda_mqtt' no disponibles.${NC}"
fi

echo "=========================================================="
echo "                 PRUEBAS COMPLETADAS                      "
echo "=========================================================="