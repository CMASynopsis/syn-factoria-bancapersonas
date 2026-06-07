#!/bin/bash
# CMA Factoria - Init Graphify Script
# Description: Installs and runs graphify to build a project knowledge graph
# Usage: ./init_graphify.sh
#   graphify is a CLI tool (PyPI: graphifyy) that builds a queryable knowledge graph
#   from a codebase. If not installed, the script offers interactive installation.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================
# Cargar commons
# ============================================
export MODULE_NAME="init_graphify"
source "$PROJECT_DIR/scripts/commons/log.sh"
source "$PROJECT_DIR/scripts/commons/validate.sh"

# ============================================
# Verificar si graphify está instalado
# ============================================
log "INFO" "Verificando si graphify está instalado..."

if command -v graphify &> /dev/null; then
    log "SUCCESS" "graphify ya está instalado"
else
    log "WARN" "graphify no está instalado"

    echo ""
    echo "  Selecciona un método de instalación:"
    echo "    1) pip install graphifyy"
    echo "    2) uv tool install graphifyy"
    echo "    3) pipx install graphifyy"
    echo "    4) skip (saltar)"
    echo ""
    read -p "  Opción [1-4] (default: 1): " INSTALL_OPTION
    INSTALL_OPTION="${INSTALL_OPTION:-1}"

    case "$INSTALL_OPTION" in
        1|pip)
            log "INFO" "Instalando graphify con pip..."
            pip install graphifyy
            ;;
        2|uv)
            log "INFO" "Instalando graphify con uv..."
            uv tool install graphifyy
            ;;
        3|pipx)
            log "INFO" "Instalando graphify con pipx..."
            pipx install graphifyy
            ;;
        4|skip|s)
            log "INFO" "Instalación omitida por el usuario. Saliendo."
            exit 0
            ;;
        *)
            log "WARN" "Opción no válida '$INSTALL_OPTION'. Instalando con pip por defecto..."
            pip install graphifyy
            ;;
    esac

    # Verificar que la instalación fue exitosa
    if ! command -v graphify &> /dev/null; then
        handle_error "graphify no se instaló correctamente. Verifica el método e intenta de nuevo."
    fi

    log "SUCCESS" "graphify instalado correctamente"
fi

# ============================================
# Ejecutar graphify
# ============================================
log "INFO" "Construyendo grafo de conocimiento del proyecto en: $PROJECT_DIR"
log "INFO" "Usando backend claude-cli (extracción semántica diferida al asistente)"

graphify extract "$PROJECT_DIR" --backend claude-cli --out "$PROJECT_DIR"

# ============================================
# Finalizar
# ============================================
GRAPHIFY_OUT_DIR="$PROJECT_DIR/.graphify"
log "SUCCESS" "Grafo de conocimiento generado exitosamente"
log "INFO" "Directorio de salida: $GRAPHIFY_OUT_DIR"
log "INFO" "Para completar la extracción semántica ejecuta /graphify desde el asistente"
