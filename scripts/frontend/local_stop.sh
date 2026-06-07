#!/bin/bash
# CMA Factoria - Frontend Local Stop Script
# Description: Detiene los MFEs del frontend

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/commons/log.sh"
MODULE_NAME="frontend-localstop"

log "INFO" "Deteniendo servicios del frontend..."

log "INFO" "Buscando procesos en puertos 3000-3005..."

# Puertos y sus MFEs correspondientes
PORTS=(
    "3000:mfe-principal"
    "3001:mfe-recruitments"
    "3002:mfe-shared-components"
    "3003:mfe-dashboard"
    "3004:mfe-requirements"
)

STOPPED_ANY=0

for entry in "${PORTS[@]}"; do
    PORT="${entry%%:*}"
    MFE_NAME="${entry##*:}"
    
    PID=$(lsof -ti:$PORT 2>/dev/null || true)
    if [[ -n "$PID" ]]; then
        log "INFO" "Deteniendo $MFE_NAME (Puerto $PORT, PID: $PID)..."
        kill $PID 2>/dev/null || true
        STOPPED_ANY=1
    fi
done

# Limpiar procesos webpack huérfanos
NODE_PIDS=$(pgrep -f "webpack" 2>/dev/null || true)
if [[ -n "$NODE_PIDS" ]]; then
    log "INFO" "Deteniendo procesos webpack huérfanos..."
    echo "$NODE_PIDS" | xargs kill 2>/dev/null || true
    STOPPED_ANY=1
fi

sleep 1

if [[ $STOPPED_ANY -eq 1 ]]; then
    log "SUCCESS" "Todos los servicios de frontend detenidos"
else
    log "INFO" "No había ningún servicio de frontend en ejecución"
fi