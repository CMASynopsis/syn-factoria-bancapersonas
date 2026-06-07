#!/bin/bash
# CMA Factoria - Init Project Script
# Description: Inicializa un nuevo proyecto con la estructura básica
# Usage: ./init_project.sh <PROJECT_NAME>
#   PROJECT_NAME: Nombre del nuevo proyecto (ej: cma-mi-proyecto)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================
# Help
# ============================================
show_help() {
    cat << EOF
Usage: $(basename "$0") <PROJECT_NAME>

Inicializa un nuevo proyecto CMA Factoria con la estructura básica.

Arguments:
    PROJECT_NAME    Nombre del nuevo proyecto (obligatorio)

Example:
    $(basename "$0") cma-mi-proyecto

EOF
}

# ============================================
# Validaciones
# ============================================
if [[ $# -lt 1 ]]; then
    echo "Error: Falta el nombre del proyecto"
    show_help
    exit 1
fi

NEW_PROJECT_NAME="$1"
NEW_PROJECT_DIR="$PROJECT_ROOT/../$NEW_PROJECT_NAME"

if [[ -d "$NEW_PROJECT_DIR" ]]; then
    echo "Error: El directorio '$NEW_PROJECT_DIR' ya existe"
    exit 1
fi

echo "==========================================="
echo "Inicializando proyecto: $NEW_PROJECT_NAME"
echo "==========================================="

# ============================================
# Crear estructura de directorios
# ============================================
echo "Creando estructura de directorios..."

# Apps
mkdir -p "$NEW_PROJECT_DIR/apps/backend"
mkdir -p "$NEW_PROJECT_DIR/apps/frontend"

# Assets
mkdir -p "$NEW_PROJECT_DIR/assets"

# Contracts
mkdir -p "$NEW_PROJECT_DIR/contracts/openapi"
mkdir -p "$NEW_PROJECT_DIR/contracts/schemas"

# Docs
mkdir -p "$NEW_PROJECT_DIR/docs/architecture"
mkdir -p "$NEW_PROJECT_DIR/docs/backend"
mkdir -p "$NEW_PROJECT_DIR/docs/database"
mkdir -p "$NEW_PROJECT_DIR/docs/frontend"
mkdir -p "$NEW_PROJECT_DIR/docs/history"
mkdir -p "$NEW_PROJECT_DIR/docs/latex"
mkdir -p "$NEW_PROJECT_DIR/docs/scripts"
mkdir -p "$NEW_PROJECT_DIR/docs/sequence"
mkdir -p "$NEW_PROJECT_DIR/docs/test/jmeter"
mkdir -p "$NEW_PROJECT_DIR/docs/uml"

# Infra
mkdir -p "$NEW_PROJECT_DIR/infra/database"
mkdir -p "$NEW_PROJECT_DIR/infra/docker"
mkdir -p "$NEW_PROJECT_DIR/infra/docker/messaging"
mkdir -p "$NEW_PROJECT_DIR/infra/k8s"

# Scripts
mkdir -p "$NEW_PROJECT_DIR/scripts/backend"
mkdir -p "$NEW_PROJECT_DIR/scripts/commons"
mkdir -p "$NEW_PROJECT_DIR/scripts/database"
mkdir -p "$NEW_PROJECT_DIR/scripts/docker/backend/modules"
mkdir -p "$NEW_PROJECT_DIR/scripts/docker/database/modules"
mkdir -p "$NEW_PROJECT_DIR/scripts/frontend"
mkdir -p "$NEW_PROJECT_DIR/scripts/jmeter/plugins"
mkdir -p "$NEW_PROJECT_DIR/scripts/k8s"
mkdir -p "$NEW_PROJECT_DIR/scripts/latex"
mkdir -p "$NEW_PROJECT_DIR/scripts/tools"

# Tests
mkdir -p "$NEW_PROJECT_DIR/tests/jmeter"

# ============================================
# Crear archivos .keep en directorios vacíos
# ============================================
keep_dirs=(
    "apps/backend"
    "apps/frontend"
    "assets"
    "contracts/openapi"
    "contracts/schemas"
    "docs/architecture"
    "docs/backend"
    "docs/database"
    "docs/frontend"
    "docs/history"
    "docs/latex"
    "docs/sequence"
    "docs/test/jmeter"
    "docs/uml"
    "infra/database"
    "infra/docker"
    "infra/docker/messaging"
    "infra/k8s"
    "scripts/database"
    "scripts/docker/backend/modules"
    "scripts/docker/database/modules"
    "scripts/jmeter/plugins"
    "scripts/k8s"
    "scripts/latex"
    "tests/jmeter"
)

for dir in "${keep_dirs[@]}"; do
    touch "$NEW_PROJECT_DIR/$dir/.keep"
done

# ============================================
# Copiar scripts/commons
# ============================================
echo "Copiando scripts/commons..."
cp -r "$PROJECT_ROOT/scripts/commons/." "$NEW_PROJECT_DIR/scripts/commons/"

# ============================================
# Copiar scripts de backend y frontend
# ============================================
echo "Copiando scripts de desarrollo local..."
[[ -f "$PROJECT_ROOT/scripts/backend/local_start.sh" ]] && \
    cp "$PROJECT_ROOT/scripts/backend/local_start.sh" "$NEW_PROJECT_DIR/scripts/backend/"
[[ -f "$PROJECT_ROOT/scripts/backend/local_stop.sh" ]] && \
    cp "$PROJECT_ROOT/scripts/backend/local_stop.sh" "$NEW_PROJECT_DIR/scripts/backend/"
[[ -f "$PROJECT_ROOT/scripts/frontend/local_start.sh" ]] && \
    cp "$PROJECT_ROOT/scripts/frontend/local_start.sh" "$NEW_PROJECT_DIR/scripts/frontend/"
[[ -f "$PROJECT_ROOT/scripts/frontend/local_stop.sh" ]] && \
    cp "$PROJECT_ROOT/scripts/frontend/local_stop.sh" "$NEW_PROJECT_DIR/scripts/frontend/"

# ============================================
# Copiar scripts/tools
# ============================================
echo "Copiando scripts/tools..."
cp "$PROJECT_ROOT/scripts/tools/init_project.sh" "$NEW_PROJECT_DIR/scripts/tools/"

# ============================================
# Copiar scripts/jmeter (install + plugins)
# ============================================
echo "Copiando scripts/jmeter..."
[[ -f "$PROJECT_ROOT/scripts/jmeter/install.sh" ]] && \
    cp "$PROJECT_ROOT/scripts/jmeter/install.sh" "$NEW_PROJECT_DIR/scripts/jmeter/"
[[ -f "$PROJECT_ROOT/scripts/jmeter/profile.env.example" ]] && \
    cp "$PROJECT_ROOT/scripts/jmeter/profile.env.example" "$NEW_PROJECT_DIR/scripts/jmeter/"
cp -r "$PROJECT_ROOT/scripts/jmeter/plugins/." "$NEW_PROJECT_DIR/scripts/jmeter/plugins/"

# ============================================
# Copiar infra/docker/messaging
# ============================================
echo "Copiando infra/docker/messaging..."
if [ -d "$PROJECT_ROOT/infra/docker/messaging" ]; then
    cp -r "$PROJECT_ROOT/infra/docker/messaging/." "$NEW_PROJECT_DIR/infra/docker/messaging/"
fi

# ============================================
# Copiar documentación de scripts/commons
# ============================================
echo "Copiando documentación de commons..."
[[ -f "$PROJECT_ROOT/docs/scripts/commons.md" ]] && \
    cp "$PROJECT_ROOT/docs/scripts/commons.md" "$NEW_PROJECT_DIR/docs/scripts/"

# ============================================
# Copiar archivos de configuración Git
# ============================================
echo "Copiando archivos de configuración Git..."
[[ -f "$PROJECT_ROOT/.gitignore" ]] && cp "$PROJECT_ROOT/.gitignore" "$NEW_PROJECT_DIR/"
[[ -f "$PROJECT_ROOT/.gitattributes" ]] && cp "$PROJECT_ROOT/.gitattributes" "$NEW_PROJECT_DIR/"

# ============================================
# Copiar .iaconfig
# ============================================
echo "Copiando configuración de agentes..."
cp -r "$PROJECT_ROOT/.iaconfig" "$NEW_PROJECT_DIR/"

# ============================================
# Crear CLAUDE.md base
# ============================================
echo "Creando CLAUDE.md..."
cat > "$NEW_PROJECT_DIR/CLAUDE.md" << EOF
# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Stack

| Capa | Tecnología | Puerto |
|------|-----------|--------|
| Backend | Quarkus 3 (Java 21), RESTEasy Reactive | 8080 |
| MFE Principal | React 18 + Webpack Module Federation (host) | 3000 |
| MFE Remote | React 18 + Module Federation (remote) | 3001+ |

## Comandos de desarrollo

### Backend (Quarkus)

\`\`\`bash
cd apps/backend/<service>
./mvnw quarkus:dev
\`\`\`

### Frontend

\`\`\`bash
./scripts/frontend/local_start.sh
\`\`\`

## Agentes

| Agente | Rol | Cuándo usarlo |
|--------|-----|---------------|
| **Oscar** | Orquestador | Features completos que necesitan scout→ivan→jester |
| **Scout** | Investigador | Analizar código y generar SPEC.md |
| **Ivan** | Implementador | Escribir código según un plan/SPEC |
| **Jester** | QA / Validador | Verificar builds, puertos y compliance con SPEC |
| **DBForge** | Base de datos | Crear o modificar tablas, SPs e índices PostgreSQL |
EOF

# ============================================
# Crear AGENTS.md base
# ============================================
echo "Creando AGENTS.md..."
cat > "$NEW_PROJECT_DIR/AGENTS.md" << 'EOF'
# AGENTS.md - Agentic Delivery OS

## Estructura del Proyecto

```
.
├── apps/
│   ├── backend/                # Microservicios (Quarkus)
│   └── frontend/               # Microfrontends (React + Module Federation)
├── assets/                     # Recursos estáticos del proyecto
├── contracts/
│   ├── openapi/                # Contratos OpenAPI (fuente de verdad)
│   └── schemas/                # Esquemas de datos (JSON Schema, etc.)
├── docs/                       # Documentación técnica
├── infra/
│   ├── database/               # Scripts SQL por base de datos
│   ├── docker/                 # Dockerfiles
│   │   └── messaging/          # Infraestructura de mensajería (Kafka)
│   └── k8s/                    # Manifiestos Kubernetes
├── scripts/
│   ├── commons/                # Funciones reutilizables (log, get, check, wait)
│   ├── backend/                # local_start.sh / local_stop.sh
│   ├── frontend/               # local_start.sh / local_stop.sh
│   ├── database/               # impact_*.sh — aplica SQL al esquema
│   ├── docker/                 # build.sh / run.sh por servicio
│   ├── k8s/                    # configure.sh / run.sh por servicio
│   ├── jmeter/                 # install.sh + planes de prueba
│   ├── latex/                  # compile-pdf.sh / compile-puml.sh
│   └── tools/                  # init_project.sh
├── tests/
│   └── jmeter/                 # Planes .jmx y propiedades por perfil
└── AGENTS.md
```

## Reglas de Estilo

- **Naming**: kebab-case para archivos y directorios, camelCase para JS/TS
- **Comentarios**: Solo si el WHY no es obvio
- **Testing**: Tests junto al código con sufijo `.test.ts` o `.spec.ts`

## Definiciones de roles disponibles

Consultar `.iaconfig/agents/` para definiciones de agentes.
EOF

# ============================================
# Crear BEADS.json base
# ============================================
echo "Creando BEADS.json..."
cat > "$NEW_PROJECT_DIR/BEADS.json" << 'EOF'
{
  "version": "1.0.0",
  "columns": [
    { "id": "backlog",     "title": "Backlog" },
    { "id": "in_progress", "title": "In Progress" },
    { "id": "review",      "title": "Review" },
    { "id": "done",        "title": "Done" }
  ],
  "cards": []
}
EOF

# ============================================
# Inicializar Git y hacer commit inicial
# ============================================
echo "Inicializando repositorio Git..."
cd "$NEW_PROJECT_DIR"
git init
git add -A
git commit -m "Commit inicial: estructura base del proyecto"

echo "==========================================="
echo "Proyecto '$NEW_PROJECT_NAME' creado exitosamente"
echo "Ubicación: $NEW_PROJECT_DIR"
echo "==========================================="
echo ""
echo "Próximos pasos:"
echo "1. cd $NEW_PROJECT_DIR"
echo "2. Actualizar CLAUDE.md con el stack y convenciones del proyecto"
echo "3. Agregar microservicios en apps/backend/"
echo "4. Agregar MFEs en apps/frontend/"
echo "5. Definir contratos OpenAPI en contracts/openapi/"
echo "6. Configurar infra/k8s/ y infra/docker/"
