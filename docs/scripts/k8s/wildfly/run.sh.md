# run.sh

Operaciones sobre el pod Wildfly desplegado en Kubernetes.

## Ubicación

```
scripts/k8s/wildfly/run.sh
```

## Uso

```bash
./scripts/k8s/wildfly/run.sh <comando> [opciones]
```

## Comandos

| Comando | Descripción |
|---------|-------------|
| `status` | Muestra estado del deployment, pods, services, configmaps y PVCs |
| `logs` | Sigue los logs del pod en tiempo real (Ctrl+C para salir) |
| `ssh` | Conecta via SSH al pod mediante port-forward (puerto local `2222` → pod:22) |
| `restart` | Hace rollout restart del deployment y espera a que esté listo (timeout 300s) |
| `scale <N>` | Escala el deployment a N réplicas y espera a que esté listo |
| `exec <comando>` | Ejecuta un comando en el pod |

## Opciones

| Opción | Descripción |
|--------|-------------|
| `-p, --profile <perfil>` | Perfil de configuración: `dev` (default), `staging`, `prod` |
| `-h, --help` | Muestra la ayuda |

## Variables de Entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `K8S_NAMESPACE` | `wildfly` | Namespace donde está desplegado Wildfly |
| `K8S_CONTEXT` | `(vacío)` | Contexto kubectl esperado |
| `WILDFLY_DEPLOY_USER` | `deploy` | Usuario SSH para conexión |
| `WILDFLY_HTTP_PORT` | `8080` | Puerto HTTP |
| `WILDFLY_ADMIN_PORT` | `9990` | Puerto Admin |
| `WILDFLY_IMAGE` | `wildfly-ssh:26.1.2.Final` | Imagen Docker |
| `LOCAL_SSH_PORT` | `2222` | Puerto local para port-forward SSH |

## Funciones

| Función | Descripción |
|---------|-------------|
| `check_kubectl` | Verifica que kubectl esté instalado |
| `require_k8s_context` | Valida que el contexto K8s coincida con `K8S_CONTEXT` (si está definido) |
| `get_pod_name` | Obtiene el nombre del primer pod del deployment |
| `get_deploy_name` | Obtiene el nombre del deployment |
| `require_pod` | Verifica que exista al menos un pod; sale con error si no |
| `require_deployment` | Verifica que exista el deployment; sale con error si no |
| `show_status` | Muestra el estado completo de todos los recursos |
| `show_logs` | Muestra logs del pod en seguimiento |
| `ssh_into_pod` | Inicia port-forward y conecta SSH |
| `restart_deployment` | Rollout restart del deployment |
| `scale_deployment` | Escala el deployment a N réplicas |
| `exec_in_pod` | Ejecuta un comando en el pod |

## Ejemplos

```bash
# Estado del deployment
./scripts/k8s/wildfly/run.sh status

# Logs en tiempo real
./scripts/k8s/wildfly/run.sh logs

# SSH al pod
./scripts/k8s/wildfly/run.sh ssh

# Reiniciar deployment
./scripts/k8s/wildfly/run.sh restart

# Escalar a 3 réplicas
./scripts/k8s/wildfly/run.sh scale 3

# Ejecutar comando en el pod
./scripts/k8s/wildfly/run.sh exec -- ls -la /opt/jboss/wildfly/standalone/deployments

# Con perfil staging
./scripts/k8s/wildfly/run.sh status -p staging
```
