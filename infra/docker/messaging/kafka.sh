#!/bin/bash
set -euo pipefail

# Cargar funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/commons/log.sh"
source "${SCRIPT_DIR}/../../../scripts/commons/get.sh"

MODULE_NAME="kafka-infra"
LOG_MODULE_NAME="$MODULE_NAME"

# ============================================================================
# Funciones de utilidad
# ============================================================================

# Mostrar ayuda
show_usage() {
  echo "Usage: $0 {start|stop|restart|status|logs|create-topics|list-topics|describe-topic <name>|consumer-groups|delete|remove} [-p|--profile <profile>] [-m|--mode <kraft|zookeeper>]"
  echo ""
  echo "Commands:"
  echo "  start           - Start Kafka containers (KRaft mode by default)"
  echo "  stop            - Stop Kafka containers"
  echo "  restart         - Restart Kafka containers"
  echo "  status          - Show container status"
  echo "  logs            - Display Kafka broker logs"
  echo "  create-topics   - Create required topics"
  echo "  list-topics     - List available topics"
  echo "  describe-topic  - Describe a specific topic"
  echo "  consumer-groups - Show consumer groups"
  echo "  delete          - Delete containers only (preserves volumes/data)"
  echo "  remove          - Remove all containers, volumes, and networks (DESTRUCTIVE)"
  echo ""
  echo "Options:"
  echo "  -p, --profile   - Profile to use (dev, staging, prod). Default: dev"
  echo "  -m, --mode      - Kafka mode: 'kraft' (default, no Zookeeper) or 'zookeeper' (legacy)"
  echo ""
  echo "Environment Variables:"
  echo "  KAFKA_MODE            - Kafka mode (kraft|zookeeper). Default: kraft"
  echo "  KAFKA_CONTAINER       - Kafka container name. Default: geniahr-kafka"
  echo "  KAFKA_BROKER          - Kafka broker address. Default: localhost:9092"
  echo "  HEALTH_CHECK_TIMEOUT  - Health check timeout in seconds. Default: 120"
  echo "  HEALTH_CHECK_INTERVAL - Health check interval in seconds. Default: 5"
}

# Detectar comando docker compose (v2) o docker-compose (v1)
detect_docker_compose() {
  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo "docker compose"
  elif command -v docker-compose &>/dev/null; then
    echo "docker-compose"
  else
    log "ERROR" "Neither 'docker compose' nor 'docker-compose' found. Please install Docker Compose."
    exit 1
  fi
}

# Verificar que Docker esté corriendo
check_docker() {
  if ! docker ps &>/dev/null; then
    log "ERROR" "Docker daemon is not running"
    exit 1
  fi
}

# Verificar que el archivo docker-compose.yml existe
check_compose_file() {
  if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
    log "ERROR" "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
    exit 1
  fi
  log "DEBUG" "Using Docker Compose file: $DOCKER_COMPOSE_FILE"
}

# Verificar si el contenedor existe
container_exists() {
  local container_name="$1"
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"
}

# Verificar si el contenedor está corriendo
container_running() {
  local container_name="$1"
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"
}

# Esperar a que Kafka esté listo usando health check robusto
wait_for_kafka() {
  local timeout="${1:-$HEALTH_CHECK_TIMEOUT}"
  local elapsed=0

  log "INFO" "Waiting for Kafka broker to be ready (mode: $KAFKA_MODE, timeout: ${timeout}s)..."

  while [[ $elapsed -lt $timeout ]]; do
    if docker exec "$KAFKA_CONTAINER" kafka-broker-api-versions \
      --bootstrap-server "$KAFKA_INTERNAL_BROKER" &>/dev/null 2>&1; then
      log "SUCCESS" "Kafka broker is ready!"
      return 0
    fi

    if ! container_running "$KAFKA_CONTAINER"; then
      log "ERROR" "Kafka container is not running. Check logs with: $0 logs"
      return 1
    fi

    log "DEBUG" "Waiting for Kafka... (${elapsed}s elapsed)"
    sleep "$HEALTH_CHECK_INTERVAL"
    elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
  done

  log "ERROR" "Timeout waiting for Kafka broker to be ready (${timeout}s)"
  log "INFO" "Check Kafka logs with: $0 logs"
  return 1
}

# Verificar que Kafka esté listo (sin espera)
check_kafka_ready() {
  if ! container_running "$KAFKA_CONTAINER"; then
    log "ERROR" "Kafka container is not running"
    return 1
  fi

  if ! docker exec "$KAFKA_CONTAINER" kafka-broker-api-versions \
    --bootstrap-server "$KAFKA_INTERNAL_BROKER" &>/dev/null 2>&1; then
    log "ERROR" "Kafka broker is not ready"
    return 1
  fi

  return 0
}

# Start Kafka
start_kafka() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Starting Kafka infrastructure using: $compose_cmd (mode: $KAFKA_MODE)"

  if [[ "$KAFKA_MODE" == "zookeeper" ]]; then
    log "INFO" "Starting Zookeeper and Kafka (legacy mode)..."
    $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILES" up -d "$ZOOKEEPER_SERVICE" "$KAFKA_SERVICE"
  else
    log "INFO" "Starting Kafka in KRaft mode (no Zookeeper)..."
    $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILES" up -d "$KAFKA_SERVICE"
  fi

  if ! wait_for_kafka; then
    log "ERROR" "Failed to start Kafka infrastructure"
    exit 1
  fi

  log "INFO" "Running Kafka init container to create topics..."
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILES" up "$KAFKA_INIT_SERVICE" || {
    log "WARN" "Kafka init container failed, but Kafka broker is running"
  }

  log "SUCCESS" "Kafka infrastructure started successfully!"
  show_status
}

# Stop Kafka
stop_kafka() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Stopping Kafka infrastructure (mode: $KAFKA_MODE)..."
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILES" down

  log "SUCCESS" "Kafka infrastructure stopped"
}

# Remove Kafka completely (containers, volumes, networks)
remove_kafka() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "WARN" "Removing Kafka infrastructure completely (mode: $KAFKA_MODE)..."
  log "WARN" "This will delete: containers, volumes (data), and networks!"

  read -p "Are you sure? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    log "INFO" "Removal cancelled"
    return 0
  fi

  log "INFO" "Removing containers, volumes, and networks..."
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile kraft --profile zookeeper down -v --remove-orphans

  log "INFO" "Cleaning up unused volumes..."
  docker volume prune -f 2>/dev/null || true

  log "SUCCESS" "Kafka infrastructure removed completely!"
  log "INFO" "All data has been deleted."
}

# Delete Kafka containers only (keep volumes)
delete_kafka() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Deleting Kafka containers (mode: $KAFKA_MODE)..."
  log "INFO" "Volumes will be preserved."

  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile kraft --profile zookeeper down --remove-orphans

  log "SUCCESS" "Kafka containers deleted (volumes preserved)"
}

# Remove Kafka completely (containers, volumes, network)
remove_kafka() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "WARN" "=========================================="
  log "WARN" "WARNING: DESTRUCTIVE OPERATION"
  log "WARN" "=========================================="
  log "WARN" "This will COMPLETELY REMOVE:"
  log "WARN" "  - All Kafka containers"
  log "WARN" "  - All volumes (kafka_data, zookeeper_data, zookeeper_logs)"
  log "WARN" "  - All data will be PERMANENTLY DELETED"
  log "WARN" "=========================================="
  echo ""
  read -p "Type 'yes' to confirm removal: " confirm

  if [[ "$confirm" != "yes" ]]; then
    log "INFO" "Removal cancelled"
    return 0
  fi

  log "INFO" "Removing Kafka infrastructure completely..."

  # Use docker compose down with -v to remove volumes
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile kraft --profile zookeeper down -v --remove-orphans

  # Additional cleanup: remove the geniahr-network if it exists and is not used
  if docker network inspect geniahr-network &>/dev/null; then
    log "INFO" "Removing geniahr-network..."
    docker network rm geniahr-network 2>/dev/null || log "WARN" "Could not remove geniahr-network (may be in use)"
  fi

  log "SUCCESS" "Kafka infrastructure completely removed!"
  log "WARN" "All data has been permanently deleted."
}

# Restart Kafka
restart_kafka() {
  log "INFO" "Restarting Kafka infrastructure..."
  stop_kafka
  sleep 2
  start_kafka
}

# Show status
show_status() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Kafka Container Status (mode: $KAFKA_MODE):"
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILES" ps
}

# Show logs
show_logs() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Kafka Broker Logs (Ctrl+C to exit):"
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILES" logs -f "$KAFKA_SERVICE"
}

# Create topics
create_topics() {
  check_docker

  if ! check_kafka_ready; then
    exit 1
  fi

  log "INFO" "Creating topic: requirements.active"

  if docker exec "$KAFKA_CONTAINER" kafka-topics --create \
    --topic requirements.active \
    --bootstrap-server "$KAFKA_INTERNAL_BROKER" \
    --partitions 1 \
    --replication-factor 1 \
    --config retention.ms=604800000 \
    --config segment.ms=86400000 \
    --if-not-exists &>/dev/null; then
    log "SUCCESS" "Topic 'requirements.active' created or already exists"
  else
    log "ERROR" "Failed to create topic 'requirements.active'"
    exit 1
  fi

  log "INFO" "Available topics:"
  docker exec "$KAFKA_CONTAINER" kafka-topics --list \
    --bootstrap-server "$KAFKA_INTERNAL_BROKER"
}

# List topics
list_topics() {
  check_docker

  if ! check_kafka_ready; then
    exit 1
  fi

  log "INFO" "Available topics:"
  docker exec "$KAFKA_CONTAINER" kafka-topics --list \
    --bootstrap-server "$KAFKA_INTERNAL_BROKER"
}

# Describe topic
describe_topic() {
  local topic="$1"
  check_docker

  if [[ -z "$topic" ]]; then
    log "ERROR" "Topic name required for describe command"
    exit 1
  fi

  if ! check_kafka_ready; then
    exit 1
  fi

  log "INFO" "Topic details for: $topic"
  docker exec "$KAFKA_CONTAINER" kafka-topics --describe \
    --topic "$topic" \
    --bootstrap-server "$KAFKA_INTERNAL_BROKER"
}

# Show consumer group status
consumer_groups() {
  check_docker

  if ! check_kafka_ready; then
    exit 1
  fi

  log "INFO" "Consumer groups:"
  docker exec "$KAFKA_CONTAINER" kafka-consumer-groups --list \
    --bootstrap-server "$KAFKA_INTERNAL_BROKER"
}

# ============================================================================
# Configuración y parseo de argumentos
# ============================================================================

# Configuración por defecto
PROFILE="${PROFILE:-dev}"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Kafka mode: 'kraft' (default, no Zookeeper) or 'zookeeper' (legacy)
KAFKA_MODE="${KAFKA_MODE:-kraft}"

# Container and service names based on mode
if [[ "$KAFKA_MODE" == "zookeeper" ]]; then
  KAFKA_CONTAINER="geniahr-kafka"
  KAFKA_SERVICE="kafka-zookeeper"
  KAFKA_INIT_SERVICE="kafka-init-zookeeper"
  KAFKA_BROKER="localhost:9092"
  KAFKA_INTERNAL_BROKER="kafka-zookeeper:29092"
  COMPOSE_PROFILES="zookeeper"
  ZOOKEEPER_SERVICE="zookeeper"
else
  KAFKA_CONTAINER="geniahr-kafka"
  KAFKA_SERVICE="kafka-kraft"
  KAFKA_INIT_SERVICE="kafka-init-kraft"
  KAFKA_BROKER="localhost:9092"
  KAFKA_INTERNAL_BROKER="kafka-kraft:29092"
  COMPOSE_PROFILES="kraft"
fi

HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-120}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-5}"

# Parseo de argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile)
      PROFILE="$2"
      shift 2
      ;;
    -m|--mode)
      KAFKA_MODE="$2"
      shift 2
      ;;
    start|stop|delete|remove|restart|status|logs|create-topics|list-topics|describe-topic|consumer-groups)
      COMMAND="$1"
      shift
      if [[ "$COMMAND" == "describe-topic" ]]; then
        TOPIC_NAME="${1:-}"
        shift 2>/dev/null || true
      fi
      break
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      log "ERROR" "Argumento desconocido: $1"
      show_usage
      exit 1
      ;;
  esac
done

# ============================================================================
# Main - ejecutar comando
# ============================================================================

if [[ -z "${COMMAND:-}" ]]; then
  show_usage
  exit 1
fi

case "$COMMAND" in
  start)
    start_kafka
    ;;
  stop)
    stop_kafka
    ;;
  delete)
    delete_kafka
    ;;
  remove)
    remove_kafka
    ;;
  restart)
    restart_kafka
    ;;
  status)
    show_status
    ;;
  logs)
    show_logs
    ;;
  create-topics)
    create_topics
    ;;
  list-topics)
    list_topics
    ;;
  describe-topic)
    describe_topic "$TOPIC_NAME"
    ;;
  consumer-groups)
    consumer_groups
    ;;
  *)
    log "ERROR" "Unknown command: $COMMAND"
    show_usage
    exit 1
    ;;
esac
