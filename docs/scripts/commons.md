# Scripts Commons

Utilidades compartidas para los scripts de automatización.

## Estructura

```
scripts/commons/
├── check.sh       # Funciones de verificación
├── get.sh         # Funciones de obtención
├── log.sh         # Funciones de logging
├── validate.sh    # Funciones de validación
└── wait.sh        # Funciones de espera
```

## log.sh

Funciones de logging con colores para la terminal.

### Funciones

| Función | Descripción |
|---------|-------------|
| `log <LEVEL> <MESSAGE>` | Imprime mensaje con nivel |
| `handle_error <MESSAGE>` | Imprime error y sale |
| `log_progress <MESSAGE>` | Spinner de progreso |

### Niveles

- `INFO` - Información general (azul)
- `SUCCESS` - Éxito (verde)
- `WARN` - Advertencia (amarillo)
- `ERROR` - Error (rojo)
- `DEBUG` - Depuración (cyan)

### Variables de Entorno

```bash
# Habilitar logs DEBUG
export DEBUG_ENABLED=true

# Guardar logs en archivo
export LOG_TO_FILE=true

# Nombre del módulo para logs
export MODULE_NAME="mi-modulo"
```

### Uso

```bash
source "$PROJECT_ROOT/scripts/commons/log.sh"
MODULE_NAME="backend"

log "INFO" "Iniciando servicio..."
log "SUCCESS" "Servicio iniciado correctamente"
log "ERROR" "Error al iniciar servicio"
```

## wait.sh

Funciones de espera con logging.

### Funciones

| Función | Descripción |
|---------|-------------|
| `wait_for_running_pod` | Espera pod K8s en estado Running |
| `wait_for_status_change` | Espera cambio de estado |
| `wait_seconds <SECONDS>` | Espera simple con mensaje |

### Uso

```bash
source "$PROJECT_ROOT/scripts/commons/wait.sh"

wait_seconds 5 "Iniciando proceso..."
```

## validate.sh

Funciones de validación de entrada.

*(Contenido específico según implementación)*

## get.sh

Funciones de obtención de recursos.

*(Contenido específico según implementación)*

## check.sh

Funciones de verificación de estado.

*(Contenido específico según implementación)*

## Uso en Scripts

Para usar las utilidades commons en un script:

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/commons/log.sh"
MODULE_NAME="mi-script"

log "INFO" "Mi mensaje"
```