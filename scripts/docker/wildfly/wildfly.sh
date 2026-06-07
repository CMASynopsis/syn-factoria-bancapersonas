#!/bin/bash
set -euo pipefail

# =============================================================================
# Wildfly + SSH Manager
# =============================================================================
# Gestiona el ciclo de vida de un contenedor Wildfly con SSH integrado,
# permitiendo despliegue automatizado via pipelines CI/CD (SCP + SSH).
#
# El pipeline .github/workflows/deploy-app-javaee.yml se conecta via SSH
# al puerto configurado (WILDFLY_SSH_PORT) para copiar y desplegar el .ear.
#
# Uso: ./scripts/docker/wildfly/wildfly.sh <comando> [-p|--profile <perfil>]
#
# Perfiles: dev (default), staging, prod
# =============================================================================

# ── SCRIPT_DIR con sufijo único (uuidv4{18}) — evitar colisiones ──
script_dir_d4e5f6a7b8c9d0e1f2a3() { echo "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"; }

# ── Cargar utilidades compartidas ──
source "$(script_dir_d4e5f6a7b8c9d0e1f2a3)/../../commons/log.sh"
source "$(script_dir_d4e5f6a7b8c9d0e1f2a3)/../../commons/get.sh"

MODULE_NAME="wildfly-manager"
LOG_MODULE_NAME="$MODULE_NAME"

# ============================================================================
# Configuración inicial (antes de parsear argumentos)
# ============================================================================

# Perfil por defecto
PROFILE="dev"

# Cargar vars del perfil antes de inicializar el resto
load_env_vars "${PROFILE}" "$(script_dir_d4e5f6a7b8c9d0e1f2a3)"

# ============================================================================
# Variables con defaults — Prioridad: ENV_VAR > VAR > profile.env > inline
# ============================================================================

# Imagen y contenedor
      WILDFLY_IMAGE="$(set_with_fallback "WILDFLY_IMAGE" "wildfly-ssh:26.1.2.Final")"
WILDFLY_CONTAINER_NAME="$(set_with_fallback "WILDFLY_CONTAINER_NAME" "geniahr-wildfly")"
NETWORK_NAME="$(set_with_fallback "NETWORK_NAME" "geniahr-network")"

# Puertos
WILDFLY_SSH_PORT="$(set_with_fallback "WILDFLY_SSH_PORT" "2222")"
WILDFLY_HTTP_PORT="$(set_with_fallback "WILDFLY_HTTP_PORT" "8080")"
WILDFLY_ADMIN_PORT="$(set_with_fallback "WILDFLY_ADMIN_PORT" "9990")"

# Usuario SSH
WILDFLY_DEPLOY_USER="$(set_with_fallback "WILDFLY_DEPLOY_USER" "deploy")"
WILDFLY_DEPLOY_PASSWORD="$(set_with_fallback "WILDFLY_DEPLOY_PASSWORD" "deploy")"
WILDFLY_SSH_PUBLIC_KEY="$(set_with_fallback "WILDFLY_SSH_PUBLIC_KEY" "")"

# Rutas dentro del contenedor
WILDFLY_HOME="$(set_with_fallback "WILDFLY_HOME" "/opt/jboss/wildfly")"
WILDFLY_DEPLOY_PATH="$(set_with_fallback "WILDFLY_DEPLOY_PATH" "${WILDFLY_HOME}/standalone/deployments")"

# JVM
WILDFLY_XMS="$(set_with_fallback "WILDFLY_XMS" "512m")"
WILDFLY_XMX="$(set_with_fallback "WILDFLY_XMX" "1024m")"
WILDFLY_JAVA_OPTS="$(set_with_fallback "WILDFLY_JAVA_OPTS" "")"

# Health checks
HEALTH_CHECK_TIMEOUT="$(set_with_fallback "HEALTH_CHECK_TIMEOUT" "120")"
HEALTH_CHECK_INTERVAL="$(set_with_fallback "HEALTH_CHECK_INTERVAL" "5")"
HEALTH_CHECK_URL="$(set_with_fallback "HEALTH_CHECK_URL" "http://localhost:${WILDFLY_HTTP_PORT}/")"

# Volúmenes montados desde el host (opcional)
WILDFLY_DEPLOYMENTS_HOST_DIR="$(set_with_fallback "WILDFLY_DEPLOYMENTS_HOST_DIR" "")"
WILDFLY_CONFIG_HOST_DIR="$(set_with_fallback "WILDFLY_CONFIG_HOST_DIR" "")"

# Dockerfile y rutas de build
DOCKERFILE_PATH="$(script_dir_d4e5f6a7b8c9d0e1f2a3)/../../../infra/docker/wildfly/Dockerfile"
ENTRYPOINT_PATH="$(script_dir_d4e5f6a7b8c9d0e1f2a3)/../../../infra/docker/wildfly/entrypoint.sh"

# ============================================================================
# Funciones auxiliares
# ============================================================================

# Mostrar ayuda
show_usage() {
  cat <<EOF
Uso: $(basename "$0") <comando> [opciones]

Comandos:
  start       Iniciar el contenedor Wildfly + SSH
  stop        Detener el contenedor
  restart     Reiniciar el contenedor
  status      Mostrar estado y puertos del contenedor
  logs        Mostrar logs de Wildfly (follow)
  ssh         Conectarse via SSH al contenedor
  build       Construir la imagen Docker
  remove      Eliminar el contenedor (con confirmacion)

Opciones:
  -p, --profile <perfil>  Perfil de configuracion (dev, staging, prod)
                            Por defecto: dev

Variables de entorno (prioridad: ENV_VAR > VAR > profile.env > default):
  WILDFLY_IMAGE            Imagen Docker                  Default: wildfly-ssh:26.1.2.Final
  WILDFLY_CONTAINER_NAME   Nombre del contenedor          Default: geniahr-wildfly
  WILDFLY_SSH_PORT         Puerto SSH (host)              Default: 2222
  WILDFLY_HTTP_PORT        Puerto HTTP (host)             Default: 8080
  WILDFLY_ADMIN_PORT       Puerto Admin (host)            Default: 9990
  WILDFLY_DEPLOY_USER      Usuario SSH para depliegues    Default: deploy
  WILDFLY_DEPLOY_PASSWORD  Password del usuario           Default: deploy
  WILDFLY_SSH_PUBLIC_KEY   Clave publica SSH              Default: (vacia)
  WILDFLY_DEPLOY_PATH      Ruta deployments (container)   Default: /opt/jboss/wildfly/standalone/deployments
  WILDFLY_XMS              Memoria XMS JVM                Default: 512m
  WILDFLY_XMX              Memoria XMX JVM                Default: 1024m
  NETWORK_NAME             Red Docker                     Default: geniahr-network
  HEALTH_CHECK_TIMEOUT     Timeout health check (seg)     Default: 120
  HEALTH_CHECK_INTERVAL    Intervalo health check (seg)   Default: 5
  WILDFLY_DEPLOYMENTS_HOST_DIR  Montar deployments host   Default: (vacio)
  WILDFLY_CONFIG_HOST_DIR       Montar config host        Default: (vacio)

Ejemplos:
  ./scripts/docker/wildfly/wildfly.sh start
  ./scripts/docker/wildfly/wildfly.sh start -p prod
  ./scripts/docker/wildfly/wildfly.sh build
  ./scripts/docker/wildfly/wildfly.sh ssh
  WILDFLY_SSH_PORT=2222 ./scripts/docker/wildfly/wildfly.sh start

Para configuracion persistente, crear <perfil>.env en este directorio.
EOF
}

# Verificar que Docker esté instalado y corriendo
check_docker() {
  if ! command -v docker &>/dev/null; then
    log "ERROR" "Docker no esta instalado. Instale Docker primero."
    exit 1
  fi
  if ! docker ps &>/dev/null; then
    log "ERROR" "Docker daemon no esta corriendo."
    exit 1
  fi
}

# Verificar si el contenedor existe (incluso si está detenido)
container_exists() {
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${WILDFLY_CONTAINER_NAME}$"
}

# Verificar si el contenedor está corriendo
container_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${WILDFLY_CONTAINER_NAME}$"
}

# Esperar a que Wildfly esté listo
wait_for_wildfly() {
  local timeout="${1:-$HEALTH_CHECK_TIMEOUT}"
  local elapsed=0
  local http_port="${WILDFLY_HTTP_PORT}"

  log "INFO" "Esperando que Wildfly este listo (timeout: ${timeout}s, puerto: ${http_port})..."

  while [[ $elapsed -lt $timeout ]]; do
    if curl -sf "${HEALTH_CHECK_URL}" &>/dev/null 2>&1; then
      log "SUCCESS" "Wildfly esta listo y respondiendo en http://localhost:${http_port}/"
      return 0
    fi

    if ! container_running; then
      log "ERROR" "El contenedor '${WILDFLY_CONTAINER_NAME}' no esta corriendo."
      log "INFO" "Revise los logs con: $(basename "$0") logs"
      return 1
    fi

    log "DEBUG" "Esperando a Wildfly... (${elapsed}s elapsed)"
    sleep "$HEALTH_CHECK_INTERVAL"
    elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
  done

  log "ERROR" "Timeout esperando a que Wildfly este listo (${timeout}s)"
  log "INFO" "Revise los logs con: $(basename "$0") logs"
  return 1
}

# Construir la imagen Docker
build_image() {
  check_docker

  local dockerfile="${DOCKERFILE_PATH}"
  local entrypoint="${ENTRYPOINT_PATH}"

  if [[ ! -f "$dockerfile" ]]; then
    log "ERROR" "Dockerfile no encontrado: $dockerfile"
    exit 1
  fi

  if [[ ! -f "$entrypoint" ]]; then
    log "ERROR" "entrypoint.sh no encontrado: $entrypoint"
    exit 1
  fi

  log "INFO" "Construyendo imagen Docker: ${WILDFLY_IMAGE}"
  log "INFO" "Dockerfile: ${dockerfile}"
  log "INFO" "Entrypoint: ${entrypoint}"

  docker build \
    --build-arg "WILDFLY_VERSION=26.1.2.Final" \
    --build-arg "DEPLOY_USER=${WILDFLY_DEPLOY_USER}" \
    --build-arg "DEPLOY_PASSWORD=${WILDFLY_DEPLOY_PASSWORD}" \
    -t "${WILDFLY_IMAGE}" \
    -f "${dockerfile}" \
    "$(dirname "$(dirname "$(dirname "$(script_dir_d4e5f6a7b8c9d0e1f2a3)")")")"

  log "SUCCESS" "Imagen '${WILDFLY_IMAGE}' construida correctamente."
}

# Crear la red Docker si no existe
ensure_network() {
  if ! docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${NETWORK_NAME}$"; then
    log "INFO" "Creando red Docker: ${NETWORK_NAME}"
    docker network create "${NETWORK_NAME}" 2>/dev/null || true
    log "SUCCESS" "Red '${NETWORK_NAME}' creada."
  fi
}

# Construir argumentos de volúmenes
build_volume_args() {
  local args=""

  # Montar directorio de deployments del host si está configurado
  if [[ -n "${WILDFLY_DEPLOYMENTS_HOST_DIR}" ]]; then
    local abs_deploy_dir
    abs_deploy_dir="$(realpath -m "${WILDFLY_DEPLOYMENTS_HOST_DIR}" 2>/dev/null || echo "${WILDFLY_DEPLOYMENTS_HOST_DIR}")"
    mkdir -p "${abs_deploy_dir}"
    args="${args} -v ${abs_deploy_dir}:${WILDFLY_DEPLOY_PATH}"
    log "DEBUG" "Montando deployments: ${abs_deploy_dir} -> ${WILDFLY_DEPLOY_PATH}"
  fi

  # Montar directorio de configuración del host si está configurado
  if [[ -n "${WILDFLY_CONFIG_HOST_DIR}" ]]; then
    local abs_config_dir
    abs_config_dir="$(realpath -m "${WILDFLY_CONFIG_HOST_DIR}" 2>/dev/null || echo "${WILDFLY_CONFIG_HOST_DIR}")"
    mkdir -p "${abs_config_dir}"
    args="${args} -v ${abs_config_dir}:${WILDFLY_HOME}/standalone/configuration"
    log "DEBUG" "Montando config: ${abs_config_dir} -> ${WILDFLY_HOME}/standalone/configuration"
  fi

  echo "${args}"
}

# Iniciar Wildfly
start_wildfly() {
  check_docker

  # Verificar si ya está corriendo
  if container_running; then
    log "WARN" "Wildfly ya esta corriendo (contenedor: ${WILDFLY_CONTAINER_NAME})"
    show_status
    return 0
  fi

  # Verificar si existe pero está detenido — lo arrancamos
  if container_exists; then
    log "INFO" "Iniciando contenedor existente: ${WILDFLY_CONTAINER_NAME}"
    docker start "${WILDFLY_CONTAINER_NAME}" > /dev/null
    if wait_for_wildfly; then
      log "SUCCESS" "Wildfly iniciado correctamente."
      show_status
    else
      log "ERROR" "Wildfly no respondio correctamente."
      exit 1
    fi
    return 0
  fi

  # Asegurar que la red existe
  ensure_network

  # Construir argumentos de ejecución
  local run_args=()

  # Nombre del contenedor
  run_args+=(--name "${WILDFLY_CONTAINER_NAME}")

  # Red
  run_args+=(--network "${NETWORK_NAME}")

  # Puertos
  run_args+=(-p "${WILDFLY_SSH_PORT}:22")
  run_args+=(-p "${WILDFLY_HTTP_PORT}:8080")
  run_args+=(-p "${WILDFLY_ADMIN_PORT}:9990")

  # Variables de entorno
  run_args+=(-e "WILDFLY_SSH_PUBLIC_KEY=${WILDFLY_SSH_PUBLIC_KEY}")
  run_args+=(-e "DEPLOY_USER=${WILDFLY_DEPLOY_USER}")
  run_args+=(-e "WILDFLY_SSH_PORT=22")

  # JVM options
  local java_opts="-Xms${WILDFLY_XMS} -Xmx${WILDFLY_XMX}"
  if [[ -n "${WILDFLY_JAVA_OPTS}" ]]; then
    java_opts="${java_opts} ${WILDFLY_JAVA_OPTS}"
  fi
  run_args+=(-e "JAVA_OPTS=${java_opts}")

  # Volúmenes
  local vol_args
  vol_args=$(build_volume_args)
  if [[ -n "${vol_args}" ]]; then
    # shellcheck disable=SC2086
    run_args+=(${vol_args})
  fi

  # Política de reinicio
  run_args+=(--restart unless-stopped)

  # Health check (basic via shell)
  run_args+=(--health-cmd="curl -sf http://localhost:8080/ || exit 1")
  run_args+=(--health-interval=30s)
  run_args+=(--health-timeout=10s)
  run_args+=(--health-retries=3)

  # Labels
  run_args+=(--label "app=geniahr-wildfly")
  run_args+=(--label "module=app-javaee")
  run_args+=(--label "managed-by=wildfly.sh")

  log "INFO" "Iniciando Wildfly + SSH (perfil: ${PROFILE})..."
  log "INFO" "  Imagen:     ${WILDFLY_IMAGE}"
  log "INFO" "  Contenedor: ${WILDFLY_CONTAINER_NAME}"
  log "INFO" "  SSH:        localhost:${WILDFLY_SSH_PORT}"
  log "INFO" "  HTTP:       localhost:${WILDFLY_HTTP_PORT}"
  log "INFO" "  Admin:      localhost:${WILDFLY_ADMIN_PORT}"
  log "INFO" "  Deploy:     ${WILDFLY_DEPLOY_PATH}"
  log "DEBUG" "  JAVA_OPTS:  ${java_opts}"

  # Ejecutar el contenedor
  docker run -d "${run_args[@]}" "${WILDFLY_IMAGE}" -b 0.0.0.0 -bmanagement 0.0.0.0

  # Esperar a que Wildfly esté listo
  if wait_for_wildfly; then
    log "SUCCESS" "Wildfly + SSH iniciado correctamente."
    show_status
  else
    log "ERROR" "Wildfly no respondio correctamente."
    log "INFO" "Revise los logs con: $(basename "$0") logs"
    exit 1
  fi
}

# Detener Wildfly
stop_wildfly() {
  check_docker

  if ! container_exists; then
    log "WARN" "No existe un contenedor '${WILDFLY_CONTAINER_NAME}'."
    return 0
  fi

  if ! container_running; then
    log "WARN" "Wildfly ya esta detenido (contenedor: ${WILDFLY_CONTAINER_NAME})"
    return 0
  fi

  log "INFO" "Deteniendo Wildfly (contenedor: ${WILDFLY_CONTAINER_NAME})..."
  docker stop "${WILDFLY_CONTAINER_NAME}" > /dev/null
  log "SUCCESS" "Wildfly detenido correctamente."
}

# Reiniciar Wildfly
restart_wildfly() {
  log "INFO" "Reiniciando Wildfly..."
  stop_wildfly
  sleep 2
  start_wildfly
}

# Mostrar estado
show_status() {
  check_docker

  if ! container_exists; then
    log "WARN" "No existe un contenedor '${WILDFLY_CONTAINER_NAME}'."
    log "INFO" "Puede iniciarlo con: $(basename "$0") start"
    return 0
  fi

  local running="false"
  if container_running; then
    running="true"
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Wildfly + SSH - Estado del Contenedor"
  echo "═══════════════════════════════════════════════════════════"
  echo "  Contenedor:     ${WILDFLY_CONTAINER_NAME}"
  echo "  Imagen:         ${WILDFLY_IMAGE}"
  echo "  Perfil:         ${PROFILE}"
  echo "  Estado:         $(docker ps -a --filter "name=${WILDFLY_CONTAINER_NAME}" --format '{{.Status}}' 2>/dev/null || echo 'N/A')"
  echo ""
  echo "  Puertos:"
  echo "    SSH (SCP):    localhost:${WILDFLY_SSH_PORT}"
  echo "    HTTP:         localhost:${WILDFLY_HTTP_PORT}"
  echo "    Admin:        localhost:${WILDFLY_ADMIN_PORT}"
  echo ""
  echo "  Deploy path:    ${WILDFLY_DEPLOY_PATH}"
  echo "  Usuario SSH:    ${WILDFLY_DEPLOY_USER}"
  echo ""

  if [[ "${running}" == "true" ]]; then
    local health
    health=$(docker inspect --format='{{.State.Health.Status}}' "${WILDFLY_CONTAINER_NAME}" 2>/dev/null || echo "N/A")
    echo "  Health:         ${health}"

    # Mostrar mapeo de puertos real
    echo ""
    echo "  Port Mapping:"
    docker port "${WILDFLY_CONTAINER_NAME}" 2>/dev/null | while read -r line; do
      echo "    ${line}"
    done
  fi
  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

# Mostrar logs
show_logs() {
  check_docker

  if ! container_exists; then
    log "ERROR" "No existe un contenedor '${WILDFLY_CONTAINER_NAME}'."
    log "INFO" "Puede iniciarlo con: $(basename "$0") start"
    exit 1
  fi

  log "INFO" "Mostrando logs de Wildfly (Ctrl+C para salir)..."
  echo "───────────────────────────────────────────────────────────"
  docker logs -f "${WILDFLY_CONTAINER_NAME}"
}

# Conectarse via SSH al contenedor
ssh_into_container() {
  check_docker

  if ! container_running; then
    log "ERROR" "Wildfly no esta corriendo. Inicielo primero con: $(basename "$0") start"
    exit 1
  fi

  log "INFO" "Conectando via SSH a localhost:${WILDFLY_SSH_PORT} (usuario: ${WILDFLY_DEPLOY_USER})..."
  log "INFO" "Nota: La primera vez debera aceptar la huella del host."
  echo ""

  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -p "${WILDFLY_SSH_PORT}" \
      "${WILDFLY_DEPLOY_USER}@localhost" "$@"
}

# Eliminar el contenedor
remove_container() {
  check_docker

  if ! container_exists; then
    log "WARN" "No existe un contenedor '${WILDFLY_CONTAINER_NAME}'."
    return 0
  fi

  if container_running; then
    log "WARN" "El contenedor esta corriendo. Se detendra antes de eliminar."
  fi

  echo ""
  log "WARN" "═══════════════════════════════════════════════════════════"
  log "WARN" "ATENCION: Esta a punto de eliminar el contenedor."
  log "WARN" "  Contenedor: ${WILDFLY_CONTAINER_NAME}"
  log "WARN" "  Se perdera cualquier cambio no persistido en volúmenes."
  log "WARN" "═══════════════════════════════════════════════════════════"
  echo ""
  read -r -p "Confirme escribiendo 'yes': " confirm

  if [[ "${confirm}" != "yes" ]]; then
    log "INFO" "Eliminacion cancelada."
    return 0
  fi

  log "INFO" "Eliminando contenedor '${WILDFLY_CONTAINER_NAME}'..."
  docker rm -f "${WILDFLY_CONTAINER_NAME}" 2>/dev/null || true
  log "SUCCESS" "Contenedor eliminado correctamente."
}

# ============================================================================
# Parseo de argumentos
# ============================================================================

COMMAND=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile)
      PROFILE="$2"
      shift 2
      # Recargar variables del perfil
      load_env_vars "${PROFILE}" "$(script_dir_d4e5f6a7b8c9d0e1f2a3)"
      # Re-evaluar variables con el nuevo perfil
WILDFLY_IMAGE="$(set_with_fallback "WILDFLY_IMAGE" "wildfly-ssh:26.1.2.Final")"
      WILDFLY_CONTAINER_NAME="$(set_with_fallback "WILDFLY_CONTAINER_NAME" "geniahr-wildfly")"
      WILDFLY_SSH_PORT="$(set_with_fallback "WILDFLY_SSH_PORT" "2222")"
      WILDFLY_HTTP_PORT="$(set_with_fallback "WILDFLY_HTTP_PORT" "8080")"
      WILDFLY_ADMIN_PORT="$(set_with_fallback "WILDFLY_ADMIN_PORT" "9990")"
      WILDFLY_DEPLOY_USER="$(set_with_fallback "WILDFLY_DEPLOY_USER" "deploy")"
      WILDFLY_DEPLOY_PASSWORD="$(set_with_fallback "WILDFLY_DEPLOY_PASSWORD" "deploy")"
      WILDFLY_SSH_PUBLIC_KEY="$(set_with_fallback "WILDFLY_SSH_PUBLIC_KEY" "")"
      WILDFLY_DEPLOY_PATH="$(set_with_fallback "WILDFLY_DEPLOY_PATH" "${WILDFLY_HOME}/standalone/deployments")"
      WILDFLY_XMS="$(set_with_fallback "WILDFLY_XMS" "512m")"
      WILDFLY_XMX="$(set_with_fallback "WILDFLY_XMX" "1024m")"
      NETWORK_NAME="$(set_with_fallback "NETWORK_NAME" "geniahr-network")"
      ;;
    start|stop|restart|status|logs|ssh|build|remove)
      COMMAND="$1"
      shift
      # Si el comando es 'ssh', el resto de args se pasan al ssh
      if [[ "${COMMAND}" == "ssh" ]]; then
        break
      fi
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
# Main
# ============================================================================

if [[ -z "${COMMAND:-}" ]]; then
  show_usage
  exit 1
fi

case "${COMMAND}" in
  start)
    start_wildfly
    ;;
  stop)
    stop_wildfly
    ;;
  restart)
    restart_wildfly
    ;;
  status)
    show_status
    ;;
  logs)
    show_logs
    ;;
  ssh)
    ssh_into_container "$@"
    ;;
  build)
    build_image
    ;;
  remove)
    remove_container
    ;;
  *)
    log "ERROR" "Comando desconocido: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
