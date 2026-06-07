# configure.sh

Despliegue y gestión de recursos Kubernetes para Wildfly+SSH.

## Ubicación

```
scripts/k8s/wildfly/configure.sh
```

## Uso

```bash
./scripts/k8s/wildfly/configure.sh <comando> [opciones]
```

## Comandos

| Comando | Descripción |
|---------|-------------|
| `apply` | Aplica los manifiestos YAML en orden: namespace → configmap → secrets → pvc → deployment → service |
| `validate` | Valida que todos los recursos estén creados y operativos (deployment, pods, service, configmap, secrets, pvc) |
| `destroy` | Elimina todos los recursos del namespace. Pide confirmación antes de proceder |
| `redeploy` | Destroy + apply en un solo paso (sin confirmación) |

## Opciones

| Opción | Descripción |
|--------|-------------|
| `-p, --profile <perfil>` | Perfil de configuración: `dev` (default), `staging`, `prod` |
| `-h, --help` | Muestra la ayuda |

## Variables de Entorno

Todas las variables se resuelven con la función `set_with_fallback` con esta prioridad:
1. `ENV_VAR_NAME` (prefijo `ENV_`)
2. `VAR_NAME` (variable directa)
3. Valor del archivo `{profile}.env`
4. Valor inline por defecto

### Kubernetes

| Variable | Default | Descripción |
|----------|---------|-------------|
| `K8S_NAMESPACE` | `wildfly` | Namespace de destino |
| `K8S_CONTEXT` | `(vacío)` | Contexto kubectl esperado. Si se define y no coincide, aborta |

### Wildfly

| Variable | Default | Descripción |
|----------|---------|-------------|
| `WILDFLY_IMAGE` | `wildfly-ssh:26.1.2.Final` | Imagen Docker |
| `WILDFLY_REPLICAS` | `1` | Réplicas del deployment |
| `WILDFLY_HTTP_PORT` | `8080` | Puerto HTTP |
| `WILDFLY_ADMIN_PORT` | `9990` | Puerto Admin |
| `WILDFLY_DEPLOY_USER` | `deploy` | Usuario SSH para despliegues |
| `WILDFLY_DEPLOY_PASSWORD` | `deploy` | Password del usuario |
| `WILDFLY_SSH_PUBLIC_KEY` | `(vacío)` | Clave pública SSH |
| `WILDFLY_XMS` | `512m` | Memoria XMS JVM |
| `WILDFLY_XMX` | `1024m` | Memoria XMX JVM |
| `WILDFLY_JAVA_OPTS` | `(vacío)` | Opciones JVM adicionales |

### Health Checks

| Variable | Default | Descripción |
|----------|---------|-------------|
| `HEALTH_CHECK_TIMEOUT` | `120` | Timeout en segundos |
| `HEALTH_CHECK_INTERVAL` | `5` | Intervalo en segundos |

### Storage / Service

| Variable | Default | Descripción |
|----------|---------|-------------|
| `STORAGE_SIZE` | `1Gi` | Tamaño del PVC |
| `SERVICE_TYPE` | `ClusterIP` | Tipo de servicio K8s |

## Flujo de apply

1. Verifica que kubectl esté instalado (`check_kubectl`)
2. Valida el contexto de Kubernetes (`require_k8s_context`)
3. Crea el namespace si no existe (`check_namespace`)
4. Aplica cada manifiesto en orden usando `envsubst` para reemplazar `${VARIABLE}` con los valores del perfil activo

## envsubst

Todos los YAMLs se procesan con `envsubst` antes de aplicar. Las variables exportadas son las listadas arriba más `PROFILE`. Los archivos YAML en `infra/k8s/wildfly/` usan `${VAR}` para los valores parametrizables.

## Ejemplos

```bash
# Perfil dev (default)
./scripts/k8s/wildfly/configure.sh apply

# Perfil staging
./scripts/k8s/wildfly/configure.sh apply -p staging

# Validar recursos
./scripts/k8s/wildfly/configure.sh validate

# Destruir todo
./scripts/k8s/wildfly/configure.sh destroy

# Redeploy
./scripts/k8s/wildfly/configure.sh redeploy

# Namespace personalizado vía env var
K8S_NAMESPACE=mi-namespace ./scripts/k8s/wildfly/configure.sh apply
```
