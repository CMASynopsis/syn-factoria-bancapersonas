#!/bin/bash
# location: scripts/docker/wildfly/modules/container.sh
# Container lifecycle: check, start, stop, restart, status, logs, ssh, remove

# ── Verificar que Docker esté instalado y corriendo ──
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

# ── Verificar si el contenedor existe (incluso detenido) ──
container_exists() {
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${WILDFLY_CONTAINER_NAME}$"
}

# ── Verificar si el contenedor está corriendo ──
container_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${WILDFLY_CONTAINER_NAME}$"
}

# ── Esperar a que Wildfly esté listo ──
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

# ── Crear la red Docker si no existe ──
ensure_network() {
  if ! docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${NETWORK_NAME}$"; then
    log "INFO" "Creando red Docker: ${NETWORK_NAME}"
    docker network create "${NETWORK_NAME}" 2>/dev/null || true
    log "SUCCESS" "Red '${NETWORK_NAME}' creada."
  fi
}

# ── Construir argumentos de volúmenes ──
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

# ── Iniciar Wildfly ──
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

# ── Detener Wildfly ──
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

# ── Reiniciar Wildfly ──
restart_wildfly() {
  log "INFO" "Reiniciando Wildfly..."
  stop_wildfly
  sleep 2
  start_wildfly
}

# ── Mostrar estado ──
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

# ── Mostrar logs ──
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

# ── Conectarse via SSH al contenedor ──
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

# ── Eliminar el contenedor ──
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
