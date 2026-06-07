#!/bin/bash
# CMA Factoria - Init IA Script
# Description: Crea .opencode y .claude con symlinks a .iaconfig

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================
# Cargar commons
# ============================================
export MODULE_NAME="init_ia"
source "$PROJECT_DIR/scripts/commons/log.sh"
source "$PROJECT_DIR/scripts/commons/validate.sh"

# ============================================
# Validaciones
# ============================================
if [[ ! -d "$PROJECT_DIR/.iaconfig" ]]; then
    handle_error "No se encuentra .iaconfig en la raíz del proyecto"
fi

log "INFO" "Configurando .opencode y .claude"

# ============================================
# .opencode
# ============================================
log "INFO" "Creando .opencode..."
mkdir -p "$PROJECT_DIR/.opencode"

ln -sfn ../.iaconfig/agents "$PROJECT_DIR/.opencode/agents"
ln -sfn ../.iaconfig/skills "$PROJECT_DIR/.opencode/skills"

log "INFO" "  .opencode/agents -> ../.iaconfig/agents"
log "INFO" "  .opencode/skills -> ../.iaconfig/skills"

# ============================================
# .claude
# ============================================
log "INFO" "Creando .claude..."
mkdir -p "$PROJECT_DIR/.claude"

ln -sfn ../.iaconfig/agents "$PROJECT_DIR/.claude/agents"
ln -sfn ../.iaconfig/skills "$PROJECT_DIR/.claude/skills"
ln -sfn ../.iaconfig/commands "$PROJECT_DIR/.claude/commands"
ln -sfn ../.iaconfig/hooks "$PROJECT_DIR/.claude/hooks"

log "INFO" "  .claude/agents   -> ../.iaconfig/agents"
log "INFO" "  .claude/skills   -> ../.iaconfig/skills"
log "INFO" "  .claude/commands -> ../.iaconfig/commands"
log "INFO" "  .claude/hooks    -> ../.iaconfig/hooks"

log "SUCCESS" "Configuración de IA completada"
