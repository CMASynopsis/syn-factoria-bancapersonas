#!/bin/bash
set -euo pipefail

# =============================================================================
# Wildfly K8s — Run
# =============================================================================
# Operaciones sobre el pod Wildfly desplegado en Kubernetes:
# estado, logs, SSH, restart, scale, exec.
#
# Uso: ./scripts/k8s/wildfly/run.sh <comando> [-p|--profile <perfil>]
#
# Perfiles: dev (default), staging, prod
# =============================================================================

# ── SCRIPT_DIR con sufijo único (uuidv4{18}) — evitar colisiones ──
script_dir_a1b2c3d4e5f6a7b8c9d0() { echo "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"; }

# ── Cargar utilidades compartidas ──
source "$(script_dir_a1b2c3d4e5f6a7b8c9d0)/../../commons/log.sh"
source "$(script_dir_a1b2c3d4e5f6a7b8c9d0)/../../commons/get.sh"
source "$(script_dir_a1b2c3d4e5f6a7b8c9d0)/../../commons/wait.sh"

MODULE_NAME="k8s-wildfly-run"
LOG_MODULE_NAME="$MODULE_NAME"

# ============================================================================
# Configuración inicial (antes de parsear argumentos)
# ============================================================================

# Perfil por defecto
PROFILE="dev"

# Cargar vars del perfil
load_env_vars "${PROFILE}" "$(script_dir_a1b2c3d4e5f6a7b8c9d0)"

# ============================================================================
# Variables con defaults — Prioridad: ENV_VAR > VAR > profile.env > inline
# ============================================================================

K8S_NAMESPACE="$(set_with_fallback "K8S_NAMESPACE" "wildfly")"
WILDFLY_DEPLOY_USER="$(set_with_fallback "WILDFLY_DEPLOY_USER" "deploy")"
WILDFLY_HTTP_PORT="$(set_with_fallback "WILDFLY_HTTP_PORT" "8080")"
WILDFLY_ADMIN_PORT="$(set_with_fallback "WILDFLY_ADMIN_PORT" "9990")"
WILDFLY_IMAGE="$(set_with_fallback "WILDFLY_IMAGE" "wildfly-ssh:26.1.2.Final")"
LOCAL_SSH_PORT="$(set_with_fallback "LOCAL_SSH_PORT" "2222")"

# ============================================================================
# Funciones auxiliares
# ============================================================================

# Mostrar ayuda
show_usage() {
  cat <<EOF
Uso: $(basename "$0") <comando> [opciones]

Comandos:
  status      Mostrar estado del deployment, pods y servicios
  logs        Mostrar logs del pod (follow)
  ssh         Conectarse via SSH al pod (port-forward + ssh)
  restart     Hacer rollout restart del deployment
  scale N     Escalar el deployment a N réplicas
  exec <cmd>  Ejecutar un comando en el pod

Opciones:
  -p, --profile <perfil>  Perfil de configuracion (dev, staging, prod)
                            Por defecto: dev
  -h, --help              Mostrar esta ayuda

Ejemplos:
  ./scripts/k8s/wildfly/run.sh status
  ./scripts/k8s/wildfly/run.sh logs
  ./scripts/k8s/wildfly/run.sh ssh
  ./scripts/k8s/wildfly/run.sh restart
  ./scripts/k8s/wildfly/run.sh scale 3
  ./scripts/k8s/wildfly/run.sh exec -- ls -la /opt/jboss/wildfly/standalone/deployments
EOF
}

# Verificar kubectl
check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    log "ERROR" "kubectl no está instalado o no está en el PATH."
    exit 1
  fi
}

# Obtener el nombre del primer pod del deployment
get_pod_name() {
  local pod_name
  pod_name=$(kubectl get pod -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  echo "${pod_name}"
}

# Obtener el nombre del deployment
get_deploy_name() {
  local deploy_name
  deploy_name=$(kubectl get deployment -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  echo "${deploy_name}"
}

# Verificar que exista al menos un pod
require_pod() {
  local pod_name
  pod_name=$(get_pod_name)
  if [[ -z "${pod_name}" ]]; then
    log "ERROR" "No se encontró ningún pod con label app=geniahr-wildfly en namespace '${K8S_NAMESPACE}'."
    log "INFO" "Ejecute primero: ./scripts/k8s/wildfly/configure.sh apply"
    exit 1
  fi
  echo "${pod_name}"
}

# Verificar que exista el deployment
require_deployment() {
  local deploy_name
  deploy_name=$(get_deploy_name)
  if [[ -z "${deploy_name}" ]]; then
    log "ERROR" "No se encontró deployment con label app=geniahr-wildfly en namespace '${K8S_NAMESPACE}'."
    log "INFO" "Ejecute primero: ./scripts/k8s/wildfly/configure.sh apply"
    exit 1
  fi
  echo "${deploy_name}"
}

# Mostrar estado completo
show_status() {
  check_kubectl

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Wildfly K8s — Estado"
  echo "═══════════════════════════════════════════════════════════"
  echo "  Namespace:    ${K8S_NAMESPACE}"
  echo "  Perfil:       ${PROFILE}"
  echo ""

  # Deployment
  local deploy_name
  deploy_name=$(get_deploy_name)
  if [[ -n "${deploy_name}" ]]; then
    echo "  ── Deployment ──────────────────────────────────────"
    kubectl get deployment -n "${K8S_NAMESPACE}" "${deploy_name}" -o wide 2>/dev/null || \
      echo "  (no disponible)"
    echo ""
  else
    echo "  Deployment:   (no encontrado)"
    echo ""
  fi

  # Pods
  local pod_list
  pod_list=$(kubectl get pod -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
  if [[ -n "${pod_list}" ]]; then
    echo "  ── Pods ────────────────────────────────────────────"
    kubectl get pod -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o wide 2>/dev/null || \
      echo "  (no disponible)"
    echo ""
  else
    echo "  Pods:         (no encontrados)"
    echo ""
  fi

  # Services
  local svc_list
  svc_list=$(kubectl get service -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
  if [[ -n "${svc_list}" ]]; then
    echo "  ── Services ────────────────────────────────────────"
    kubectl get service -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o wide 2>/dev/null || \
      echo "  (no disponible)"
    echo ""
  else
    echo "  Services:     (no encontrados)"
    echo ""
  fi

  # ConfigMap
  local cm_list
  cm_list=$(kubectl get configmap -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
  if [[ -n "${cm_list}" ]]; then
    echo "  ConfigMaps:   ${cm_list}"
  fi

  # PVC
  local pvc_list
  pvc_list=$(kubectl get pvc -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
  if [[ -n "${pvc_list}" ]]; then
    echo "  PVCs:         ${pvc_list}"
  fi

  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

# Mostrar logs del pod
show_logs() {
  check_kubectl
  local pod_name
  pod_name=$(require_pod)

  log "INFO" "Mostrando logs de '${pod_name}' (Ctrl+C para salir)..."
  echo "───────────────────────────────────────────────────────────"
  kubectl logs -n "${K8S_NAMESPACE}" -f "${pod_name}"
}

# Conectarse via SSH al pod mediante port-forward
ssh_into_pod() {
  check_kubectl
  local pod_name
  pod_name=$(require_pod)

  log "INFO" "Iniciando port-forward para SSH al pod '${pod_name}'..."
  log "INFO" "  Puerto local: ${LOCAL_SSH_PORT} → pod:22"
  log "INFO" "  Usuario: ${WILDFLY_DEPLOY_USER}"
  log "INFO" ""

  # Iniciar port-forward en background
  kubectl port-forward -n "${K8S_NAMESPACE}" "pod/${pod_name}" "${LOCAL_SSH_PORT}:22" &
  local pf_pid=$!

  # Asegurar limpieza del port-forward al salir
  cleanup() {
    kill "${pf_pid}" 2>/dev/null || true
    wait "${pf_pid}" 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM

  # Esperar a que el port-forward esté listo
  sleep 2

  # Verificar que el port-forward sigue vivo
  if ! kill -0 "${pf_pid}" 2>/dev/null; then
    log "ERROR" "El port-forward falló al iniciar."
    log "INFO" "Verifique que el pod esté en estado Running."
    exit 1
  fi

  log "INFO" "Conectando via SSH a localhost:${LOCAL_SSH_PORT}..."
  log "INFO" "Nota: La primera vez deberá aceptar la huella del host."
  echo ""

  # Conectar SSH
  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -p "${LOCAL_SSH_PORT}" \
      "${WILDFLY_DEPLOY_USER}@localhost" "$@"
}

# Hacer rollout restart del deployment
restart_deployment() {
  check_kubectl
  local deploy_name
  deploy_name=$(require_deployment)

  log "INFO" "Reiniciando deployment '${deploy_name}' (rollout restart)..."
  kubectl rollout restart -n "${K8S_NAMESPACE}" "deployment/${deploy_name}"

  log "INFO" "Esperando que el nuevo rollout esté listo..."
  if kubectl rollout status -n "${K8S_NAMESPACE}" "deployment/${deploy_name}" --timeout=300s; then
    log "SUCCESS" "Deployment '${deploy_name}' reiniciado correctamente."
  else
    log "ERROR" "Timeout esperando el rollout. Verifique el estado con: $(basename "$0") status"
    exit 1
  fi
}

# Escalar el deployment
scale_deployment() {
  check_kubectl
  local deploy_name
  deploy_name=$(require_deployment)

  local replicas="${1:-}"
  if [[ -z "${replicas}" ]]; then
    log "ERROR" "Debe especificar el número de réplicas."
    log "INFO" "Uso: $(basename "$0") scale <N>"
    exit 1
  fi

  # Validar que sea un número
  if ! [[ "${replicas}" =~ ^[0-9]+$ ]]; then
    log "ERROR" "El número de réplicas debe ser un entero positivo: '${replicas}'"
    exit 1
  fi

  log "INFO" "Escalando deployment '${deploy_name}' a ${replicas} réplica(s)..."
  kubectl scale -n "${K8S_NAMESPACE}" "deployment/${deploy_name}" --replicas="${replicas}"

  log "INFO" "Esperando que el escalado esté completo..."
  if kubectl rollout status -n "${K8S_NAMESPACE}" "deployment/${deploy_name}" --timeout=300s; then
    log "SUCCESS" "Deployment '${deploy_name}' escalado a ${replicas} réplica(s)."
  else
    log "ERROR" "Timeout esperando el escalado. Verifique con: $(basename "$0") status"
    exit 1
  fi
}

# Ejecutar un comando en el pod
exec_in_pod() {
  check_kubectl
  local pod_name
  pod_name=$(require_pod)

  if [[ $# -eq 0 ]]; then
    log "ERROR" "Debe especificar un comando a ejecutar."
    log "INFO" "Uso: $(basename "$0") exec <comando>"
    log "INFO" "Ejemplo: $(basename "$0") exec -- ls -la /opt/jboss/wildfly/standalone/deployments/"
    exit 1
  fi

  log "INFO" "Ejecutando en pod '${pod_name}': $*"
  kubectl exec -n "${K8S_NAMESPACE}" -it "${pod_name}" -- "$@"
}

# ============================================================================
# Parseo de argumentos
# ============================================================================

COMMAND=""
SCALE_REPLICAS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile)
      PROFILE="$2"
      shift 2
      # Recargar variables del perfil
      load_env_vars "${PROFILE}" "$(script_dir_a1b2c3d4e5f6a7b8c9d0)"
      # Re-evaluar variables
      K8S_NAMESPACE="$(set_with_fallback "K8S_NAMESPACE" "wildfly")"
      WILDFLY_DEPLOY_USER="$(set_with_fallback "WILDFLY_DEPLOY_USER" "deploy")"
      WILDFLY_HTTP_PORT="$(set_with_fallback "WILDFLY_HTTP_PORT" "8080")"
      WILDFLY_ADMIN_PORT="$(set_with_fallback "WILDFLY_ADMIN_PORT" "9990")"
      LOCAL_SSH_PORT="$(set_with_fallback "LOCAL_SSH_PORT" "2222")"
      ;;
    status|logs|ssh|restart)
      COMMAND="$1"
      shift
      if [[ "${COMMAND}" == "ssh" ]]; then
        break
      fi
      ;;
    scale)
      COMMAND="$1"
      shift
      # El siguiente argumento es el número de réplicas
      if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        SCALE_REPLICAS="$1"
        shift
      fi
      ;;
    exec)
      COMMAND="$1"
      shift
      # El resto de args se pasan como comando
      break
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      log "ERROR" "Argumento desconocido: $1"
      show_usage
      exit 1
      ;;
  esac
done

# ============================================================================
# Main
# ============================================================================

if [[ -z "${COMMAND:-}" ]]; then
  show_usage
  exit 1
fi

case "${COMMAND}" in
  status)
    show_status
    ;;
  logs)
    show_logs
    ;;
  ssh)
    ssh_into_pod "$@"
    ;;
  restart)
    restart_deployment
    ;;
  scale)
    scale_deployment "${SCALE_REPLICAS}"
    ;;
  exec)
    exec_in_pod "$@"
    ;;
  *)
    log "ERROR" "Comando desconocido: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
