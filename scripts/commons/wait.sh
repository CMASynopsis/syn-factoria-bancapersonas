#!/bin/bash
# Description: Common wait functions for Kubernetes deployments
# Author: CMA Consulting
# Version: 1.0

# Function: wait_for_running_pod
# Description: Wait for a pod to reach Running state with timeout
# Parameters: NAME, NAMESPACE (global variables)
# Returns: 0 on success, 1 on timeout, 2 on error state
function wait_for_running_pod() {
    local timeout=300
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    log "INFO" "Waiting for pod ${NAME} to be in Running state..."
    while [[ $(date +%s) -lt ${end_time} ]]; do
        POD_NAME=$(kubectl get pod -n "${NAMESPACE}" | grep "${NAME}.*Running" | awk '{print $1}')
        if [[ -n "${POD_NAME}" ]]; then
            log "SUCCESS" "Pod ${POD_NAME} is in Running state"
            return 0
        fi
        log "INFO" "Waiting... ($(( end_time - $(date +%s) )) seconds remaining)"
        sleep 10
    done
    
    handle_error "Timeout waiting for pod to reach Running state"
}

# Function: wait_for_status_change
# Description: Wait for status to change from current to target with timeout
# Parameters: TIMEOUT, MAX_ATTEMPTS, SLEEP_TIME, CURRENT_STATUS, TARGET_STATUS (global variables)
# Returns: 0 on success, 1 on timeout
function wait_for_status_change() {
    local timeout=${TIMEOUT:-300}
    local max_attempts=${MAX_ATTEMPTS:-30}
    local sleep_time=${SLEEP_TIME:-10}
    local current_status=${CURRENT_STATUS:-"NONE"}
    local target_status=${TARGET_STATUS:-"OK"}
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    local attempt=1
    
    log "INFO" "Waiting for status to change from ${current_status} to ${target_status}..."
    
    while [[ $attempt -le $max_attempts ]] && [[ $(date +%s) -lt ${end_time} ]]; do
        if [[ "${current_status}" != "${target_status}" ]] && [[ "${current_status}" != "NONE" ]]; then
            log "SUCCESS" "Status changed to: ${current_status}"
            return 0
        fi
        
        log "INFO" "Intento $attempt/$max_attempts: Esperando... (${sleep_time} segundos)"
        sleep $sleep_time
        ((attempt++))
    done
    
    handle_error "Timeout waiting for status change. Current status: ${current_status}"
}

# Function: wait_seconds
# Description: Simple wait function with logging
# Parameters: SECONDS, MESSAGE (optional)
function wait_seconds() {
    local seconds=$1
    local message="${2:-Esperando ${seconds} segundos...}"
    
    log "INFO" "${message}"
    sleep $seconds
}