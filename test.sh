#!/bin/bash

# Configuración base
BASE_URL="http://localhost:8080/api"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función auxiliar para evaluar resultados
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

echo "=========================================="
echo " EJECUTANDO PRUEBAS DE INTEGRACIÓN (US8) "
echo "=========================================="

# 1. Pruebas de Productos (US4)
probar_endpoint "POST /productos (Creación exitosa)" "POST" "$BASE_URL/productos" \
  '{"nombre":"Laptop Test","descripcion":"Laptop de prueba","precio":1200.00,"stock":10,"categoria":"Tech","imagenes":[]}' 201

probar_endpoint "GET /productos (Listar productos)" "GET" "$BASE_URL/productos" "" 200

probar_endpoint "GET /productos/1 (Obtener producto por ID)" "GET" "$BASE_URL/productos/1" "" 200

probar_endpoint "GET /productos/9999 (Producto no encontrado)" "GET" "$BASE_URL/productos/9999" "" 404

probar_endpoint "POST /productos (Error 400 - Precio inválido)" "POST" "$BASE_URL/productos" \
  '{"nombre":"","descripcion":"Test","precio":-10.00,"stock":5,"categoria":"Tech","imagenes":[]}' 400

# 2. Pruebas de Órdenes (US5)
probar_endpoint "POST /ordenes (Creación exitosa de orden)" "POST" "$BASE_URL/ordenes" \
  '{"email":"test.us8@example.com","direccionEnvio":"Calle Test 123","telefono":"099111222","productos":[{"productoId":1,"cantidad":2}]}' 201

probar_endpoint "POST /ordenes (Error 400 - Email vacío)" "POST" "$BASE_URL/ordenes" \
  '{"email":"","direccionEnvio":"Calle Test 123","telefono":"099111222","productos":[{"productoId":1,"cantidad":1}]}' 400

probar_endpoint "POST /ordenes (Error 409 - Stock insuficiente)" "POST" "$BASE_URL/ordenes" \
  '{"email":"test.us8@example.com","direccionEnvio":"Calle Test 123","telefono":"099111222","productos":[{"productoId":1,"cantidad":99999}]}' 409

# 3. Pruebas de Consulta de Órdenes (US6)
probar_endpoint "GET /ordenes (Listar resúmenes de órdenes)" "GET" "$BASE_URL/ordenes" "" 200

probar_endpoint "GET /ordenes/1 (Obtener orden por ID)" "GET" "$BASE_URL/ordenes/1" "" 200

probar_endpoint "GET /ordenes/1/detalle (Obtener orden con detalle)" "GET" "$BASE_URL/ordenes/1/detalle" "" 200

probar_endpoint "GET /ordenes/9999 (Orden no encontrada)" "GET" "$BASE_URL/ordenes/9999" "" 404

echo "=========================================="
echo "           PRUEBAS FINALIZADAS            "
echo "=========================================="