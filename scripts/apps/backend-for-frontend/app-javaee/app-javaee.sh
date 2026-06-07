#!/bin/bash
set -euo pipefail

# Cargar funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../commons/log.sh"
source "${SCRIPT_DIR}/../../../commons/get.sh"

MODULE_NAME="app-javaee"
LOG_MODULE_NAME="$MODULE_NAME"

# Cargar vars del perfil antes de inicializar el resto
PROFILE="$(set_with_fallback "PROFILE" "dev")"
load_env_vars "${PROFILE}" "${SCRIPT_DIR}"

# ============================================================================
# Variables con defaults alineados con docker-compose.yml
# Prioridad: 1) ENV_VAR_NAME, 2) VAR_NAME, 3) inline default
# ============================================================================
PROJECT_NAME="$(set_with_fallback "PROJECT_NAME" "banca")"
PROJECT_ARTIFACT_ID="$(set_with_fallback "PROJECT_ARTIFACT_ID" "banca")"

WILDFLY_IMAGE="$(set_with_fallback "WILDFLY_IMAGE" "wildfly-app")"
WILDFLY_CONTAINER_NAME="$(set_with_fallback "WILDFLY_CONTAINER_NAME" "banca-wildfly")"
MYSQL_CONTAINER_NAME="$(set_with_fallback "MYSQL_CONTAINER_NAME" "banca-mysql")"
NETWORK_NAME="$(set_with_fallback "NETWORK_NAME" "banca-network")"

APP_PORT="$(set_with_fallback "APP_PORT" "8080")"
MYSQL_PORT="$(set_with_fallback "MYSQL_PORT" "3306")"

MYSQL_DATABASE="$(set_with_fallback "MYSQL_DATABASE" "banca_db")"
MYSQL_USER="$(set_with_fallback "MYSQL_USER" "banca_user")"
MYSQL_PASSWORD="$(set_with_fallback "MYSQL_PASSWORD" "banca_pass123")"
MYSQL_ROOT_PASSWORD="$(set_with_fallback "MYSQL_ROOT_PASSWORD" "root123")"

WILDFLY_USER="$(set_with_fallback "WILDFLY_USER" "admin")"
WILDFLY_PASSWORD="$(set_with_fallback "WILDFLY_PASSWORD" "Admin123*")"

COMPOSE_PROFILE="$(set_with_fallback "COMPOSE_PROFILE" "dev")"

# Health check settings
HEALTH_CHECK_TIMEOUT="$(set_with_fallback "HEALTH_CHECK_TIMEOUT" "120")"
HEALTH_CHECK_INTERVAL="$(set_with_fallback "HEALTH_CHECK_INTERVAL" "5")"

# ============================================================================
# Rutas fijas del proyecto
# ============================================================================

# Docker Compose file: from script dir → project root → infra/
#   SCRIPT_DIR = scripts/apps/backend-for-frontend/app-javaee/
#   ../../../../ → project root
DOCKER_COMPOSE_FILE="$(cd "${SCRIPT_DIR}/../../../../infra/apps/backend-for-frontend/app-javaee" && pwd)/docker-compose.yml"

# Project source directory for Maven builds
PROJECT_SRC_DIR="$(cd "${SCRIPT_DIR}/../../../../apps/backend-for-frontend/app-javaee" && pwd)"

# Servicios definidos en docker-compose.yml
WILDFLY_SERVICE="wildfly-app"
MYSQL_SERVICE="mysql-db"

# ============================================================================
# Funciones de utilidad
# ============================================================================

# Mostrar ayuda
show_usage() {
  echo "Usage: $0 {build|start|stop|restart|status|logs|app-logs|rebuild|delete|remove|deploy|db-shell|app-shell} [-p|--profile <profile>]"
  echo ""
  echo "Commands:"
  echo "  build       - Rebuild the WildFly Docker image"
  echo "  start       - Start all containers via docker-compose"
  echo "  stop        - Stop all containers"
  echo "  restart     - Stop + start containers"
  echo "  status      - Show container status"
  echo "  logs        - Show WildFly container logs (stdout, optional: service name)"
  echo "  app-logs    - Tail application log (server.log) from within the container"
  echo "  rebuild     - Build image then recreate containers"
  echo "  delete      - Remove containers only (preserves volumes/data)"
  echo "  remove      - Remove all containers, volumes, and network (DESTRUCTIVE)"
  echo "  deploy      - Rebuild EAR with Maven and copy to running WildFly container"
  echo "  db-shell    - Open MySQL CLI inside the mysql container"
  echo "  app-shell   - Open bash inside the WildFly container"
  echo ""
  echo "Options:"
  echo "  -p, --profile   - Profile to use (dev, staging, prod). Default: dev"
  echo "  -h, --help      - Show this help"
  echo ""
  echo "Environment Variables:"
  echo "  PROJECT_NAME           - Project name. Default: banca"
  echo "  PROJECT_ARTIFACT_ID    - Artifact ID / context path. Default: banca"
  echo "  WILDFLY_IMAGE          - WildFly Docker image name. Default: wildfly-app"
  echo "  WILDFLY_CONTAINER_NAME - WildFly container name. Default: banca-wildfly"
  echo "  MYSQL_CONTAINER_NAME   - MySQL container name. Default: banca-mysql"
  echo "  NETWORK_NAME           - Docker network name. Default: banca-network"
  echo "  APP_PORT               - Application HTTP port. Default: 8080"
  echo "  MYSQL_PORT             - MySQL port. Default: 3306"
  echo "  MYSQL_DATABASE         - MySQL database name. Default: banca_db"
  echo "  MYSQL_USER             - MySQL user. Default: banca_user"
  echo "  MYSQL_PASSWORD         - MySQL password. Default: banca_pass123"
  echo "  MYSQL_ROOT_PASSWORD    - MySQL root password. Default: root123"
  echo "  WILDFLY_USER           - WildFly admin user. Default: admin"
  echo "  WILDFLY_PASSWORD       - WildFly admin password. Default: Admin123*"
  echo "  COMPOSE_PROFILE        - Docker Compose profile. Default: dev"
  echo "  HEALTH_CHECK_TIMEOUT   - Health check timeout in seconds. Default: 120"
  echo "  HEALTH_CHECK_INTERVAL  - Health check interval in seconds. Default: 5"
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

# Esperar a que la aplicación responda con HTTP 200
wait_for_app() {
  local timeout="${HEALTH_CHECK_TIMEOUT}"
  local elapsed=0
  local health_url="http://localhost:${APP_PORT}/${PROJECT_ARTIFACT_ID}/login"

  log "INFO" "Waiting for application to be ready at ${health_url} (timeout: ${timeout}s)..."

  while [[ $elapsed -lt $timeout ]]; do
    if curl -sf "${health_url}" > /dev/null 2>&1; then
      log "SUCCESS" "Application is ready!"
      return 0
    fi

    if ! container_running "${WILDFLY_CONTAINER_NAME}"; then
      log "ERROR" "WildFly container is not running. Check logs with: $0 logs"
      return 1
    fi

    log "DEBUG" "Waiting for application... (${elapsed}s elapsed)"
    sleep "${HEALTH_CHECK_INTERVAL}"
    elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
  done

  log "ERROR" "Timeout waiting for application to be ready (${timeout}s)"
  log "INFO" "Check application logs with: $0 logs"
  return 1
}

# ============================================================================
# Comandos principales
# ============================================================================

# Build Docker image
build_image() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Building WildFly Docker image: ${WILDFLY_IMAGE}"
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" build

  log "SUCCESS" "Docker image built successfully!"
}

# Start containers
start_containers() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Starting WildFly + MySQL containers..."
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILE" up -d "$WILDFLY_SERVICE" "$MYSQL_SERVICE"

  if ! wait_for_app; then
    log "ERROR" "Application did not become ready in time"
    log "INFO" "Container logs: $0 logs $WILDFLY_SERVICE"
    log "INFO" "Database shell: $0 db-shell"
    exit 1
  fi

  log "SUCCESS" "All containers started successfully!"
  show_status
}

# Stop containers
stop_containers() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Stopping WildFly + MySQL containers..."
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" down

  log "SUCCESS" "All containers stopped"
}

# Restart containers
restart_containers() {
  log "INFO" "Restarting WildFly + MySQL containers..."
  stop_containers
  sleep 2
  start_containers
}

# Show container status
show_status() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Container Status:"
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILE" ps
}

# Show logs
show_logs() {
  local service="${1:-$WILDFLY_SERVICE}"
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Showing logs for service: ${service} (Ctrl+C to exit)"
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILE" logs -f "$service"
}

# Tail application log (server.log) from inside the container
show_app_logs() {
  check_docker

  if ! container_running "$WILDFLY_CONTAINER_NAME"; then
    log "ERROR" "WildFly container is not running"
    exit 1
  fi

  log "INFO" "Tailing application log from ${WILDFLY_CONTAINER_NAME} (Ctrl+C to exit)..."
  docker exec -ti "$WILDFLY_CONTAINER_NAME" tail -f /opt/jboss/wildfly/standalone/log/server.log
}

# Rebuild (build image + recreate containers)
rebuild_containers() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Rebuilding WildFly image and recreating containers..."
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" build
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILE" up -d "$WILDFLY_SERVICE" "$MYSQL_SERVICE"

  if ! wait_for_app; then
    log "ERROR" "Application did not become ready in time after rebuild"
    exit 1
  fi

  log "SUCCESS" "Rebuild complete!"
  show_status
}

# Delete containers only (keep volumes)
delete_containers() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "INFO" "Deleting application containers..."
  log "INFO" "Volumes will be preserved."

  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILE" down --remove-orphans

  log "SUCCESS" "Containers deleted (volumes preserved)"
}

# Remove all (containers, volumes, network) — DESTRUCTIVE
remove_all() {
  check_docker
  check_compose_file

  local compose_cmd
  compose_cmd=$(detect_docker_compose)

  log "WARN" "=========================================="
  log "WARN" "WARNING: DESTRUCTIVE OPERATION"
  log "WARN" "=========================================="
  log "WARN" "This will COMPLETELY REMOVE:"
  log "WARN" "  - All application containers"
  log "WARN" "  - All volumes (database data, logs)"
  log "WARN" "  - All data will be PERMANENTLY DELETED"
  log "WARN" "=========================================="
  echo ""
  read -p "Type 'yes' to confirm removal: " confirm

  if [[ "$confirm" != "yes" ]]; then
    log "INFO" "Removal cancelled"
    return 0
  fi

  log "INFO" "Removing all containers, volumes, and networks..."
  $compose_cmd -f "$DOCKER_COMPOSE_FILE" --profile "$COMPOSE_PROFILE" down -v --remove-orphans

  # Additional cleanup: remove the network if it exists and is not used
  if docker network inspect "$NETWORK_NAME" &>/dev/null; then
    log "INFO" "Removing network $NETWORK_NAME..."
    docker network rm "$NETWORK_NAME" 2>/dev/null || log "WARN" "Could not remove $NETWORK_NAME (may be in use by other containers)"
  fi

  log "SUCCESS" "Application infrastructure completely removed!"
  log "WARN" "All data has been permanently deleted."
}

# Deploy — rebuild EAR with Maven and copy to running WildFly container
deploy_app() {
  check_docker

  if ! container_running "${WILDFLY_CONTAINER_NAME}"; then
    log "ERROR" "WildFly container '${WILDFLY_CONTAINER_NAME}' is not running"
    log "INFO" "Start the application first with: $0 start"
    exit 1
  fi

  if [[ ! -d "$PROJECT_SRC_DIR" ]]; then
    log "ERROR" "Project source directory not found: $PROJECT_SRC_DIR"
    exit 1
  fi

  log "INFO" "Building EAR with Maven (Java 8)..."
  log "INFO" "Project directory: $PROJECT_SRC_DIR"

  # Maven build
  if ! (cd "$PROJECT_SRC_DIR" && mvn clean package -DskipTests); then
    log "ERROR" "Maven build failed"
    exit 1
  fi

  # Locate the generated EAR file
  local ear_file
  ear_file=$(find "$PROJECT_SRC_DIR/banca-ear/target" -name "*.ear" -type f 2>/dev/null | head -1)

  if [[ -z "$ear_file" ]]; then
    log "ERROR" "EAR file not found after build"
    log "INFO" "Expected in: $PROJECT_SRC_DIR/banca-ear/target/"
    exit 1
  fi

  log "INFO" "EAR file found: ${ear_file}"

  # Copy EAR to WildFly deployments
  log "INFO" "Deploying EAR to WildFly container '${WILDFLY_CONTAINER_NAME}'..."
  if docker cp "$ear_file" "${WILDFLY_CONTAINER_NAME}:/opt/jboss/wildfly/standalone/deployments/"; then
    log "SUCCESS" "EAR deployed successfully!"
    log "INFO" "WildFly will auto-deploy the new EAR. Check progress with: $0 logs"
  else
    log "ERROR" "Failed to copy EAR to WildFly container"
    exit 1
  fi
}

# Open MySQL CLI inside the mysql container
db_shell() {
  check_docker

  if ! container_running "${MYSQL_CONTAINER_NAME}"; then
    log "ERROR" "MySQL container '${MYSQL_CONTAINER_NAME}' is not running"
    log "INFO" "Start the application first with: $0 start"
    exit 1
  fi

  log "INFO" "Opening MySQL CLI (database: ${MYSQL_DATABASE}, user: ${MYSQL_USER})..."
  log "INFO" "Exit with: exit"
  echo ""
  docker exec -it "${MYSQL_CONTAINER_NAME}" mysql \
    -u"${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    "${MYSQL_DATABASE}"
}

# Open bash inside the WildFly container
app_shell() {
  check_docker

  if ! container_running "${WILDFLY_CONTAINER_NAME}"; then
    log "ERROR" "WildFly container '${WILDFLY_CONTAINER_NAME}' is not running"
    log "INFO" "Start the application first with: $0 start"
    exit 1
  fi

  log "INFO" "Opening bash shell in WildFly container '${WILDFLY_CONTAINER_NAME}'..."
  log "INFO" "Exit with: exit"
  echo ""
  docker exec -it "${WILDFLY_CONTAINER_NAME}" bash
}

# ============================================================================
# Configuración y parseo de argumentos
# ============================================================================

# Parseo de argumentos
SERVICE_FILTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile)
      PROFILE="$2"
      shift 2
      load_env_vars "${PROFILE}" "${SCRIPT_DIR}"
      ;;
    build|start|stop|restart|status|logs|app-logs|rebuild|delete|remove|deploy|db-shell|app-shell)
      COMMAND="$1"
      shift
      if [[ "$COMMAND" == "logs" ]]; then
        SERVICE_FILTER="${1:-}"
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
  build)
    build_image
    ;;
  start)
    start_containers
    ;;
  stop)
    stop_containers
    ;;
  restart)
    restart_containers
    ;;
  status)
    show_status
    ;;
  logs)
    show_logs "$SERVICE_FILTER"
    ;;
  app-logs)
    show_app_logs
    ;;
  rebuild)
    rebuild_containers
    ;;
  delete)
    delete_containers
    ;;
  remove)
    remove_all
    ;;
  deploy)
    deploy_app
    ;;
  db-shell)
    db_shell
    ;;
  app-shell)
    app_shell
    ;;
  *)
    log "ERROR" "Unknown command: $COMMAND"
    show_usage
    exit 1
    ;;
esac
