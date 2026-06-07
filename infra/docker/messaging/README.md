# Kafka Messaging Infrastructure

Esta carpeta contiene la configuración de Docker para la infraestructura de mensajería basada en Apache Kafka.

## Requisitos

- Docker & Docker Compose 3.8+
- 2GB RAM disponible (mínimo)
- Puertos 2181 (Zookeeper), 9092 (Kafka) disponibles

## Inicio Rápido

### 1. Iniciar Kafka

```bash
../../scripts/docker/messaging/kafka.sh start
```

Este comando:
- ✅ Inicia Zookeeper
- ✅ Inicia el broker Kafka
- ✅ Crea los tópicos necesarios
- ✅ Valida la salud de los servicios

### 2. Verificar estado

```bash
../../scripts/docker/messaging/kafka.sh status
```

Output esperado:
```
geniahr-zookeeper   Up   2181/tcp
geniahr-kafka       Up   9092/tcp, 29092/tcp
```

### 3. Ver logs en tiempo real

```bash
../../scripts/docker/messaging/kafka.sh logs
```

### 4. Listar tópicos disponibles

```bash
../../scripts/docker/messaging/kafka.sh list-topics
```

Output esperado:
```
requirements.active
```

## Comandos Disponibles

### manage-kafka.sh

```bash
# Iniciar servicios
../../scripts/docker/messaging/kafka.sh start

# Detener servicios
../../scripts/docker/messaging/kafka.sh stop

# Reiniciar servicios
../../scripts/docker/messaging/kafka.sh restart

# Ver estado de containers
../../scripts/docker/messaging/kafka.sh status

# Ver logs de Kafka broker
../../scripts/docker/messaging/kafka.sh logs

# Crear tópicos
../../scripts/docker/messaging/kafka.sh create-topics

# Listar tópicos
../../scripts/docker/messaging/kafka.sh list-topics

# Describir un tópico específico
../../scripts/docker/messaging/kafka.sh describe-topic requirements.active

# Ver consumer groups
../../scripts/docker/messaging/kafka.sh consumer-groups
```

## Arquitectura

### Servicios

#### Zookeeper (geniahr-zookeeper)
- **Puerto**: 2181
- **Imagen**: confluentinc/cp-zookeeper:7.8.1
- **Volumen**: zookeeper_data, zookeeper_logs
- **Rol**: Coordinador de cluster Kafka

#### Kafka Broker (geniahr-kafka)
- **Puerto**: 9092 (host), 29092 (interno)
- **Imagen**: confluentinc/cp-kafka:7.8.1
- **Volumen**: kafka_data
- **Rol**: Broker principal

#### Kafka Init (geniahr-kafka-init)
- **Imagen**: confluentinc/cp-kafka:7.8.1
- **Rol**: Inicialización de tópicos (one-shot)

### Tópicos

#### requirements.active
- **Particiones**: 1
- **Replication Factor**: 1
- **Retention**: 7 días
- **Propósito**: Mensajes de requerimientos en estado "Active"
- **Schema**: JSON (Requirement object)

## Conexión desde Aplicaciones

### Desde localhost (desarrollo)

```properties
kafka.bootstrap.servers=localhost:9092
```

### Desde dentro de Docker (red bridge)

```properties
kafka.bootstrap.servers=geniahr-kafka:29092
```

### Variables de Entorno

```bash
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
# o
export KAFKA_BOOTSTRAP_SERVERS=geniahr-kafka:29092  # Si está en Docker Compose
```

## Volúmenes Persistentes

Los datos se persisten en volúmenes Docker locales:

```
zookeeper_data:       /var/lib/zookeeper/data
zookeeper_logs:       /var/lib/zookeeper/log
kafka_data:           /var/lib/kafka/data
```

Para limpiar:

```bash
# Ver volúmenes
docker volume ls | grep geniahr

# Eliminar volúmenes (CUIDADO: se pierden los datos)
docker volume rm messaging_zookeeper_data messaging_zookeeper_logs messaging_kafka_data
```

## Health Checks

### Zookeeper

```bash
docker exec geniahr-zookeeper echo ruok | nc localhost 2181
# Output: imok (si está sano)
```

### Kafka

```bash
docker exec geniahr-kafka kafka-broker-api-versions.sh --bootstrap-server localhost:9092
# Output: ApiVersion details (si está sano)
```

## Testing

### Enviar mensaje de prueba

```bash
docker exec geniahr-kafka kafka-console-producer.sh \
  --broker-list localhost:9092 \
  --topic requirements.active \
  --property "parse.key=true" \
  --property "key.separator=:"
```

Luego escribir:
```
uuid-123:{"id":"uuid-123","title":"Senior Java Developer","department":"Engineering"}
Ctrl+C para terminar
```

### Consumir mensajes de prueba

```bash
docker exec geniahr-kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic requirements.active \
  --from-beginning
```

## Performance

### Configuración actual

| Parámetro | Valor | Descripción |
|-----------|-------|------------|
| Acks | all | Garantía máxima de entrega |
| Retries | 3 | Reintentos en caso de error |
| Batch Size | 16KB | Tamaño de lote de mensajes |
| Linger MS | 10 | Espera máxima para lote |
| Compression | snappy | Compresión de payload |
| Retention | 7 días | Tiempo de retención |

### Monitoreo

```bash
# Ver métricas de Kafka
docker exec geniahr-kafka kafka-metrics-reporter.sh \
  --bootstrap-server localhost:9092 \
  --group recruitment-api-consumer \
  --describe
```

## Troubleshooting

### "Connection refused" a Kafka

```bash
# Verificar que container está corriendo
docker ps | grep geniahr-kafka

# Reiniciar
../../scripts/docker/messaging/kafka.sh restart

# Ver logs de error
docker logs geniahr-kafka
```

### Tópico no existe

```bash
# Recrear tópicos
../../scripts/docker/messaging/kafka.sh create-topics

# Verificar
../../scripts/docker/messaging/kafka.sh list-topics
```

### Messages que no se procesan

```bash
# Ver consumer groups y lag
../../scripts/docker/messaging/kafka.sh consumer-groups

# Reset consumer group (CUIDADO: reprocessa todos los mensajes)
docker exec geniahr-kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group recruitment-api-consumer \
  --reset-offsets \
  --to-earliest \
  --execute
```

### Limpiar todo y comenzar de nuevo

```bash
# Parar
../../scripts/docker/messaging/kafka.sh stop

# Eliminar volúmenes (CUIDADO)
docker volume rm messaging_zookeeper_data messaging_zookeeper_logs messaging_kafka_data

# Iniciar de nuevo
../../scripts/docker/messaging/kafka.sh start
```

## Integración con Docker Compose de aplicaciones

Para que los microservicios se conecten a Kafka desde Docker Compose:

```yaml
# En docker-compose.yml del microservicio
services:
  recruitment-api:
    depends_on:
      - geniahr-kafka
    environment:
      KAFKA_BOOTSTRAP_SERVERS: geniahr-kafka:29092
    networks:
      - geniahr-network

networks:
  geniahr-network:
    driver: bridge
```

## Documentación Completa

Ver: [`docs/KAFKA_ARCHITECTURE.md`](../../docs/KAFKA_ARCHITECTURE.md)

## Referencias

- [Confluent Kafka Docker Images](https://hub.docker.com/r/confluentinc/cp-kafka)
- [Kafka CLI Tools](https://kafka.apache.org/quickstart)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
