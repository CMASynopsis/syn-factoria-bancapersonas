#!/bin/bash
# location: scripts/docker/wildfly/modules/image.sh
# Image lifecycle: build, publish

# ── Construir la imagen Docker ──
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
    "${PROJECT_ROOT}"

  log "SUCCESS" "Imagen '${WILDFLY_IMAGE}' construida correctamente."
}

# ── Publicar la imagen en el registry ──
publish_image() {
  check_docker

  # Construir primero
  build_image

  local registry="${WILDFLY_REGISTRY}"
  local source_tag="${WILDFLY_IMAGE}"
  local target_tag=""

  if [[ -n "${registry}" ]]; then
    # Sanitizar: eliminar protocolo (https://, http://) y slash final
    # Docker no acepta protocolo en tags ni en docker login
    local registry_raw="${registry}"
    registry="${registry#https://}"
    registry="${registry#http://}"
    registry="${registry%/}"
    target_tag="${registry}/${source_tag}"

    log "INFO" "═══════════════════════════════════════════════════════════"
    log "INFO" "  Publicando imagen en registry"
    log "INFO" "  Origen:  ${source_tag}"
    log "INFO" "  Destino: ${target_tag}"
    log "INFO" "═══════════════════════════════════════════════════════════"

    # Autenticar contra el registry si hay credenciales
    if [[ -n "${WILDFLY_REGISTRY_USER}" ]] && [[ -n "${WILDFLY_REGISTRY_PASSWORD}" ]]; then
      log "INFO" "Autenticando contra ${registry_raw}..."
      echo "${WILDFLY_REGISTRY_PASSWORD}" | docker login "${registry_raw}" \
        --username "${WILDFLY_REGISTRY_USER}" \
        --password-stdin
    fi

    # Taggear la imagen para el registry
    docker tag "${source_tag}" "${target_tag}"

    # Pushear al registry
    log "INFO" "Pusheando imagen..."
    docker push "${target_tag}"

    log "SUCCESS" "Imagen publicada correctamente: ${target_tag}"
    log "INFO" "Actualice WILDFLY_IMAGE en su perfil K8s para usar la imagen del registry:"
    log "INFO" "  WILDFLY_IMAGE=${target_tag}"
  else
    log "WARN" "WILDFLY_REGISTRY no está definido. La imagen se publicará en Docker Hub."
    log "INFO" "Asegúrese de haber iniciado sesión con: docker login"

    # Autenticar en Docker Hub si hay credenciales
    if [[ -n "${WILDFLY_REGISTRY_USER}" ]] && [[ -n "${WILDFLY_REGISTRY_PASSWORD}" ]]; then
      log "INFO" "Autenticando en Docker Hub..."
      echo "${WILDFLY_REGISTRY_PASSWORD}" | docker login \
        --username "${WILDFLY_REGISTRY_USER}" \
        --password-stdin
    fi

    docker push "${source_tag}"

    log "SUCCESS" "Imagen publicada correctamente: ${source_tag}"
  fi
}
