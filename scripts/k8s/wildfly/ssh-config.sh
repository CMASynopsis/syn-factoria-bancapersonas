#!/bin/bash
set -euo pipefail

# =============================================================================
# Wildfly K8s — SSH Config
# =============================================================================
# Manage SSH key pair generation and distribution for connecting from a kubectl
# client machine to a Kubernetes node server.
#
# Uso: ./scripts/k8s/wildfly/ssh-config.sh <comando> [-p|--profile <perfil>] [opciones SSH]
#
# Perfiles: dev (default), staging, prod
# =============================================================================

# ── SCRIPT_DIR con sufijo único (uuidv4{18}) — evitar colisiones ──
script_dir_p0o9i8u7y6t5r4e3w2q1() { echo "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"; }

# ── Cargar utilidades compartidas ──
source "$(script_dir_p0o9i8u7y6t5r4e3w2q1)/../../commons/log.sh"
source "$(script_dir_p0o9i8u7y6t5r4e3w2q1)/../../commons/get.sh"

MODULE_NAME="k8s-wildfly-ssh-config"
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
load_env_vars "${PROFILE}" "$(script_dir_p0o9i8u7y6t5r4e3w2q1)"

# ============================================================================
# Variables con defaults — Prioridad: ENV_VAR > VAR > profile.env > inline
# ============================================================================

# SSH — passphrase vacía por defecto (sin passphrase)
SSH_HOST="$(set_with_fallback "SSH_HOST" "")"
SSH_USER="$(set_with_fallback "SSH_USER" "${USER:-root}")"
SSH_KEY_PATH="$(set_with_fallback "SSH_KEY_PATH" "${HOME}/.ssh/id_rsa_wildfly")"
SSH_KEY_TYPE="$(set_with_fallback "SSH_KEY_TYPE" "rsa")"
SSH_KEY_BITS="$(set_with_fallback "SSH_KEY_BITS" "4096")"
SSH_PASSPHRASE=""

# ============================================================================
# Funciones auxiliares
# ============================================================================

# Mostrar ayuda
show_usage() {
  cat <<EOF
Uso: $(basename "$0") <comando> [opciones]

Comandos:
  create      Generar un par de claves SSH si no existe
  copy        Copiar la clave pública al servidor remoto
  test        Probar la conexión SSH al servidor
  connect     Conecta vía SSH interactiva al servidor remoto
  info        Mostrar información del par de claves

Opciones:
  -p, --profile <perfil>  Perfil de configuracion (dev, staging, prod)
                            Por defecto: dev
  -n, --node <host>       Host o IP del nodo Kubernetes
  -u, --user <user>       Usuario SSH (default: \$USER o root)
  -k, --key <path>        Ruta a la clave privada SSH
  -P, --passphrase        Solicitar passphrase para proteger la clave privada
                            (por defecto se genera sin passphrase para CI/CD)
  -h, --help              Mostrar esta ayuda

Variables de entorno (prioridad: ENV_VAR > VAR > profile.env > default):
  SSH_HOST                Host o IP del nodo Kubernetes
  SSH_USER                Usuario SSH                           Default: \$USER/root
  SSH_KEY_PATH            Ruta a la clave privada SSH           Default: ~/.ssh/id_rsa_wildfly
  SSH_KEY_TYPE            Tipo de clave (rsa, ed25519)          Default: rsa
  SSH_KEY_BITS            Bits de la clave (para rsa)           Default: 4096

Ejemplos:
  ./scripts/k8s/wildfly/ssh-config.sh create
  ./scripts/k8s/wildfly/ssh-config.sh create -k ~/.ssh/mi_clave
  ./scripts/k8s/wildfly/ssh-config.sh create -P                    # solicita passphrase
  ./scripts/k8s/wildfly/ssh-config.sh copy -n nodo1
  ./scripts/k8s/wildfly/ssh-config.sh copy -n 10.0.0.1 -u admin -k ~/.ssh/id_rsa_wildfly
  ./scripts/k8s/wildfly/ssh-config.sh test -n nodo1
  ./scripts/k8s/wildfly/ssh-config.sh connect -n nodo1
  ./scripts/k8s/wildfly/ssh-config.sh info
  SSH_HOST=nodo1 ./scripts/k8s/wildfly/ssh-config.sh copy
  ./scripts/k8s/wildfly/ssh-config.sh create -p staging
EOF
}

# Verificar que SSH_HOST esté definido
require_ssh_host() {
  if [[ -z "${SSH_HOST}" ]]; then
    log "ERROR" "Debe especificar el nodo con -n/--node o definir SSH_HOST."
    exit 1
  fi
}

# Generar par de claves SSH
create_keys() {
  if [[ -f "${SSH_KEY_PATH}" ]]; then
    if [[ "${PASSPHRASE_FLAG}" == "true" ]]; then
      log "WARN" "La clave ya existe: ${SSH_KEY_PATH}"
      log "WARN" "Para añadir passphrase a la clave existente ejecute:"
      log "WARN" "    ssh-keygen -p -f ${SSH_KEY_PATH}"
    else
      log "INFO" "La clave ya existe: ${SSH_KEY_PATH}"
      log "INFO" "Use el comando 'info' para ver los detalles."
    fi
    return 0
  fi

  local key_dir
  key_dir=$(dirname "${SSH_KEY_PATH}")
  mkdir -p "${key_dir}"
  chmod 700 "${key_dir}"

  # Solicitar passphrase solo si se pasó -P
  if [[ "${PASSPHRASE_FLAG}" == "true" ]]; then
    read -r -s -p "Introduzca passphrase para la clave (o vacío para ninguna): " SSH_PASSPHRASE
    echo
  fi

  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Generando par de claves SSH"
  log "INFO" "  Ruta:      ${SSH_KEY_PATH}"
  log "INFO" "  Tipo:      ${SSH_KEY_TYPE}"
  log "INFO" "  Bits:      ${SSH_KEY_BITS}"
  if [[ -n "${SSH_PASSPHRASE}" ]]; then
    log "INFO" "  Passphrase: Protegida"
    log "WARN" "  ⚠ Debe cargar la clave en ssh-agent para uso no interactivo:"
    log "WARN" "      ssh-add ${SSH_KEY_PATH}"
  else
    log "INFO" "  Passphrase: No (modo CI/CD)"
  fi
  log "INFO" "═══════════════════════════════════════════════════════════"

  if [[ -n "${SSH_PASSPHRASE}" ]]; then
    ssh-keygen -t "${SSH_KEY_TYPE}" -b "${SSH_KEY_BITS}" -f "${SSH_KEY_PATH}" -N "${SSH_PASSPHRASE}" -q
  else
    ssh-keygen -t "${SSH_KEY_TYPE}" -b "${SSH_KEY_BITS}" -f "${SSH_KEY_PATH}" -N "" -q
  fi

  log "SUCCESS" "Par de claves generado correctamente."

  # Mostrar huella digital
  local fingerprint
  fingerprint=$(ssh-keygen -lf "${SSH_KEY_PATH}" 2>/dev/null || true)
  log "INFO" "  Huella:    ${fingerprint}"

  # Mostrar clave pública
  log "INFO" "  Clave pública:"
  cat "${SSH_KEY_PATH}.pub"
}

# Copiar clave pública al servidor remoto
copy_key() {
  require_ssh_host

  if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    log "ERROR" "La clave privada no existe: ${SSH_KEY_PATH}"
    log "INFO" "Ejecute primero: $(basename "$0") create"
    exit 1
  fi

  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Copiando clave pública a: ${SSH_USER}@${SSH_HOST}"
  log "INFO" "  Clave: ${SSH_KEY_PATH}.pub"
  log "INFO" "═══════════════════════════════════════════════════════════"

  ssh-copy-id -i "${SSH_KEY_PATH}.pub" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${SSH_USER}@${SSH_HOST}"

  log "SUCCESS" "Clave pública copiada correctamente."

  # Verificar conexión
  log "INFO" "Verificando conexión..."
  if ssh -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=5 \
       "${SSH_USER}@${SSH_HOST}" "echo OK" 2>/dev/null; then
    log "SUCCESS" "Conexión verificada correctamente."
  else
    log "ERROR" "La verificación de conexión falló."
    exit 1
  fi
}

# Probar conexión SSH
test_connection() {
  require_ssh_host

  log "INFO" "Probando conexión a ${SSH_USER}@${SSH_HOST}..."
  log "INFO" "  Clave: ${SSH_KEY_PATH}"

  if ssh -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=5 \
       -i "${SSH_KEY_PATH}" \
       "${SSH_USER}@${SSH_HOST}" "echo OK" 2>/dev/null; then
    log "SUCCESS" "Conexión exitosa a ${SSH_USER}@${SSH_HOST}"
  else
    log "ERROR" "No se pudo conectar a ${SSH_USER}@${SSH_HOST}"
    log "INFO" "Verifique que el servidor sea accesible y la clave esté copiada."
    exit 1
  fi
}

# Conectar vía SSH interactiva al servidor remoto
open_connection() {
  require_ssh_host

  if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    log "ERROR" "La clave privada no existe: ${SSH_KEY_PATH}"
    log "INFO" "Ejecute primero: $(basename "$0") create"
    exit 1
  fi

  log "INFO" "Conectando a ${SSH_USER}@${SSH_HOST}..."
  log "INFO" "  Clave: ${SSH_KEY_PATH}"
  echo ""

  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -i "${SSH_KEY_PATH}" \
      -t \
      "${SSH_USER}@${SSH_HOST}"
}

# Mostrar información del par de claves
show_info() {
  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Información del par de claves SSH"
  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Ruta:        ${SSH_KEY_PATH}"

  if [[ -f "${SSH_KEY_PATH}" ]]; then
    log "INFO" "  Estado:      Existe"

    local fingerprint
    fingerprint=$(ssh-keygen -lf "${SSH_KEY_PATH}" 2>/dev/null || true)
    if [[ -n "${fingerprint}" ]]; then
      log "INFO" "  Huella:      ${fingerprint}"
    fi

    # Detectar si la clave tiene passphrase
    if ssh-keygen -y -f "${SSH_KEY_PATH}" </dev/null &>/dev/null; then
      log "INFO" "  Passphrase:  No"
    else
      log "INFO" "  Passphrase:  Sí (requiere ssh-agent)"
    fi

    log "INFO" "  Clave pública:"
    sed 's/^/    /' "${SSH_KEY_PATH}.pub"
  else
    log "INFO" "  Estado:      No existe"
    log "INFO" "  Ejecute:     $(basename "$0") create"
  fi

  log "INFO" "  Tipo:        ${SSH_KEY_TYPE}"
  log "INFO" "  Bits:        ${SSH_KEY_BITS}"
  log "INFO" "  Usuario:     ${SSH_USER}"
  if [[ -n "${SSH_HOST}" ]]; then
    log "INFO" "  Host:        ${SSH_HOST}"
  else
    log "INFO" "  Host:        (no especificado)"
  fi
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
      load_env_vars "${PROFILE}" "$(script_dir_p0o9i8u7y6t5r4e3w2q1)"
      # Re-evaluar variables con el nuevo perfil
      SSH_HOST="$(set_with_fallback "SSH_HOST" "")"
      SSH_USER="$(set_with_fallback "SSH_USER" "${USER:-root}")"
      SSH_KEY_PATH="$(set_with_fallback "SSH_KEY_PATH" "${HOME}/.ssh/id_rsa_wildfly")"
      SSH_KEY_TYPE="$(set_with_fallback "SSH_KEY_TYPE" "rsa")"
      SSH_KEY_BITS="$(set_with_fallback "SSH_KEY_BITS" "4096")"
      SSH_PASSPHRASE=""
      PASSPHRASE_FLAG=false
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
    -P|--passphrase)
      PASSPHRASE_FLAG=true
      shift
      ;;
    create|copy|test|connect|info)
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

case "${COMMAND}" in
  create)
    create_keys
    ;;
  copy)
    copy_key
    ;;
  test)
    test_connection
    ;;
  connect)
    open_connection
    ;;
  info)
    show_info
    ;;
  *)
    log "ERROR" "Comando desconocido: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
