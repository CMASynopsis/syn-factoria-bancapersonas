#!/bin/bash
# CMA Factoria - Backend Local Start Script
# Description: Inicializa requirements-api-ms localmente
# Usage: ./local_start.sh [--profile <dev|staging|prod>]
#   --profile  - perfil de variables de entorno (default: dev)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/commons/log.sh"
MODULE_NAME="backend-localstart"

PROFILE="dev"

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--profile <dev|staging|prod>]"
            exit 1
            ;;
    esac
done

log "INFO" "=========================================="
log "INFO" "Iniciando Backend - CMA Factoria"
log "INFO" "Servicio: requirements-api-ms | Perfil: $PROFILE"
log "INFO" "=========================================="

BACKEND_DIR="$PROJECT_ROOT/apps/backend/requirements-api-ms"
SERVICE_NAME="requirements-api-ms"
SERVICE_PORT="8083"

if [[ ! -d "$BACKEND_DIR" ]]; then
    handle_error "Directorio de backend no encontrado: $BACKEND_DIR"
fi

cd "$BACKEND_DIR"

if [[ ! -f "pom.xml" ]]; then
    handle_error "No se encontró pom.xml en $BACKEND_DIR"
fi

# Cargar variables de entorno del perfil
ENV_FILE="$BACKEND_DIR/${PROFILE}.env"
if [[ -f "$ENV_FILE" ]]; then
    log "INFO" "Cargando variables de entorno desde: $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    log "WARN" "No se encontró archivo de perfil: $ENV_FILE"
fi

log "INFO" "Verificando/compilando proyecto backend ($SERVICE_NAME)..."
mvn clean compile -q

log "INFO" "Iniciando $SERVICE_NAME en modo desarrollo..."
log "INFO" "El servicio estará disponible en: http://localhost:$SERVICE_PORT"
log "INFO" "Presiona Ctrl+C para detener"

mvn quarkus:dev