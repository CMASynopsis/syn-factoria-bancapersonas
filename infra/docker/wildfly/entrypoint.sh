#!/bin/bash
# =============================================================================
# Entrypoint para Wildfly + SSH
# =============================================================================
# Inicia el servicio SSH como root, inyecta claves publicas, luego arranca
# Wildfly como usuario jboss (sin exec para mantener sshd como hijo).
#
# Se inyecta la clave publica SSH via variable de entorno:
#   WILDFLY_SSH_PUBLIC_KEY  - Clave publica para el usuario deploy
#   DEPLOY_USER             - Usuario destino (default: deploy)
# =============================================================================
set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
WILDFLY_HOME="${WILDFLY_HOME:-/opt/jboss/wildfly}"
WILDFLY_RUN_USER="${WILDFLY_RUN_USER:-jboss}"
DEPLOY_USER_HOME="/home/${DEPLOY_USER}"

# ---------------------------------------------------------------------------
# 1. Inyectar clave publica SSH (si se proporciona via variable de entorno)
# ---------------------------------------------------------------------------
if [[ -n "${WILDFLY_SSH_PUBLIC_KEY:-}" ]]; then
  echo "[ENTRYPOINT] Inyectando clave publica SSH para usuario '${DEPLOY_USER}'..."
  mkdir -p "${DEPLOY_USER_HOME}/.ssh"
  echo "${WILDFLY_SSH_PUBLIC_KEY}" >> "${DEPLOY_USER_HOME}/.ssh/authorized_keys"
  chmod 600 "${DEPLOY_USER_HOME}/.ssh/authorized_keys"
  chmod 700 "${DEPLOY_USER_HOME}/.ssh"
  chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${DEPLOY_USER_HOME}/.ssh"
  echo "[ENTRYPOINT] Clave publica SSH inyectada correctamente."
fi

# ---------------------------------------------------------------------------
# 2. Iniciar SSH daemon
# ---------------------------------------------------------------------------
echo "[ENTRYPOINT] Iniciando servicio SSH en puerto 22..."
/usr/sbin/sshd -D -p 22 &
SSHD_PID=$!
echo "[ENTRYPOINT] SSH daemon iniciado (PID: ${SSHD_PID})"

# ---------------------------------------------------------------------------
# 3. Esperar brevemente a que SSH este listo
# ---------------------------------------------------------------------------
sleep 1
if kill -0 "${SSHD_PID}" 2>/dev/null; then
  echo "[ENTRYPOINT] SSH daemon corriendo correctamente."
else
  echo "[ENTRYPOINT] ADVERTENCIA: SSH daemon no esta corriendo."
fi

# ---------------------------------------------------------------------------
# 4. Arrancar Wildfly como usuario jboss
# ---------------------------------------------------------------------------
echo "[ENTRYPOINT] Iniciando Wildfly como usuario '${WILDFLY_RUN_USER}' con argumentos: $*"
echo "[ENTRYPOINT] Deployments directory: ${WILDFLY_HOME}/standalone/deployments"

# Cambiar al usuario jboss y arrancar Wildfly (sin exec para mantener sshd)
su -s /bin/bash "${WILDFLY_RUN_USER}" -c "${WILDFLY_HOME}/bin/standalone.sh $*" &

WILDFLY_PID=$!
echo "[ENTRYPOINT] Wildfly iniciado (PID: ${WILDFLY_PID})"

# ---------------------------------------------------------------------------
# 5. Trap SIGTERM/SIGINT para apagado graceful
# ---------------------------------------------------------------------------
_shutdown() {
  echo "[ENTRYPOINT] Recibida senal de parada. Deteniendo servicios..."
  kill "${WILDFLY_PID}" 2>/dev/null || true
  kill "${SSHD_PID}" 2>/dev/null || true
  wait
  exit 0
}
trap _shutdown SIGTERM SIGINT

# ---------------------------------------------------------------------------
# 6. Mantener el entrypoint vivo y reenviar senales
# ---------------------------------------------------------------------------
wait
