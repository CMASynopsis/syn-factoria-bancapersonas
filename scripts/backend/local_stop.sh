#!/bin/bash
# CMA Factoria - Backend Local Stop Script
# Description: Detiene requirements-api-ms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/commons/log.sh"
MODULE_NAME="backend-localstop"

log "INFO" "Deteniendo servicios del backend..."

SERVICE_PORT="8083"
PID=$(lsof -ti:$SERVICE_PORT 2>/dev/null || true)

if [[ -n "$PID" ]]; then
    log "INFO" "Deteniendo requirements-api-ms (Puerto $SERVICE_PORT, PID: $PID)..."
    kill $PID 2>/dev/null || true
else
    log "INFO" "No se encontró proceso en puerto $SERVICE_PORT"
fi

sleep 2

JAVA_PIDS=$(pgrep -f "quarkus" 2>/dev/null || true)
if [[ -n "$JAVA_PIDS" ]]; then
    log "INFO" "Deteniendo procesos Java relacionados con Quarkus..."
    echo "$JAVA_PIDS" | xargs kill 2>/dev/null || true
    sleep 1
fi

log "SUCCESS" "requirements-api-ms detenido"