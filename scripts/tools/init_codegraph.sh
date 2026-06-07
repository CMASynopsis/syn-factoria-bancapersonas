#!/bin/bash
# CMA Factoria - Init CodeGraph Script
# Description: Installs and runs CodeGraph to build a pre-indexed code knowledge graph
#   for AI agents (Claude Code, Cursor, Codex, OpenCode, etc.)
# Usage: ./init_codegraph.sh
#   codegraph (by Colby McHenry - @colbymchenry/codegraph) parses your codebase
#   with tree-sitter into a SQLite knowledge graph exposed via MCP, reducing
#   AI agent token usage by ~35% and tool calls by ~71%.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================
# Cargar commons
# ============================================
export MODULE_NAME="init_codegraph"
source "$PROJECT_DIR/scripts/commons/log.sh"
source "$PROJECT_DIR/scripts/commons/validate.sh"

# ============================================
# Verificar si codegraph está instalado
# ============================================
log "INFO" "Verificando si codegraph está instalado..."

if command -v codegraph &> /dev/null; then
    log "SUCCESS" "codegraph ya está instalado"
else
    log "WARN" "codegraph no está instalado"

    echo ""
    echo "  Selecciona un método de instalación:"
    echo "    1) standalone (curl install.sh - no requiere Node.js)"
    echo "    2) npm install -g @colbymchenry/codegraph"
    echo "    3) npx @colbymchenry/codegraph (un solo uso)"
    echo "    4) skip (saltar)"
    echo ""
    read -p "  Opción [1-4] (default: 1): " INSTALL_OPTION
    INSTALL_OPTION="${INSTALL_OPTION:-1}"

    case "$INSTALL_OPTION" in
        1|standalone)
            log "INFO" "Instalando codegraph con el instalador standalone..."
            curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
            ;;
        2|npm)
            log "INFO" "Instalando codegraph con npm..."
            npm install -g @colbymchenry/codegraph
            ;;
        3|npx)
            log "INFO" "Ejecutando codegraph con npx (instalación temporal)..."
            npx @colbymchenry/codegraph
            ;;
        4|skip|s)
            log "INFO" "Instalación omitida por el usuario. Saliendo."
            exit 0
            ;;
        *)
            log "WARN" "Opción no válida '$INSTALL_OPTION'. Instalando con standalone por defecto..."
            curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
            ;;
    esac

    # Verificar que la instalación fue exitosa
    if ! command -v codegraph &> /dev/null; then
        handle_error "codegraph no se instaló correctamente. Abre una nueva terminal o verifica el método."
    fi

    log "SUCCESS" "codegraph instalado correctamente"
fi

# ============================================
# Instalar agentes (wiring MCP)
# ============================================
log "INFO" "Configurando agentes (MCP server wiring)..."
log "INFO" "Detecta e integra Claude Code, Cursor, Codex, OpenCode, etc."

codegraph install

# ============================================
# Inicializar e indexar el proyecto
# ============================================
log "INFO" "Inicializando CodeGraph en el proyecto: $PROJECT_DIR"
log "INFO" "Indexando código con tree-sitter (símbolos, relaciones, call graph)..."

codegraph init -i "$PROJECT_DIR"

# ============================================
# Finalizar
# ============================================
CODEGRAPH_DIR="$PROJECT_DIR/.codegraph"
log "SUCCESS" "CodeGraph indexado exitosamente"
log "INFO" "Directorio de índice: $CODEGRAPH_DIR"
log "INFO" "Ejecuta 'codegraph status' para ver estadísticas del índice"
log "INFO" "Ejecuta 'codegraph query <busqueda>' para buscar símbolos"
