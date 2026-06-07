# profile.env

Archivos de configuración por perfil para los scripts Wildfly K8s.

## Ubicación

```
scripts/k8s/wildfly/
├── profile.env.example   # Template con todas las variables comentadas
├── dev.env               # Perfil de desarrollo (default)
├── staging.env           # Perfil de staging (crear desde example)
└── prod.env              # Perfil de producción (crear desde example)
```

## Uso

```bash
# Crear un perfil desde el template
cp scripts/k8s/wildfly/profile.env.example scripts/k8s/wildfly/staging.env

# Editar valores
vim scripts/k8s/wildfly/staging.env

# Usar el perfil
./scripts/k8s/wildfly/configure.sh apply -p staging
```

## Variables

### Kubernetes

| Variable | dev | staging | prod |
|----------|-----|---------|------|
| `K8S_NAMESPACE` | `wildfly` | — | — |
| `K8S_CONTEXT` | `(vacío)` | — | — |

### Imagen y Réplicas

| Variable | dev | staging | prod |
|----------|-----|---------|------|
| `WILDFLY_IMAGE` | `wildfly-ssh:26.1.2.Final` | — | — |
| `WILDFLY_REPLICAS` | `1` | — | — |

### Puertos

| Variable | dev | staging | prod |
|----------|-----|---------|------|
| `WILDFLY_HTTP_PORT` | `8080` | — | — |
| `WILDFLY_ADMIN_PORT` | `9990` | — | — |
| `LOCAL_SSH_PORT` | `2222` | — | — |

### Usuario SSH

| Variable | dev |
|----------|-----|
| `WILDFLY_DEPLOY_USER` | `deploy` |
| `WILDFLY_DEPLOY_PASSWORD` | `deploy` |
| `WILDFLY_SSH_PUBLIC_KEY` | `(vacío)` |

### JVM

| Variable | dev |
|----------|-----|
| `WILDFLY_XMS` | `512m` |
| `WILDFLY_XMX` | `1024m` |
| `WILDFLY_JAVA_OPTS` | `(vacío)` |

### Health Checks

| Variable | dev |
|----------|-----|
| `HEALTH_CHECK_TIMEOUT` | `120` |
| `HEALTH_CHECK_INTERVAL` | `5` |

### Storage / Service

| Variable | dev |
|----------|-----|
| `STORAGE_SIZE` | `1Gi` |
| `SERVICE_TYPE` | `ClusterIP` |

## Prioridad de Variables

Las variables siguen esta prioridad (de mayor a menor):

1. `ENV_VAR_NAME` — Variable con prefijo `ENV_` (ej: `ENV_K8S_NAMESPACE`)
2. `VAR_NAME` — Variable de entorno directa (ej: `K8S_NAMESPACE`)
3. `{profile}.env` — Valor del archivo de perfil
4. **Valor inline** — Default hardcodeado en el script

Esto permite sobrescribir cualquier valor sin modificar archivos:

```bash
# Sobrescribir namespace sin tocar dev.env
K8S_NAMESPACE=mi-ns ./scripts/k8s/wildfly/configure.sh apply
```
