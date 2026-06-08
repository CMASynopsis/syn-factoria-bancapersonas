#!/bin/bash
# location: scripts/k8s/wildfly/modules/kubectl.sh
# Shared kubectl helpers: check, context validation, pod/deployment queries

# ── Verificar que kubectl esté instalado ──
check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    log "ERROR" "kubectl no está instalado o no está en el PATH."
    exit 1
  fi
  log "DEBUG" "kubectl binary found."
}

# ── Validar que el contexto de kubectl coincida con K8S_CONTEXT (si está definido) ──
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

# ── Obtener el nombre del primer pod del deployment ──
get_pod_name() {
  local pod_name
  pod_name=$(kubectl get pod -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  echo "${pod_name}"
}

# ── Obtener el nombre del deployment ──
get_deploy_name() {
  local deploy_name
  deploy_name=$(kubectl get deployment -n "${K8S_NAMESPACE}" -l app=geniahr-wildfly \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  echo "${deploy_name}"
}

# ── Verificar que exista al menos un pod ──
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

# ── Verificar que exista el deployment ──
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
