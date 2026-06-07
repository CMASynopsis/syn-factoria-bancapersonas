#!/bin/bash
#location: scripts/commons/log.sh

# Variable para controlar el nivel de debug
# Establece DEBUG_ENABLED a "true" para habilitar los logs de depuración
DEBUG_ENABLED="${DEBUG_ENABLED:-false}"

# Habilitar guardado de logs en archivo
LOG_TO_FILE="${LOG_TO_FILE:-false}"
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.logs"

# Generar código aleatorio de 12 caracteres
generate_random_id() {
  # Fix para macOS - configurar locale antes de usar tr
  LC_CTYPE=C tr -dc 'A-Z0-9' < /dev/urandom 2>/dev/null | head -c 12 || echo "$(date +%s)$RANDOM"
}

# ID único y timestamp para esta ejecución (generado una sola vez)
export LOG_EXEC_ID="${LOG_EXEC_ID:-$(generate_random_id)}"
export LOG_TIMESTAMP="${LOG_TIMESTAMP:-$(date '+%Y%m%d_%H%M%S')}"

# Función de log unificada
log() {
  local level="$1"
  local message="$2"
  
  # Auto-detectar LOG_MODULE_NAME en el primer llamado si no está definido
  if [[ -z "${LOG_MODULE_NAME:-}" ]]; then
    export LOG_MODULE_NAME="${MODULE_NAME:-unknown}"
  fi
  
  # Si el nivel es DEBUG y DEBUG_ENABLED no es true, sal del script
  if [[ "$level" == "DEBUG" ]] && [[ "${DEBUG_ENABLED:-}" != "true" ]]; then
    return 0
  fi
  
  # Asigna color según el nivel de log
  local color_code="\033[0m" # Default (NC - No Color)
  case "$level" in
    "SUCCESS")
      color_code="\033[0;32m" # Green (Verde: Éxito)
      ;;
    "INFO")
      color_code="\033[0;34m" # Blue (Azul: Información general)
      ;;
    "WARN")
      color_code="\033[0;33m" # Yellow (Amarillo: Advertencia)
      ;;
    "DEBUG")
      color_code="\033[0;36m" # Cyan (Cyan: Depuración)
      ;;
    "ERROR")
      color_code="\033[0;31m" # Red (Rojo: Error crítico)
      ;;
    *)
      level="UNKNOWN"
      ;;
  esac

  # Imprime el mensaje con formato y color a stderr
  echo -e "${color_code}$(date '+%Y-%m-%d %H:%M:%S') - $MODULE_NAME - $level - $message\033[0m" 1>&2
  
  # Guardar en archivo (sin colores)
  if [[ "$LOG_TO_FILE" == "true" ]]; then
    mkdir -p "$LOG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MODULE_NAME - $level - $message" >> "$LOG_DIR/${LOG_MODULE_NAME}_${LOG_TIMESTAMP}_${LOG_EXEC_ID}.log"
  fi
}

# Función para manejar errores fatales y salir del script
handle_error() {
  local message="$1"
  local exit_code="${2:-1}"
  log "ERROR" "$message"
  exit "$exit_code"
}

# Función para mostrar error de configuración de AWS con ayuda específica
handle_aws_config_error() {
  local issue="$1"
  local profile="${AWS_PROFILE:-default}"
  
  case "$issue" in
    "no_credentials")
      handle_error "AWS credentials not configured for profile '$profile'. Please:
1. Run 'aws configure' or 'aws configure --profile $profile'
2. Or export AWS_PROFILE=<profile_name>
3. Or export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
      ;;
    "no_cli")
      handle_error "AWS CLI not installed. Please install it from: https://aws.amazon.com/cli/"
      ;;
    "invalid_region")
      handle_error "Invalid AWS region. Please specify a valid region like: us-east-1, us-west-2, eu-west-1"
      ;;
    "permissions")
      handle_error "Insufficient AWS permissions. Please check your IAM permissions for the required actions"
      ;;
    *)
      handle_error "AWS configuration error: $issue"
      ;;
  esac
}

# Función para log de progreso con spinner
log_progress() {
  local message="$1"
  local duration="${2:-3}"
  
  for i in $(seq 1 $duration); do
    echo -ne "\r\033[0;34m$(date '+%Y-%m-%d %H:%M:%S') - $MODULE_NAME - INFO - $message... "
    case $((i % 4)) in
      0) echo -ne "|\033[0m" ;;
      1) echo -ne "/\033[0m" ;;
      2) echo -ne "-\033[0m" ;;
      3) echo -ne "\\\033[0m" ;;
    esac
    sleep 0.25
  done
  echo -ne "\r\033[0;34m$(date '+%Y-%m-%d %H:%M:%S') - $MODULE_NAME - INFO - $message... ✅\033[0m\n"
}