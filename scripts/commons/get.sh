#!/bin/bash
#location: scripts/commons/get.sh

# Función para capturar el directorio base del script
ENVIRONMENT=${ENVIRONMENT:-"dev"}

get_commons_dir() {
  echo "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
}

get_script_dir() {
  echo $(dirname "$(get_commons_dir)")
}

get_project_dir() {
  echo $(dirname "$(get_script_dir)")
}

get_workspace_dir() {
  echo $(get_project_dir)/workspace/$ENVIRONMENT
}

# ------------------------------------------------------------------
# Helper: obtener el directorio scripts/k8s/ desde cualquier subdirectorio
# get_k8s_scripts_dir "${SCRIPT_DIR}"
#   scripts/k8s/<svc>/<script>.sh → scripts/k8s/
#   scripts/k8s/<script>.sh       → scripts/k8s/
# ------------------------------------------------------------------
get_k8s_scripts_dir() {
  local script_dir="$1"
  local parent_dir
  parent_dir=$(dirname "${script_dir}")
  local parent_base
  parent_base=$(basename "${parent_dir}")

  # Si el script está en scripts/k8s/<componento>/ → parent es scripts/k8s/
  if [[ "${parent_base}" == "k8s" ]]; then
    echo "${parent_dir}"
  # Si el script está directamente en scripts/k8s/ → ese es el dir
  elif [[ "$(basename "${script_dir}")" == "k8s" ]]; then
    echo "${script_dir}"
  # Fallback: subir un nivel
  else
    echo "${parent_dir}"
  fi
}

# ------------------------------------------------------------------
# load_env_vars: Carga variables de entorno desde <directory>/<profile>.env
# Uso: load_env_vars <profile> <directory>
#   load_env_vars "${PROFILE}" "${SCRIPTS_K8S_DIR}"        → scripts/k8s/master.env
#   load_env_vars "${PROFILE}" "${SCRIPT_DIR}/env"         → scripts/k8s/<svc>/env/master.env
# ------------------------------------------------------------------
load_env_vars() {
  local profile="${1:-master}"
  local env_dir="${2:-$(get_script_dir)}"
  local env_file="${env_dir}/${profile}.env"

  if [[ -f "${env_file}" ]]; then
    set -a
    source "${env_file}"
    set +a
  fi
}

# Función para asignar variable con fallback completo
# Uso: VAR=$(set_with_fallback "VAR_NAME" "inline_default")
# Prioridad: 1) Variable con prefijo ENV_ (ENV_VAR_NAME), 2) Variable directamente definida, 3) Valor inline
set_with_fallback() {
  local var_name="$1"
  local inline_default="$2"
  
  # Primero buscar con prefijo ENV_
  local env_var="ENV_${var_name}"
  local env_value="${!env_var:-}"
  
  # Si no existe, buscar sin prefijo
  if [[ -z "$env_value" ]]; then
    env_value="${!var_name:-}"
  fi
  
  # Usar valor encontrado o el default inline
  echo "${env_value:-$inline_default}"
}