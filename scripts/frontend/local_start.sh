#!/bin/bash
# CMA Factoria - Frontend Local Start Script
# Description: Inicializa el frontend (shell + MFEs + shared APIs) localmente
# Usage: ./local_start.sh --profile <dev|staging|prod>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/commons/log.sh"
MODULE_NAME="frontend-localstart"

# Parsear argumentos
PROFILE="dev"

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 --profile <dev|staging|prod>"
            exit 1
            ;;
    esac
done

log "INFO" "=========================================="
log "INFO" "Iniciando Frontend - CMA Factoria"
log "INFO" "Perfil: $PROFILE"
log "INFO" "=========================================="

FRONTEND_DIR="$PROJECT_ROOT/apps/frontend"

# MFEs requeridos (el script falla si no existen)
REQUIRED_APPS=("mfe-principal" "mfe-dashboard" "mfe-requirements" "mfe-recruitments" "mfe-shared-components")

# MFEs opcionales (se omiten con advertencia si no existen)
OPTIONAL_APPS=("shared-commands-api" "shared-requirements-api")

for app in "${REQUIRED_APPS[@]}"; do
    if [[ ! -d "$FRONTEND_DIR/$app" ]]; then
        log "ERROR" "Directorio requerido no encontrado: $FRONTEND_DIR/$app"
        exit 1
    fi
done

for app in "${OPTIONAL_APPS[@]}"; do
    if [[ ! -d "$FRONTEND_DIR/$app" ]]; then
        log "WARN" "Directorio opcional no encontrado (omitiendo): $FRONTEND_DIR/$app"
    fi
done

# Función para cargar variables de entorno por perfil
load_profile_env() {
    local app_dir="$1"
    local env_file="$app_dir/${PROFILE}.env"

    if [[ ! -d "$app_dir" ]]; then
        return 0
    fi

    if [[ -f "$env_file" ]]; then
        log "INFO" "Cargando variables de entorno desde: $env_file"
        set -a
        source "$env_file"
        set +a
    else
        log "WARN" "No se encontró archivo de perfil: $env_file"
    fi
}

# Función para instalar dependencias si el directorio existe
install_deps() {
    local app_dir="$1"
    local app_name="$2"

    if [[ ! -d "$app_dir" ]] || [[ ! -f "$app_dir/package.json" ]]; then
        return 0
    fi

    log "INFO" "Instalando dependencias de $app_name..."
    cd "$app_dir"
    npm install --silent 2>/dev/null || npm install
    log "SUCCESS" "$app_name dependencies installed"
}

# Cargar profiles (remotes primero, host al final)
load_profile_env "$FRONTEND_DIR/mfe-recruitments"
load_profile_env "$FRONTEND_DIR/mfe-settings"
load_profile_env "$FRONTEND_DIR/mfe-dashboard"
load_profile_env "$FRONTEND_DIR/mfe-requirements"
load_profile_env "$FRONTEND_DIR/mfe-principal"
load_profile_env "$FRONTEND_DIR/mfe-shared-components"

# Instalar dependencias
install_deps "$FRONTEND_DIR/mfe-recruitments"   "mfe-recruitments"
install_deps "$FRONTEND_DIR/mfe-settings"   "mfe-settings"
install_deps "$FRONTEND_DIR/mfe-dashboard"  "mfe-dashboard"
install_deps "$FRONTEND_DIR/mfe-requirements" "mfe-requirements"
install_deps "$FRONTEND_DIR/mfe-principal"  "mfe-principal"
install_deps "$FRONTEND_DIR/mfe-shared-components" "mfe-shared-components"

#if [[ -d "$FRONTEND_DIR/mfe-recruitments" ]] && [[ -f "$FRONTEND_DIR/mfe-recruitments/package.json" ]]; then
#    cd "$FRONTEND_DIR/mfe-recruitments"
#    npm link @cma-factoria/shared-commands-api 2>/dev/null || true
#fi

cd "$FRONTEND_DIR"

log "INFO" "=========================================="
log "INFO" "Iniciando servicios de frontend..."
log "INFO" "=========================================="
log "INFO" " - MFE Principal  (host):    http://localhost:3000"
log "INFO" " - MFE Recruitment   (remote):  http://localhost:3001"
log "INFO" " - MFE Settings   (remote):  http://localhost:3002"
log "INFO" " - MFE Dashboard  (remote): http://localhost:3003"
log "INFO" " - MFE Requirements (remote): http://localhost:3004"
log "INFO" " - MFE Shared Components (remote): http://localhost:3005"
log "INFO" "=========================================="

declare -A PIDS

# Iniciar remotes opcionales
if [[ -d "$FRONTEND_DIR/mfe-settings" ]]; then
    log "INFO" "Iniciando mfe-settings en puerto 3002..."
    cd "$FRONTEND_DIR/mfe-settings"
    npm run dev &
    PIDS["mfe-settings"]=$!
fi

# Iniciar remotes requeridos
if [[ -d "$FRONTEND_DIR/mfe-recruitments" ]]; then
    log "INFO" "Iniciando mfe-recruitments en puerto 3001..."
    cd "$FRONTEND_DIR/mfe-recruitments"
    npm run dev &
    PIDS["mfe-recruitments"]=$!
fi

if [[ -d "$FRONTEND_DIR/mfe-dashboard" ]]; then
    log "INFO" "Iniciando mfe-dashboard en puerto 3003..."
    cd "$FRONTEND_DIR/mfe-dashboard"
    npm run dev &
    PIDS["mfe-dashboard"]=$!
fi

if [[ -d "$FRONTEND_DIR/mfe-requirements" ]]; then
    log "INFO" "Iniciando mfe-requirements en puerto 3004..."
    cd "$FRONTEND_DIR/mfe-requirements"
    npm run dev &
    PIDS["mfe-requirements"]=$!
fi

if [[ -d "$FRONTEND_DIR/mfe-shared-components" ]]; then
    log "INFO" "Iniciando mfe-shared-components en puerto 3005..."
    cd "$FRONTEND_DIR/mfe-shared-components"
    npm run dev &
    PIDS["mfe-shared-components"]=$!
fi

# El host (mfe-principal) arranca al final para que los remotes estén listos
log "INFO" "Iniciando mfe-principal en puerto 3000..."
cd "$FRONTEND_DIR/mfe-principal"
npm run dev &
PIDS["mfe-principal"]=$!

log "SUCCESS" "Servicios de frontend iniciados"
log "INFO" "PIDs: $(for k in "${!PIDS[@]}"; do echo -n "$k=${PIDS[$k]} "; done)"
log "INFO" "Presiona Ctrl+C para detener todos los servicios"

cleanup() {
    log "INFO" "Deteniendo servicios..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    log "SUCCESS" "Servicios detenidos"
    exit 0
}

trap cleanup SIGINT SIGTERM

wait
