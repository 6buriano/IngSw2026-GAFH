# Laboratorio 5 — Cluster de 3 nodos con Docker Swarm

**Proyecto:** IngSw2026-GAFH — Tienda de productos y órdenes
**Entrega:** Parte 5 — Balanceo de carga y alta disponibilidad para `POST /api/ordenes`

---

## 1. Objetivo

Las ventas aumentaron y un solo contenedor de la API ya no alcanza. Se pide:

1. Investigar **Docker Swarm** para simular un cluster de 3 nodos.
2. Ejecutar la API REST (`POST /api/ordenes`) en **3 instancias** del mismo contenedor.
3. Usar **la misma imagen** y ejecutarlas en paralelo.
4. **Validar el balanceo** de carga viendo los logs de cada instancia.
5. **Bajar una instancia** y comprobar que las otras 2 siguen procesando.
6. **Bajar otra instancia** y comprobar que la única viva sigue procesando.
7. Configurar nginx **sólo si fuera necesario**.

---

## 2. Investigación: Docker Swarm

### 2.1 ¿Qué es?

Docker Swarm es el **orquestador nativo de Docker** (modo *swarm*, incluido en Docker Engine desde la versión 1.12).
Toma varios hosts con Docker y los presenta como **un único cluster**: el usuario declara el estado deseado
(“quiero 3 réplicas de esta imagen”) y Swarm se encarga de crearlas, distribuirlas y **re-crearlas si fallan**.

La diferencia central con `docker compose` es el **modelo declarativo con reconciliación**:

| | `docker compose up` | `docker stack deploy` (Swarm) |
|---|---|---|
| Alcance | 1 solo host | 1 o varios hosts (cluster) |
| Réplicas | 1 contenedor por servicio | N réplicas por servicio (`deploy.replicas`) |
| Si un contenedor muere | queda muerto | Swarm crea otra tarea automáticamente |
| Balanceo | no (hay que usar un proxy) | sí, *routing mesh* integrado |
| Redes | bridge del host | red **overlay** entre nodos |
| Actualizaciones | recrea contenedores (downtime) | rolling update con `start-first` y rollback |

### 2.2 Conceptos clave

| Concepto | Definición | En este laboratorio |
|---|---|---|
| **Nodo** | Host Docker que participa del swarm (manager o worker) | `docker-desktop` (manager único) |
| **Servicio** | Definición declarativa (imagen, réplicas, puertos, redes) | `tienda_lab5_api` |
| **Tarea** | Contenedor concreto que ejecuta una réplica del servicio | las 3 instancias de la API |
| **Réplica** | Cantidad deseada de tareas de un servicio | `deploy.replicas: 3` |
| **Red overlay** | Red virtual VXLAN que conecta contenedores de distintos nodos | `tienda_lab5_default` |
| **Routing mesh / ingress** | Balanceador L4 integrado que publica un puerto en todos los nodos | puerto `8080` |
| **Stack** | Conjunto de servicios desplegado desde un archivo compose | `tienda_lab5` |

### 2.3 Cómo funciona el balanceo de carga en Swarm

Cuando un servicio publica un puerto con `mode: ingress`:

1. Docker crea la red **`ingress`** (overlay) y un **balanceador IPVS**.
2. El puerto queda publicado en **todos los nodos** del swarm (no sólo donde corre la tarea).
3. Cada conexión TCP que entra al puerto se reenvía a una de las tareas del servicio, en **round robin**.

Además, dentro de la red overlay:

- El nombre del servicio (`api`) resuelve a una **VIP** (IP virtual) y el tráfico a la VIP se reparte entre las tareas.
- `tasks.api` resuelve a las IPs de **todas** las tareas (esto se usa, por ejemplo, si se quiere un proxy propio).

> **Detalle importante:** el balanceo del *routing mesh* es **por conexión TCP**. Si un cliente usa
> `keep-alive` prolongado, todas sus requests viajan por la misma conexión y caen en la misma réplica;
> por eso los scripts de prueba usan un `curl` por request (conexión nueva cada vez).

### 2.4 Alta disponibilidad y tolerancia a fallos

- `restart_policy: any` → si un contenedor muere (o el nodo se cae), Swarm **crea otra tarea**.
- `healthcheck` → Swarm conoce el estado real del contenedor y lo muestra en `docker service ps`.
- `update_config.order: start-first` → en un redeploy primero levanta la réplica nueva y después baja la vieja,
  por lo que no se pierden requests.
- Al reducir réplicas (`docker service scale api=2`), el *routing mesh* **deja de enviar tráfico** a la tarea eliminada:
  las que quedan siguen atendiendo sin intervención manual.
- En un cluster **multi-nodo real**, si se cae un nodo, Swarm **reubica** sus tareas en los nodos que tengan recursos.

### 2.5 ¿Cómo se simulan los 3 nodos?

Se usa un **swarm de un nodo manager** (Docker Desktop) con **3 réplicas** del servicio de la API:

- cada réplica es un **contenedor independiente**, con su propio hostname y su propia IP en la red overlay;
- las 3 reciben requests a través del *routing mesh*;
- las 3 corren **exactamente la misma imagen** (`ingsw2026-gafh-api:1.0.0`), sin configuración diferenciada.

El mismo `docker-compose.yml` se despliega **sin cambios** en un swarm de 3 máquinas reales:

```bash
# En el manager
docker swarm init --advertise-addr <IP_DEL_MANAGER>
docker swarm join-token worker        # muestra el comando para los workers

# En cada worker
docker swarm join --token <TOKEN> <IP_DEL_MANAGER>:2377

# En el manager: el mismo stack (Swarm reparte las réplicas entre los nodos)
docker stack deploy -c docker-compose.yml tienda_lab5
```

En ese caso hay que publicar la imagen en un registry (Docker Hub, GHCR, registry local) o construirla en
cada nodo, porque **cada nodo necesita la imagen** para poder ejecutar sus tareas.

**¿Por qué no 3 VMs?** El laboratorio pide *simular* el cluster. Con 3 réplicas en un swarm se cumplen
todos los objetivos funcionales (3 instancias en paralelo, misma imagen, balanceo real y caída de instancias).
La diferencia con 3 VMs es sólo la ubicación física de las tareas, no el comportamiento del servicio.
La sección 2.7 lista las limitaciones de esta simulación.

### 2.6 Qué aporta Swarm frente a un `docker-compose` común

- **Escalado horizontal**: `docker service scale tienda_lab5_api=3`.
- **Auto-reparación**: no hace falta reiniciar a mano.
- **Rolling updates** con rollback automático si el healthcheck falla.
- **Service discovery** por DNS (`db`, `mosquitto`) dentro de la red overlay.
- **Secretos y configs** distribuidos por el cluster (`configs` en este stack).
- **Constraints** de ubicación (por ejemplo, la base en el manager).

### 2.7 Limitaciones de la simulación (y qué haría falta en producción)

| Limitación | Impacto | Mejora en producción |
|---|---|---|
| Un solo host físico | Si se cae la máquina, se cae el cluster entero | 3 VMs / 3 nodos reales |
| Un solo MySQL | La API escala, la base no (cuello de botella) | MySQL con réplica / cluster, o servicio gestionado |
| Un solo broker MQTT | Punto único de fallo para la facturación | Cluster MQTT (p. ej. EMQX) o broker gestionado |
| Sin TLS | Tráfico HTTP plano | Terminación TLS (Traefik/nginx) o malla |
| Sin registry | La imagen vive en el manager | Registry (Docker Hub/GHCR) + `--with-registry-auth` |
| Secretos en variables de entorno | Visibles en `docker inspect` | Docker secrets |

---

## 3. Arquitectura de la solución

```
                         ┌─────────────────────────────────────────────┐
                         │        Docker Swarm (nodo manager)          │
                         │                                             │
  curl / frontend ──────▶│  :8080  (puerto publicado, ingress)         │
                         │     │                                       │
                         │     ▼   routing mesh / IPVS (round robin)   │
                         │  ┌────────┐  ┌────────┐  ┌────────┐         │
                         │  │ api.1  │  │ api.2  │  │ api.3  │  ← 3 réplicas
                         │  │ réplica│  │ réplica│  │ réplica│    (misma imagen)
                         │  └───┬────┘  └───┬────┘  └───┬────┘         │
                         │      └───────────┼───────────┘              │
                         │           ┌──────┴──────┐                   │
                         │           ▼             ▼                   │
                         │      ┌─────────┐   ┌───────────┐            │
                         │      │ MySQL   │   │ Mosquitto │            │
                         │      │ (1)     │   │ (1)       │            │
                         │      └─────────┘   └───────────┘            │
                         └─────────────────────────────────────────────┘
```

Flujo de un `POST /api/ordenes`:

1. El request entra por el puerto `8080` publicado (routing mesh).
2. Swarm lo entrega a **una** de las 3 réplicas.
3. La réplica valida los productos, guarda la orden en MySQL (estado `Created`) y publica
   el evento `ordenes/creadas` en Mosquitto.
4. Las 3 réplicas están suscriptas como **grupo compartido** (`$share/facturacion/...`), por lo que
   Mosquitto entrega el evento a **una sola** de ellas; esa réplica descuenta stock, genera la factura
   y pasa la orden a `Ready to Delivery`.
5. La respuesta HTTP la devuelve la réplica que atendió el POST.

La base de datos y el broker son **compartidos** por las 3 réplicas: es lo que permite que cualquier
réplica atienda cualquier request (no hay estado local en la API).

---

## 4. ¿Fue necesario nginx? — **No**

Con Docker Swarm **no hace falta nginx** para el balanceo:

- El *routing mesh* ya implementa un **balanceador L4** (IPVS) sobre el puerto publicado.
- Swarm ya hace **service discovery** por DNS y mantiene la lista de tareas actualizada.
- Agregar nginx sumaría un salto extra, otro punto de fallo y un problema conocido:
  nginx resuelve las IPs de las tareas **al arrancar** y las cachea; cuando Swarm re-crea una tarea
  (cambio de IP), nginx seguiría enviando tráfico a la IP vieja hasta que se recargue la configuración.
  Para evitarlo habría que usar `resolver 127.0.0.11` + `proxy_pass` con variable (ver apéndice A).

nginx sí sería necesario si se necesitara:

- balanceo **L7** (por path/host, por ejemplo `/api/ordenes` a un servicio y `/api/productos` a otro);
- terminación **TLS** en el cluster;
- *rate limiting*, caché, compresión o autenticación centralizada;
- *sticky sessions* (afinidad de sesión) en una aplicación con estado.

Ninguno de esos requisitos aparece en este laboratorio, así que el stack se resuelve sólo con Swarm
y el entregable **no incluye** `nginx.conf` (como indica la consigna).

<details>
<summary><strong>Apéndice A — Configuración de nginx si se quisiera usar igual</strong></summary>

```nginx
worker_processes auto;

events { worker_connections 1024; }

http {
    # DNS interno de Docker Swarm: re-resuelve los nombres cada 10 s
    resolver 127.0.0.11 valid=10s ipv6=off;

    server {
        listen 80;

        location /api/ {
            # variable + resolver → nginx re-resuelve y reparte entre las réplicas
            set $backend "http://tasks.tienda_lab5_api:8080";
            proxy_pass $backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```
</details>

---

## 5. Archivos entregados

```
parte5/
├── docker-compose.yml            # stack de Swarm: db + mosquitto + api (3 réplicas)
├── schema.sql                    # copia del schema del proyecto (se monta como config en MySQL)
├── mosquitto.conf                # configuración del broker (idéntica a la del proyecto)
├── scripts/
│   ├── lib.sh                    # funciones comunes (colores, esperas, conteo de logs)
│   ├── 01-levantar-cluster.sh    # swarm init + build de la imagen + stack deploy + espera 3/3
│   ├── 02-pruebas-balanceo.sh    # curls, baja de instancias y verificación de logs
│   └── 03-bajar-cluster.sh       # docker stack rm (+ opción de borrar datos / salir del swarm)
├── resultados/                   # evidencia generada por el script 02
└── README.md                     # este informe
```

`schema.sql` y `mosquitto.conf` son **copias** de los archivos del proyecto. Están duplicados a propósito:
el stack file de Swarm debe ser **autocontenido**. Un `config` de Swarm se lee del disco de la máquina
donde se ejecuta `docker stack deploy` y se sube al cluster; la ruta de `file:` se resuelve **relativa a
la carpeta del compose**, no al directorio desde el que se ejecuta el comando. Por eso `./schema.sql`
funciona desde cualquier ubicación, mientras que `../schema.sql` ataría el stack a que la carpeta esté
colgando exactamente del repositorio.

Además, a diferencia de un **bind mount** (`volumes: ./schema.sql:/...`), un `config` no apunta a un path
del nodo: Swarm lo monta desde su almacenamiento interno, así que el stack funciona igual en un cluster
multi-nodo. Un bind mount en Swarm usa un path **del nodo** donde corre la tarea; si la tarea se programa
en otro nodo, ese archivo no existe y la tarea falla al arrancar.

---

## 6. Cambios en el código de la aplicación

Como las 3 réplicas corren **la misma imagen**, hicieron falta dos ajustes mínimos para que el cluster
sea observable y correcto.

### 6.1 `InstanceLoggingFilter` — identificar la instancia en los logs

Archivo: `src/main/java/com/tienda/config/InstanceLoggingFilter.java`

- Agrega el header **`X-Instancia`** a todas las respuestas.
- Escribe una línea de log por cada request a `/api`:

```
[REQ] POST /api/ordenes -> 201 | instancia=1a2b3c4d5e6f | 12 ms
```

`instancia` es el **hostname del contenedor**, que en Swarm identifica a la tarea (réplica) que atendió
el request. Sin esta marca, los logs de las 3 réplicas serían indistinguibles.

### 6.2 `MqttSubscriberService` — suscripción compartida (una sola factura por orden)

Archivo: `src/main/java/com/tienda/service/MqttSubscriberService.java`

Con 3 réplicas suscriptas al mismo tópico `ordenes/creadas`, **las 3 recibían el mismo evento** y
las 3 intentaban facturar la misma orden al mismo tiempo (la tabla `factura` tiene `orden_id UNIQUE`,
así que dos de las tres transacciones fallaban).

Solución: **suscripción compartida** de MQTT (`$share/<grupo>/<tópico>`), soportada por Mosquitto ≥ 2.0:

```java
String suscripcion = "$share/facturacion/" + topic;  // una sola réplica recibe cada orden
client.subscribe(suscripcion, 1);
```

Además, el `clientId` ahora incluye el hostname + UUID para que las réplicas no se expulsen entre sí
en el broker.

Resultado: **el POST se balancea entre las 3 réplicas**, pero la facturación de cada orden la procesa
**exactamente una** de ellas. Es el mismo patrón *competing consumers* que se usa con colas.

---

## 7. Cómo ejecutar

### Requisitos

- Docker Desktop (Windows/macOS) o Docker Engine (Linux) **con swarm habilitado** (Docker Desktop lo soporta).
- `bash` (Git Bash en Windows, o WSL / Linux) y `curl`.
- ~4 GB de RAM libres para el motor Docker.

### Pasos

```bash
# 1) Descomprimir este zip dentro del proyecto (junto a pom.xml), en una carpeta parte5/
# 2) Levantar el cluster (hace el build de la imagen, swarm init y stack deploy)
bash scripts/01-levantar-cluster.sh

# 3) Ejecutar las pruebas de balanceo y caída de instancias
bash scripts/02-pruebas-balanceo.sh

# 4) Bajar todo
bash scripts/03-bajar-cluster.sh
```

La API queda publicada en `http://localhost:8080` (frontend en `/`, Swagger en `/swagger-ui.html`).

### Comandos manuales equivalentes

```bash
docker swarm init
docker build -t ingsw2026-gafh-api:1.0.0 .
docker stack deploy -c docker-compose.yml tienda_lab5

docker stack services tienda_lab5            # 3/3 réplicas
docker service ps tienda_lab5_api            # una tarea por réplica
docker service logs -f tienda_lab5_api       # logs de las 3 instancias

docker service scale tienda_lab5_api=2       # baja una instancia
docker service scale tienda_lab5_api=1       # baja otra
docker service scale tienda_lab5_api=3       # vuelve a 3

docker stack rm tienda_lab5
```

### Variables opcionales

| Variable | Default | Para qué |
|---|---|---|
| `STACK` | `tienda_lab5` | nombre del stack |
| `API_IMAGE` | `ingsw2026-gafh-api:1.0.0` | tag de la imagen |
| `API_URL` | `http://localhost:8080` | URL publicada |
| `ADVERTISE_ADDR` | — | IP a anunciar si `docker swarm init` falla por tener varias interfaces |

---

## 8. Resultados de la validación

> Ejecución real del **17/10/2026 a las 14:00** sobre **Docker 29.8.2** (Docker Desktop, swarm de
> 1 nodo manager `docker-desktop`, 3 réplicas). Se enviaron **36 `POST /api/ordenes`**
> (órdenes #37 a #72) y **los 36 respondieron HTTP 201**, sin fallos.
> Evidencia cruda en `resultados/`: `resumen-20261017-140050.txt`,
> `respuestas-20261017-140050.csv`, `fase1..fase4-logs.txt` y `fase*-tareas.txt`.

### 8.1 Balanceo con 3 réplicas (Fase 1)

Con las 3 réplicas corriendo se enviaron **12 requests**: los atendieron **las 3 instancias,
4 requests cada una**, en orden estrictamente round robin.

| Réplica (slot Swarm) | Instancia (hostname del contenedor) | Nodo | POST atendidos |
|---|---|---|---|
| `tienda_lab5_api.1` | `3b7673362735` | `docker-desktop` | 4 |
| `tienda_lab5_api.2` | `0a57f181d82b` | `docker-desktop` | 4 |
| `tienda_lab5_api.3` | `64d1a8c6eaf4` | `docker-desktop` | 4 |
| **Total** | **3 instancias distintas** | | **12** |

Secuencia real de las órdenes #37 a #48:
`api.2 → api.3 → api.1 → api.2 → api.3 → api.1 → …` (round robin perfecto).

Extracto de `resultados/fase1-logs.txt` (una línea por instancia):

```text
17:00:55 tienda_lab5_api.2.grkjqglgc0cc@docker-desktop | [REQ] POST /api/ordenes -> 201 | instancia=0a57f181d82b | 325 ms
17:00:56 tienda_lab5_api.3.azy3xiu6ars6@docker-desktop | [REQ] POST /api/ordenes -> 201 | instancia=64d1a8c6eaf4 | 332 ms
17:00:57 tienda_lab5_api.1.mgn3bvf0jf72@docker-desktop | [REQ] POST /api/ordenes -> 201 | instancia=3b7673362735 | 324 ms
```

### 8.2 Con 2 réplicas, tras bajar una instancia (Fase 2)

Se ejecutó `docker service scale tienda_lab5_api=2`. Swarm eliminó la tarea `api.3`
(deja de aparecer en `docker service ps`) y **las otras 2 siguieron atendiendo**:

| Instancia | POST atendidos |
|---|---|
| `3b7673362735` (api.1) | 5 |
| `0a57f181d82b` (api.2) | 5 |
| **Total** | **10 / 10 (HTTP 201)** |

La instancia `64d1a8…` (api.3) ya no aparece en los logs: el *routing mesh* dejó de enviarle
tráfico automáticamente, sin tocar el cliente ni la URL.

### 8.3 Con 1 réplica, tras bajar otra instancia (Fase 3)

Se ejecutó `docker service scale tienda_lab5_api=1`. Quedó viva únicamente `api.1` y **atendió
los 8 requests sola**:

| Instancia | POST atendidos |
|---|---|
| `3b7673362735` (api.1) | 8 |
| **Total** | **8 / 8 (HTTP 201)** |

### 8.4 Auto-reparación: caída simulada de una instancia (Fase 4)

Se volvió a `replicas=3` y se mató el contenedor de la tarea `api.3` (`docker kill` → exit code
**137**, visible en `fase4-tareas.txt`). Mientras Swarm la re-creaba:

- se enviaron 6 requests → **6/6 HTTP 201**, todas atendidas por las 2 réplicas sobrevivientes;
- Swarm volvió a **3/3 réplicas en ~15 segundos** (`esperar_replicas` lo confirma);
- la tarea nueva de `api.3` aparece como `Running` en `fase4-tareas.txt`.

Esto demuestra la **alta disponibilidad**: la caída de una instancia no corta el servicio y Swarm
restaura el estado deseado sin intervención manual.

### 8.5 Flujo MQTT (facturación en el cluster)

- La última orden (#72) quedó en estado **`Ready to Delivery`** y
  `GET /api/facturas/orden/72` respondió **HTTP 200**.
- En la ventana de la Fase 1 se crearon 12 órdenes y se registraron **12 recepciones MQTT**
  (`[MQTT Recibido]`), con **12 ids distintos** y **12 líneas de facturación**: exactamente
  **una recepción y una factura por orden**, no 36 (12 × 3 réplicas).
- No hubo **ningún** `Duplicate entry` ni error de facturación en los logs.

Esto valida la **suscripción compartida** (`$share/facturacion/ordenes/creadas`): el broker reparte
cada evento entre las réplicas una sola vez, igual que una cola de trabajo.

---

## 9. Problemas encontrados y soluciones

| Problema | Causa | Solución aplicada |
|---|---|---|
| `depends_on` no se respeta | **Swarm ignora `depends_on`** (es una dependencia de Compose, no de Swarm) | `restart_policy: any` + `max_attempts: 0`: las réplicas que arrancan antes que MySQL se re-crean hasta conectar |
| Las 3 réplicas facturaban la misma orden | Cada réplica se suscribía al tópico sin grupo | Suscripción compartida `$share/facturacion/...` + `clientId` único |
| `docker service logs` mezcla las 3 instancias | Es el comportamiento normal (agrega los logs de todas las tareas) | Prefijo `api.N.<task>@nodo` de Swarm + campo `instancia=` del filtro |
| Riesgo: puerto 8080 ocupado | El stack de los laboratorios anteriores publica el mismo puerto | `01-levantar-cluster.sh` avisa; hay que hacer `docker compose down` en la raíz antes |
| No se podían distinguir las réplicas | Misma imagen, mismo código | Header `X-Instancia` + log `[REQ] ... instancia=` |
| Rutas de `configs` | `docker stack deploy` lee los `configs` del disco de quien lo ejecuta y resuelve `file:` **relativo a la carpeta del compose** (no al directorio actual). Con `file: ../schema.sql` el stack depende de dónde se extraiga el zip. | `schema.sql` y `mosquitto.conf` se copian junto al `docker-compose.yml` y se referencian como `./...`: el stack es autocontenido y funciona desde cualquier carpeta. |
| Fin de línea de los scripts | Un editor Windows puede guardarlos con CRLF y bash falla | Se guardan con **LF** y se ejecutan con Git Bash |
| Deploy inmediatamente después de `stack rm` | `docker stack rm` es **asíncrono**: la red overlay se termina de borrar después de los servicios y el nuevo deploy falla con `network ... not found` | `03-bajar-cluster.sh` espera a que desaparezca la red; `01-levantar-cluster.sh` reintenta el deploy hasta 3 veces (detectado y corregido durante la validación) |

---

## 10. Conclusiones

- **Docker Swarm cumple** el objetivo del laboratorio: 3 instancias de la misma imagen, ejecutadas en
  paralelo, con **balanceo de carga L4 integrado** y **auto-reparación**, sin necesidad de nginx.
- La validación en logs muestra que los `POST /api/ordenes` se reparten entre las 3 réplicas y que, al
  bajar instancias, el tráfico se redistribuye entre las que quedan **sin cambiar el cliente** (misma URL
  y puerto).
- El único punto de fallo que queda es la infraestructura compartida (MySQL, Mosquitto y el host). En un
  entorno real se resolvería con nodos reales, base de datos replicada y broker en cluster.
- Los dos ajustes al código (identificación de instancia y suscripción compartida de MQTT) fueron
  necesarios para **observar** el balanceo y para **evitar la facturación duplicada**, respectivamente.

---

## 11. Referencias

- Docker Docs — *Swarm mode overview*: https://docs.docker.com/engine/swarm/
- Docker Docs — *Swarm mode key concepts*: https://docs.docker.com/engine/swarm/key-concepts/
- Docker Docs — *Use Swarm mode routing mesh*: https://docs.docker.com/engine/swarm/ingress/
- Docker Docs — *Deploy a stack to a swarm*: https://docs.docker.com/engine/swarm/stack-deploy/
- Docker Docs — *Scale a service*: https://docs.docker.com/engine/swarm/swarm-tutorial/scale-service/
- Docker Docs — *Swarm mode admin guide / add nodes*: https://docs.docker.com/engine/swarm/admin_guide/
- Eclipse Mosquitto — *Shared subscriptions* (`$share/...`): https://mosquitto.org/man/mosquitto-conf-5.html
- Docker Docs — *Compose file `deploy` reference*: https://docs.docker.com/reference/compose-file/deploy/
