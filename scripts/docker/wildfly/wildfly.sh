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

# ── Cargar módulos ──
source "$(script_dir_d4e5f6a7b8c9d0e1f2a3)/modules/container.sh"
source "$(script_dir_d4e5f6a7b8c9d0e1f2a3)/modules/image.sh"

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
PROJECT_ROOT="$(script_dir_d4e5f6a7b8c9d0e1f2a3)/../../.."

# Registry para publicar la imagen
WILDFLY_REGISTRY="$(set_with_fallback "WILDFLY_REGISTRY" "")"
WILDFLY_REGISTRY_USER="$(set_with_fallback "WILDFLY_REGISTRY_USER" "")"
WILDFLY_REGISTRY_PASSWORD="$(set_with_fallback "WILDFLY_REGISTRY_PASSWORD" "")"

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
  publish     Construir y publicar la imagen en el registry
  remove      Eliminar el contenedor (con confirmacion)

Opciones:
  -p, --profile <perfil>  Perfil de configuracion (dev, staging, prod)
                            Por defecto: dev

Variables de entorno (prioridad: ENV_VAR > VAR > profile.env > default):
  WILDFLY_IMAGE            Imagen Docker                  Default: wildfly-ssh:26.1.2.Final
  WILDFLY_REGISTRY         Registry para publicar imagen  Default: (vacio = Docker Hub)
  WILDFLY_REGISTRY_USER    Usuario del registry           Default: (vacio)
  WILDFLY_REGISTRY_PASSWORD Password del registry          Default: (vacio)
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
  ./scripts/docker/wildfly/wildfly.sh publish
  ./scripts/docker/wildfly/wildfly.sh ssh
  WILDFLY_SSH_PORT=2222 ./scripts/docker/wildfly/wildfly.sh start

Para configuracion persistente, crear <perfil>.env en este directorio.
EOF
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
      WILDFLY_REGISTRY="$(set_with_fallback "WILDFLY_REGISTRY" "")"
      WILDFLY_REGISTRY_USER="$(set_with_fallback "WILDFLY_REGISTRY_USER" "")"
      WILDFLY_REGISTRY_PASSWORD="$(set_with_fallback "WILDFLY_REGISTRY_PASSWORD" "")"
      ;;
    start|stop|restart|status|logs|ssh|build|publish|remove)
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
  publish)
    publish_image
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
