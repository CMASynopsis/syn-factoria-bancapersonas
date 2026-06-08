#!/bin/bash
set -euo pipefail

# =============================================================================
# Wildfly K8s — Volumes
# =============================================================================
# Pre-crea los directorios de volúmenes en el nodo Kubernetes antes de
# desplegar Wildfly. Asegura que los permisos sean correctos para el
# usuario jboss (UID 1000) dentro del contenedor.
#
# Uso: ./scripts/k8s/wildfly/volumes.sh <comando> [-p|--profile <perfil>] [opciones SSH]
#
# Perfiles: dev (default), staging, prod
# =============================================================================

# ── SCRIPT_DIR con sufijo único (uuidv4{18}) — evitar colisiones ──
script_dir_d9e8f7c6b5a4d3e2f1g0() { echo "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"; }

# ── Cargar utilidades compartidas ──
source "$(script_dir_d9e8f7c6b5a4d3e2f1g0)/../../commons/log.sh"
source "$(script_dir_d9e8f7c6b5a4d3e2f1g0)/../../commons/get.sh"

MODULE_NAME="k8s-wildfly-volumes"
LOG_MODULE_NAME="$MODULE_NAME"

# ============================================================================
# Configuración inicial (antes de parsear argumentos)
# ============================================================================

# Perfil por defecto
PROFILE="dev"

# ── Early parse: detectar --profile antes de inicializar variables ──
for arg in "$@"; do
  case "${arg}" in
    -p|--profile)
      capture_profile=true
      ;;
    *)
      if [[ "${capture_profile:-}" == "true" ]]; then
        PROFILE="${arg}"
        break
      fi
      ;;
  esac
done

# Cargar vars del perfil
load_env_vars "${PROFILE}" "$(script_dir_d9e8f7c6b5a4d3e2f1g0)"

# ============================================================================
# Variables con defaults — Prioridad: ENV_VAR > VAR > profile.env > inline
# ============================================================================

# SSH
SSH_HOST="$(set_with_fallback "SSH_HOST" "")"
SSH_USER="$(set_with_fallback "SSH_USER" "${USER:-root}")"
SSH_KEY_PATH="$(set_with_fallback "SSH_KEY_PATH" "")"

# Volumen
VOLUME_BASE_DIR="$(set_with_fallback "VOLUME_BASE_DIR" "/mnt/data/wildfly")"
WILDFLY_DEPLOY_USER="$(set_with_fallback "WILDFLY_DEPLOY_USER" "deploy")"
STORAGE_SIZE="$(set_with_fallback "STORAGE_SIZE" "1Gi")"

# ============================================================================
# Funciones auxiliares
# ============================================================================

# Mostrar ayuda
show_usage() {
  cat <<EOF
Uso: $(basename "$0") <comando> [opciones]

Comandos:
  create      Crear directorios de volúmenes en el nodo
  check       Verificar que los directorios existan y tengan permisos correctos
  delete      Eliminar directorios de volúmenes (cuidado: borra datos)

Opciones:
  -p, --profile <perfil>  Perfil de configuracion (dev, staging, prod)
                            Por defecto: dev
  -n, --node <host>       Host o IP del nodo Kubernetes (requerido si SSH_HOST no está definido)
  -u, --user <user>       Usuario SSH (default: \$USER o root)
  -k, --key <path>        Ruta a la clave privada SSH
  -h, --help              Mostrar esta ayuda

Variables de entorno (prioridad: ENV_VAR > VAR > profile.env > default):
  SSH_HOST                Host o IP del nodo Kubernetes
  SSH_USER                Usuario SSH                           Default: \$USER/root
  SSH_KEY_PATH            Ruta a la clave privada SSH
  VOLUME_BASE_DIR         Directorio base para los volúmenes    Default: /mnt/data/wildfly
  STORAGE_SIZE            Tamaño del volumen                    Default: 1Gi

Ejemplos:
  ./scripts/k8s/wildfly/volumes.sh create -n nodo1
  ./scripts/k8s/wildfly/volumes.sh create -n 10.0.0.1 -u admin -k ~/.ssh/id_rsa
  ./scripts/k8s/wildfly/volumes.sh check -n nodo1
  SSH_HOST=nodo1 ./scripts/k8s/wildfly/volumes.sh create
  ./scripts/k8s/wildfly/volumes.sh create -p staging -n nodo2
EOF
}

# Ejecutar comando remoto via SSH
remote_exec() {
  local host="${1}"
  local command="${2}"

  if [[ -z "${host}" ]]; then
    log "ERROR" "No se especificó nodo. Use -n/--node o defina SSH_HOST."
    exit 1
  fi

  log "DEBUG" "Ejecutando en ${SSH_USER}@${host}: ${command}"
  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      ${SSH_KEY_PATH:+-i "${SSH_KEY_PATH}"} \
      "${SSH_USER}@${host}" \
      "${command}"
}

# Obtener la ruta del directorio de deployments
get_deployments_dir() {
  echo "${VOLUME_BASE_DIR}/deployments"
}

# Crear directorios de volúmenes en el nodo
create_volumes() {
  local host="${1}"
  local deploy_dir
  deploy_dir=$(get_deployments_dir)

  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Creando volúmenes en: ${SSH_USER}@${host}"
  log "INFO" "  Directorio: ${deploy_dir}"
  log "INFO" "═══════════════════════════════════════════════════════════"

  # Crear directorio principal
  remote_exec "${host}" "sudo mkdir -p ${deploy_dir}"

  # Asignar ownership al usuario jboss (UID 1000) para que Wildfly pueda escribir
  remote_exec "${host}" "sudo chown -R 1000:1000 ${VOLUME_BASE_DIR}"

  # Asignar permisos
  remote_exec "${host}" "sudo chmod -R 775 ${VOLUME_BASE_DIR}"

  # Verificar creación
  local result
  result=$(remote_exec "${host}" "ls -ld ${deploy_dir} 2>/dev/null || echo 'NOT_FOUND'")

  if [[ "${result}" == "NOT_FOUND" ]]; then
    log "ERROR" "No se pudo crear el directorio ${deploy_dir}."
    exit 1
  fi

  log "SUCCESS" "Volúmenes creados correctamente en ${deploy_dir}"

  # Mostrar información del volumen
  log "INFO" "  Ruta:      ${deploy_dir}"
  log "INFO" "  Propietario: 1000:1000 (jboss)"
  log "INFO" "  Permisos:  775 (rwxrwxr-x)"
  log "INFO" "  Tamaño:   ${STORAGE_SIZE}"
}

# Verificar que los directorios existan y tengan permisos correctos
check_volumes() {
  local host="${1}"
  local deploy_dir
  deploy_dir=$(get_deployments_dir)

  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Verificando volúmenes en: ${SSH_USER}@${host}"
  log "INFO" "═══════════════════════════════════════════════════════════"

  local has_errors=false

  # Verificar que el directorio exista
  local dir_exists
  dir_exists=$(remote_exec "${host}" "test -d ${deploy_dir} && echo 'OK' || echo 'NOT_FOUND'")

  if [[ "${dir_exists}" == "OK" ]]; then
    log "SUCCESS" "Directorio existe: ${deploy_dir}"
  else
    log "ERROR" "Directorio NO existe: ${deploy_dir}"
    log "INFO" "Ejecute: $(basename "$0") create -n ${host}"
    has_errors=true
  fi

  # Verificar permisos
  local perms
  perms=$(remote_exec "${host}" "stat -c '%a %u:%g' ${deploy_dir} 2>/dev/null || true")

  if [[ -n "${perms}" ]]; then
    local perm_num="${perms%% *}"
    local owner="${perms##* }"
    log "INFO" "  Permisos:  ${perm_num}"
    log "INFO" "  Owner:     ${owner}"

    if [[ "${owner}" != "1000:1000" ]]; then
      log "WARN" "Owner no es 1000:1000 (jboss). Ejecute: $(basename "$0") create -n ${host}"
    fi
  fi

  # Mostrar espacio disponible
  local disk_info
  disk_info=$(remote_exec "${host}" "df -h ${deploy_dir} 2>/dev/null || true")
  if [[ -n "${disk_info}" ]]; then
    log "INFO" "  Espacio en disco:"
    echo "${disk_info}" | while IFS= read -r line; do
      log "INFO" "    ${line}"
    done
  fi

  if [[ "${has_errors}" == "true" ]]; then
    return 1
  fi

  log "SUCCESS" "Verificación completada correctamente."
}

# Eliminar directorios de volúmenes
delete_volumes() {
  local host="${1}"

  log "WARN" "═══════════════════════════════════════════════════════════"
  log "WARN" "  ATENCION: Esta a punto de eliminar TODOS los datos."
  log "WARN" "  Host:  ${SSH_USER}@${host}"
  log "WARN" "  Ruta:  ${VOLUME_BASE_DIR}"
  log "WARN" "═══════════════════════════════════════════════════════════"

  local confirm
  echo ""
  read -r -p "Confirme escribiendo 'yes': " confirm

  if [[ "${confirm}" != "yes" ]]; then
    log "INFO" "Eliminación cancelada."
    return 0
  fi

  log "INFO" "Eliminando ${VOLUME_BASE_DIR}..."
  remote_exec "${host}" "sudo rm -rf ${VOLUME_BASE_DIR}"

  log "SUCCESS" "Volúmenes eliminados correctamente."
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
      load_env_vars "${PROFILE}" "$(script_dir_d9e8f7c6b5a4d3e2f1g0)"
      SSH_HOST="$(set_with_fallback "SSH_HOST" "")"
      SSH_USER="$(set_with_fallback "SSH_USER" "${USER:-root}")"
      SSH_KEY_PATH="$(set_with_fallback "SSH_KEY_PATH" "")"
      VOLUME_BASE_DIR="$(set_with_fallback "VOLUME_BASE_DIR" "/mnt/data/wildfly")"
      STORAGE_SIZE="$(set_with_fallback "STORAGE_SIZE" "1Gi")"
      ;;
    -n|--node)
      SSH_HOST="$2"
      shift 2
      ;;
    -u|--user)
      SSH_USER="$2"
      shift 2
      ;;
    -k|--key)
      SSH_KEY_PATH="$2"
      shift 2
      ;;
    create|check|delete)
      COMMAND="$1"
      shift
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

if [[ -z "${SSH_HOST:-}" ]]; then
  log "ERROR" "Debe especificar el nodo con -n/--node o definir SSH_HOST."
  exit 1
fi

case "${COMMAND}" in
  create)
    create_volumes "${SSH_HOST}"
    ;;
  check)
    check_volumes "${SSH_HOST}"
    ;;
  delete)
    delete_volumes "${SSH_HOST}"
    ;;
  *)
    log "ERROR" "Comando desconocido: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
