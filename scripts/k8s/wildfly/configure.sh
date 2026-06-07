#!/bin/bash
set -euo pipefail

# =============================================================================
# Wildfly K8s — Configure
# =============================================================================
# Aplica, valida y destruye los recursos Kubernetes de Wildfly+SSH.
# Los manifiestos YAML se encuentran en infra/k8s/wildfly/ y se aplican
# en orden: namespace → configmap → secrets → pvc → deployment → service.
#
# Uso: ./scripts/k8s/wildfly/configure.sh <comando> [-p|--profile <perfil>]
#
# Perfiles: dev (default), staging, prod
# =============================================================================

# ── SCRIPT_DIR con sufijo único (uuidv4{18}) — evitar colisiones ──
script_dir_c1d2e3f4a5b6c7d8e9f0() { echo "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"; }

# ── Cargar utilidades compartidas ──
source "$(script_dir_c1d2e3f4a5b6c7d8e9f0)/../../commons/log.sh"
source "$(script_dir_c1d2e3f4a5b6c7d8e9f0)/../../commons/get.sh"

MODULE_NAME="k8s-wildfly-configure"
LOG_MODULE_NAME="$MODULE_NAME"

# ============================================================================
# Configuración inicial (antes de parsear argumentos)
# ============================================================================

# Perfil por defecto
PROFILE="dev"

# ── Early parse: detectar --profile antes de inicializar variables ──
for arg in "$@"; do
  case "${arg}" in
    -p|--profile)
      capture_profile=true
      ;;
    *)
      if [[ "${capture_profile:-}" == "true" ]]; then
        PROFILE="${arg}"
        break
      fi
      ;;
  esac
done

# Cargar vars del perfil
load_env_vars "${PROFILE}" "$(script_dir_c1d2e3f4a5b6c7d8e9f0)"

# ============================================================================
# Variables con defaults — Prioridad: ENV_VAR > VAR > profile.env > inline
# ============================================================================

# Kubernetes
K8S_NAMESPACE="$(set_with_fallback "K8S_NAMESPACE" "wildfly")"
K8S_CONTEXT="$(set_with_fallback "K8S_CONTEXT" "")"

# Imagen y réplicas
WILDFLY_IMAGE="$(set_with_fallback "WILDFLY_IMAGE" "wildfly-ssh:26.1.2.Final")"
WILDFLY_REPLICAS="$(set_with_fallback "WILDFLY_REPLICAS" "1")"

# Puertos
WILDFLY_HTTP_PORT="$(set_with_fallback "WILDFLY_HTTP_PORT" "8080")"
WILDFLY_ADMIN_PORT="$(set_with_fallback "WILDFLY_ADMIN_PORT" "9990")"

# Usuario SSH
WILDFLY_DEPLOY_USER="$(set_with_fallback "WILDFLY_DEPLOY_USER" "deploy")"
WILDFLY_DEPLOY_PASSWORD="$(set_with_fallback "WILDFLY_DEPLOY_PASSWORD" "deploy")"
WILDFLY_SSH_PUBLIC_KEY="$(set_with_fallback "WILDFLY_SSH_PUBLIC_KEY" "")"

# JVM
WILDFLY_XMS="$(set_with_fallback "WILDFLY_XMS" "512m")"
WILDFLY_XMX="$(set_with_fallback "WILDFLY_XMX" "1024m")"
WILDFLY_JAVA_OPTS="$(set_with_fallback "WILDFLY_JAVA_OPTS" "")"

# Health checks
HEALTH_CHECK_TIMEOUT="$(set_with_fallback "HEALTH_CHECK_TIMEOUT" "120")"
HEALTH_CHECK_INTERVAL="$(set_with_fallback "HEALTH_CHECK_INTERVAL" "5")"

# Storage y Service
STORAGE_SIZE="$(set_with_fallback "STORAGE_SIZE" "1Gi")"
SERVICE_TYPE="$(set_with_fallback "SERVICE_TYPE" "ClusterIP")"

# Ruta a los manifiestos K8s
MANIFESTS_DIR="$(script_dir_c1d2e3f4a5b6c7d8e9f0)/../../../../infra/k8s/wildfly"

# Orden de aplicación de los manifiestos
MANIFEST_ORDER=(
  "namespace"
  "configmap"
  "secrets"
  "pvc"
  "deployment"
  "service"
)

# ============================================================================
# Funciones auxiliares
# ============================================================================

# Mostrar ayuda
show_usage() {
  cat <<EOF
Uso: $(basename "$0") <comando> [opciones]

Comandos:
  apply       Aplicar los manifiestos K8s en orden
  validate    Validar que los recursos estén creados y operativos
  destroy     Eliminar todos los recursos del namespace
  redeploy    Destruir y volver a aplicar (destroy + apply)

Opciones:
  -p, --profile <perfil>  Perfil de configuracion (dev, staging, prod)
                            Por defecto: dev
  -h, --help              Mostrar esta ayuda

Variables de entorno (prioridad: ENV_VAR > VAR > profile.env > default):
  K8S_NAMESPACE            Namespace K8s                    Default: wildfly
  K8S_CONTEXT              Contexto kubectl (si se define y no coincide, aborta)
  WILDFLY_IMAGE            Imagen Docker                    Default: wildfly-ssh:26.1.2.Final
  WILDFLY_REPLICAS         Réplicas del deployment          Default: 1
  WILDFLY_HTTP_PORT        Puerto HTTP                      Default: 8080
  WILDFLY_ADMIN_PORT       Puerto Admin                     Default: 9990
  WILDFLY_DEPLOY_USER      Usuario SSH para depliegues      Default: deploy
  WILDFLY_DEPLOY_PASSWORD  Password del usuario             Default: deploy
  WILDFLY_SSH_PUBLIC_KEY   Clave pública SSH                Default: (vacía)
  WILDFLY_XMS              Memoria XMS JVM                  Default: 512m
  WILDFLY_XMX              Memoria XMX JVM                  Default: 1024m
  STORAGE_SIZE             Tamaño del PVC                   Default: 1Gi
  SERVICE_TYPE             Tipo de servicio K8s             Default: ClusterIP
  HEALTH_CHECK_TIMEOUT     Timeout health check (seg)       Default: 120
  HEALTH_CHECK_INTERVAL    Intervalo health check (seg)     Default: 5

Ejemplos:
  ./scripts/k8s/wildfly/configure.sh apply
  ./scripts/k8s/wildfly/configure.sh apply -p prod
  ./scripts/k8s/wildfly/configure.sh validate
  ./scripts/k8s/wildfly/configure.sh destroy
  ./scripts/k8s/wildfly/configure.sh redeploy
  K8S_NAMESPACE=my-wildfly ./scripts/k8s/wildfly/configure.sh apply
EOF
}

# Verificar que kubectl esté instalado
check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    log "ERROR" "kubectl no está instalado o no está en el PATH."
    exit 1
  fi
  log "DEBUG" "kubectl binary found."
}

# Validar que el contexto de kubectl coincida con K8S_CONTEXT (si está definido)
# Si K8S_CONTEXT está vacío, solo muestra DEBUG y continúa.
# Si está definido y no coincide, ABORTA con error para evitar impacto en cluster incorrecto.
require_k8s_context() {
  local current_context
  current_context=$(kubectl config current-context 2>/dev/null || true)

  if [[ -z "${current_context}" ]]; then
    log "ERROR" "No se pudo obtener el contexto actual de Kubernetes."
    log "INFO" "Verifique su archivo kubeconfig (~/.kube/config)."
    exit 1
  fi

  if [[ -z "${K8S_CONTEXT}" ]]; then
    log "DEBUG" "Contexto kubectl actual: ${current_context} (K8S_CONTEXT no definido — se permite cualquier contexto)"
    return 0
  fi

  if [[ "${current_context}" != "${K8S_CONTEXT}" ]]; then
    log "ERROR" "Contexto actual '${current_context}' no coincide con el esperado '${K8S_CONTEXT}'."
    log "INFO" "Use: kubectl config use-context ${K8S_CONTEXT}"
    log "INFO" "O deshabilite esta validación: export K8S_CONTEXT=''"
    exit 1
  fi

  log "DEBUG" "Contexto kubectl OK: ${current_context}"
}

# Verificar que el namespace exista, crearlo si no
check_namespace() {
  if kubectl get namespace "${K8S_NAMESPACE}" &>/dev/null; then
    log "INFO" "Namespace '${K8S_NAMESPACE}' ya existe."
  else
    log "INFO" "Namespace '${K8S_NAMESPACE}' no existe. Creándolo..."
    kubectl create namespace "${K8S_NAMESPACE}"
    log "SUCCESS" "Namespace '${K8S_NAMESPACE}' creado."
  fi
}

# Aplicar un manifiesto YAML si existe
apply_manifest() {
  local name="$1"
  local file="${MANIFESTS_DIR}/${name}.yaml"

  if [[ ! -f "${file}" ]]; then
    log "WARN" "Manifiesto no encontrado — saltando: ${file}"
    return 0
  fi

  log "INFO" "Aplicando ${name}: ${file}"
  kubectl apply -f "${file}" --namespace "${K8S_NAMESPACE}"
  log "SUCCESS" "Recurso '${name}' aplicado correctamente."
}

# Aplicar todos los manifiestos en orden
apply_manifests() {
  check_kubectl
  require_k8s_context
  check_namespace

  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Aplicando manifiestos — perfil: ${PROFILE}"
  log "INFO" "  Namespace: ${K8S_NAMESPACE}"
  log "INFO" "  Manifiestos: ${MANIFESTS_DIR}"
  log "INFO" "═══════════════════════════════════════════════════════════"

  for manifest in "${MANIFEST_ORDER[@]}"; do
    apply_manifest "${manifest}"
  done

  log "SUCCESS" "Todos los manifiestos aplicados correctamente."
}

# Validar que los recursos K8s estén creados y operativos
validate_resources() {
  check_kubectl
  require_k8s_context

  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Validando recursos en namespace '${K8S_NAMESPACE}'"
  log "INFO" "═══════════════════════════════════════════════════════════"

  local has_errors=false

  # 1. Validar namespace
  if kubectl get namespace "${K8S_NAMESPACE}" &>/dev/null; then
    log "SUCCESS" "Namespace '${K8S_NAMESPACE}' existe."
  else
    log "ERROR" "Namespace '${K8S_NAMESPACE}' NO existe."
    has_errors=true
  fi

  # 2. Validar deployment
  local deploy_name
  deploy_name=$(kubectl get deployment -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "${deploy_name}" ]]; then
    local ready_replicas
    ready_replicas=$(kubectl get deployment -n "${K8S_NAMESPACE}" "${deploy_name}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired_replicas
    desired_replicas=$(kubectl get deployment -n "${K8S_NAMESPACE}" "${deploy_name}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    log "SUCCESS" "Deployment '${deploy_name}' — réplicas listas: ${ready_replicas}/${desired_replicas}"

    if [[ "${ready_replicas:-0}" -lt "${desired_replicas:-1}" ]]; then
      log "WARN" "No todas las réplicas están listas (${ready_replicas:-0}/${desired_replicas:-1})."
    fi
  else
    log "ERROR" "No se encontró deployment con label app=geniahr-wildfly."
    has_errors=true
  fi

  # 3. Validar pods
  local pod_list
  pod_list=$(kubectl get pod -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
  if [[ -n "${pod_list}" ]]; then
    for pod in ${pod_list}; do
      local phase
      phase=$(kubectl get pod -n "${K8S_NAMESPACE}" "${pod}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
      if [[ "${phase}" == "Running" ]]; then
        log "SUCCESS" "Pod '${pod}' — estado: ${phase}"
      else
        log "WARN" "Pod '${pod}' — estado: ${phase} (se esperaba Running)"
      fi
    done
  else
    log "ERROR" "No se encontraron pods con label app=geniahr-wildfly."
    has_errors=true
  fi

  # 4. Validar service
  local svc_name
  svc_name=$(kubectl get service -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "${svc_name}" ]]; then
    local svc_type
    svc_type=$(kubectl get service -n "${K8S_NAMESPACE}" "${svc_name}" -o jsonpath='{.spec.type}' 2>/dev/null || true)
    local cluster_ip
    cluster_ip=$(kubectl get service -n "${K8S_NAMESPACE}" "${svc_name}" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
    log "SUCCESS" "Service '${svc_name}' — tipo: ${svc_type}, clusterIP: ${cluster_ip}"
  else
    log "WARN" "No se encontró service con label app=geniahr-wildfly."
  fi

  # 5. Validar configmap si existe
  local cm_name
  cm_name=$(kubectl get configmap -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "${cm_name}" ]]; then
    log "SUCCESS" "ConfigMap '${cm_name}' existe."
  else
    log "INFO" "ConfigMap con label app=geniahr-wildfly no encontrado (opcional)."
  fi

  # 6. Validar secrets si existe
  local secret_name
  secret_name=$(kubectl get secret -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "${secret_name}" ]]; then
    log "SUCCESS" "Secret '${secret_name}' existe."
  else
    log "INFO" "Secret con label app=geniahr-wildfly no encontrado (opcional)."
  fi

  # 7. Validar PVC si existe
  local pvc_name
  pvc_name=$(kubectl get pvc -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "${pvc_name}" ]]; then
    local pvc_status
    pvc_status=$(kubectl get pvc -n "${K8S_NAMESPACE}" "${pvc_name}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
    log "SUCCESS" "PVC '${pvc_name}' — estado: ${pvc_status}"
  else
    log "INFO" "PVC con label app=geniahr-wildfly no encontrado (opcional)."
  fi

  echo ""
  if [[ "${has_errors}" == "true" ]]; then
    log "ERROR" "Validación completada con errores. Revise los mensajes anteriores."
    return 1
  else
    log "SUCCESS" "Validación completada — todos los recursos están en estado correcto."
    return 0
  fi
}

# Destruir todos los recursos del namespace
destroy_resources() {
  check_kubectl
  require_k8s_context

  if ! kubectl get namespace "${K8S_NAMESPACE}" &>/dev/null; then
    log "WARN" "El namespace '${K8S_NAMESPACE}' no existe. No hay nada que destruir."
    return 0
  fi

  echo ""
  log "WARN" "═══════════════════════════════════════════════════════════"
  log "WARN" "ATENCION: Esta a punto de eliminar TODOS los recursos."
  log "WARN" "  Namespace: ${K8S_NAMESPACE}"
  log "WARN" "  Perfil:    ${PROFILE}"
  log "WARN" "  Se eliminaran deployments, services, pods, PVCs, etc."
  log "WARN" "═══════════════════════════════════════════════════════════"
  echo ""
  read -r -p "Confirme escribiendo 'yes': " confirm

  if [[ "${confirm}" != "yes" ]]; then
    log "INFO" "Eliminación cancelada."
    return 0
  fi

  log "INFO" "Eliminando recursos en orden inverso..."

  # Eliminar en orden inverso (service → deployment → pvc → secrets → configmap)
  for manifest in service deployment pvc secrets configmap; do
    local file="${MANIFESTS_DIR}/${manifest}.yaml"
    if [[ -f "${file}" ]]; then
      log "INFO" "Eliminando ${manifest}..."
      kubectl delete -f "${file}" --namespace "${K8S_NAMESPACE}" --ignore-not-found=true &
    fi
  done

  # Esperar a que terminen los deletes
  wait

  # Finalmente eliminar el namespace (limpia cualquier recurso residual)
  log "INFO" "Eliminando namespace '${K8S_NAMESPACE}'..."
  kubectl delete namespace "${K8S_NAMESPACE}" --ignore-not-found=true

  log "SUCCESS" "Recursos eliminados correctamente."
}

# Redeploy: destroy + apply
redeploy() {
  check_kubectl
  require_k8s_context

  log "INFO" "═══════════════════════════════════════════════════════════"
  log "INFO" "  Redeploy — destruyendo y reaplicando recursos"
  log "INFO" "═══════════════════════════════════════════════════════════"

  # En redeploy no pedimos confirmación — el usuario ya sabe lo que hace
  if kubectl get namespace "${K8S_NAMESPACE}" &>/dev/null; then
    log "INFO" "Eliminando recursos existentes..."
    for manifest in service deployment pvc secrets configmap; do
      local file="${MANIFESTS_DIR}/${manifest}.yaml"
      if [[ -f "${file}" ]]; then
        kubectl delete -f "${file}" --namespace "${K8S_NAMESPACE}" --ignore-not-found=true 2>/dev/null &
      fi
    done
    wait
    log "INFO" "Recursos antiguos eliminados."
  fi

  apply_manifests
}

# ============================================================================
# Parseo de argumentos
# ============================================================================

COMMAND=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile)
      PROFILE="$2"
      shift 2
      # Recargar variables del perfil
      load_env_vars "${PROFILE}" "$(script_dir_c1d2e3f4a5b6c7d8e9f0)"
      # Re-evaluar variables con el nuevo perfil
      K8S_NAMESPACE="$(set_with_fallback "K8S_NAMESPACE" "wildfly")"
      WILDFLY_IMAGE="$(set_with_fallback "WILDFLY_IMAGE" "wildfly-ssh:26.1.2.Final")"
      WILDFLY_REPLICAS="$(set_with_fallback "WILDFLY_REPLICAS" "1")"
      WILDFLY_HTTP_PORT="$(set_with_fallback "WILDFLY_HTTP_PORT" "8080")"
      WILDFLY_ADMIN_PORT="$(set_with_fallback "WILDFLY_ADMIN_PORT" "9990")"
      WILDFLY_DEPLOY_USER="$(set_with_fallback "WILDFLY_DEPLOY_USER" "deploy")"
      WILDFLY_DEPLOY_PASSWORD="$(set_with_fallback "WILDFLY_DEPLOY_PASSWORD" "deploy")"
      WILDFLY_SSH_PUBLIC_KEY="$(set_with_fallback "WILDFLY_SSH_PUBLIC_KEY" "")"
      WILDFLY_XMS="$(set_with_fallback "WILDFLY_XMS" "512m")"
      WILDFLY_XMX="$(set_with_fallback "WILDFLY_XMX" "1024m")"
      STORAGE_SIZE="$(set_with_fallback "STORAGE_SIZE" "1Gi")"
      SERVICE_TYPE="$(set_with_fallback "SERVICE_TYPE" "ClusterIP")"
      ;;
    apply|validate|destroy|redeploy)
      COMMAND="$1"
      shift
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
  apply)
    apply_manifests
    ;;
  validate)
    validate_resources
    ;;
  destroy)
    destroy_resources
    ;;
  redeploy)
    redeploy
    ;;
  *)
    log "ERROR" "Comando desconocido: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
