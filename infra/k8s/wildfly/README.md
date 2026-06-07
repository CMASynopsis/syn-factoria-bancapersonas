# Wildfly + SSH — Manifiestos Kubernetes

## Descripción

Manifiestos Kubernetes para desplegar **Wildfly 26.1.2.Final** con servidor **SSH integrado**,
permitiendo despliegue automatizado de artefactos Java EE (`.ear`/`.war`) via pipelines CI/CD.

La imagen `wildfly-ssh:26.1.2.Final` se construye desde `infra/docker/wildfly/Dockerfile`.

## Puertos

| Puerto | Nombre  | Descripción                              |
|--------|---------|------------------------------------------|
| 22     | SSH     | Conexión SSH / SCP para despliegues      |
| 8080   | HTTP    | Aplicaciones Java EE / APIs REST         |
| 9990   | Admin   | Wildfly Management Console               |

## Estructura de archivos

```
infra/k8s/wildfly/
├── namespace.yaml          # Namespace: wildfly
├── configmap.yaml          # ConfigMaps por perfil (dev, staging, prod)
├── secrets.yaml            # Secrets template (base64)
├── pvc.yaml                # PersistentVolumeClaim para deployments
├── deployment.yaml         # Deployment con probes, resources, volumes
├── service.yaml            # Service ClusterIP (o NodePort)
├── kustomization.yaml      # Kustomize base
└── README.md               # Este archivo
```

## Requisitos

- Kubernetes 1.24+
- Storage Class configurado (para PVC)
- Imagen `wildfly-ssh:26.1.2.Final` disponible en el cluster
  - Construir localmente: `./scripts/docker/wildfly/wildfly.sh build`
  - O desde registry: `docker pull <registry>/wildfly-ssh:26.1.2.Final`

## Variables de entorno

| Variable                    | Default                   | Descripción                              |
|-----------------------------|---------------------------|------------------------------------------|
| `WILDFLY_XMS`               | `512m`                    | Memoria heap inicial (Xms)               |
| `WILDFLY_XMX`               | `1024m`                   | Memoria heap máxima (Xmx)                |
| `WILDFLY_JAVA_OPTS`         | `""`                      | Opciones JVM adicionales                 |
| `DEPLOY_USER`               | `deploy`                  | Usuario SSH para despliegues             |
| `DEPLOY_PASSWORD`           | `deploy`                  | Password del usuario deploy              |
| `WILDFLY_SSH_PUBLIC_KEY`    | `""`                      | Clave pública SSH (opcional)             |
| `HEALTH_CHECK_URL`          | `http://localhost:8080/`  | URL para health checks                   |
| `WILDFLY_DEPLOY_PATH`       | `/opt/jboss/wildfly/standalone/deployments` | Ruta de deployments |

## Perfiles

Tres perfiles predefinidos en `configmap.yaml`:

| Perfil   | Xms   | Xmx   | CPU request | CPU limit | Memory request | Memory limit | Replicas |
|----------|-------|-------|-------------|-----------|----------------|--------------|----------|
| dev      | 512m  | 1024m | 500m        | 1         | 512Mi          | 1Gi          | 1        |
| staging  | 1024m | 2048m | 1           | 2         | 1Gi            | 2Gi          | 2        |
| prod     | 2048m | 4096m | 2           | 4         | 2Gi            | 4Gi          | 3+       |

Para cambiar de perfil, edita `deployment.yaml`:
1. Cambia `configMapRef.name` a `wildfly-config-<perfil>`
2. Ajusta `resources.requests` y `resources.limits`
3. Ajusta `replicas`

## Uso rápido

### 1. Crear secrets (desarrollo local)

```bash
# Codificar valores en base64
echo -n "deploy" | base64                                    # ZGVwbG95
echo -n "MiPasswordSegura" | base64                          # TWlQYXNzd29yZFNlZ3VyYQ==

# Editar secrets.yaml con los valores codificados
# Luego aplicar:
kubectl apply -f infra/k8s/wildfly/secrets.yaml
```

### 2. Desplegar todo

```bash
# Opcion A: Aplicar recursos individualmente
kubectl apply -f infra/k8s/wildfly/namespace.yaml
kubectl apply -f infra/k8s/wildfly/configmap.yaml
kubectl apply -f infra/k8s/wildfly/secrets.yaml
kubectl apply -f infra/k8s/wildfly/pvc.yaml
kubectl apply -f infra/k8s/wildfly/service.yaml
kubectl apply -f infra/k8s/wildfly/deployment.yaml

# Opcion B: Usar Kustomize (recomendado)
kubectl apply -k infra/k8s/wildfly/
```

### 3. Verificar el despliegue

```bash
kubectl get pods -n wildfly -w
kubectl get svc -n wildfly
kubectl get pvc -n wildfly

# Ver logs
kubectl logs -n wildfly -l app=geniahr-wildfly

# Port forwarding para probar localmente
kubectl port-forward -n wildfly svc/wildfly 8080:8080 9990:9990
```

### 4. Probar health checks

```bash
# Readiness/Liveness probe
kubectl describe pod -n wildfly -l app=geniahr-wildfly
```

## Kustomize Overlays

Para un manejo más ordenado por entornos, crea overlays:

```bash
# Crear estructura de overlays
mkdir -p infra/k8s/wildfly/overlays/{dev,staging,prod}

# Ejemplo overlay dev/ (infra/k8s/wildfly/overlays/dev/kustomization.yaml):
: '
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../

namespace: wildfly-dev

patchesStrategicMerge:
  - deployment-patch.yaml
'

# Aplicar overlay
kubectl apply -k infra/k8s/wildfly/overlays/dev/
```

## Despliegue de artefactos (.ear/.war)

### Opcion A: kubectl cp (recomendado para K8s)

```bash
# Copiar el artefacto al Pod
kubectl cp -n wildfly ./target/mi-app.ear wildfly-<pod-name>:/opt/jboss/wildfly/standalone/deployments/

# O mejor, copiar al PVC directamente si hay un Pod temporal:
kubectl run -n wildfly --rm -i --restart=Never temp-pod \
  --image=busybox --command -- sh -c "echo 'copiando...'"
```

### Opcion B: Copiar al PVC via un job temporal

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: deploy-copier
  namespace: wildfly
spec:
  containers:
  - name: copier
    image: alpine
    command: ["sleep", "3600"]
    volumeMounts:
    - name: deployments
      mountPath: /deployments
  volumes:
  - name: deployments
    persistentVolumeClaim:
      claimName: wildfly-deployments-pvc
EOF

# Copiar el artefacto
kubectl cp ./target/mi-app.ear wildfly/deploy-copier:/deployments/

# Limpiar
kubectl delete pod deploy-copier -n wildfly
```

### Opcion C: SSH (solo si el Service expone puerto 22)

```bash
scp -P 22 ./target/mi-app.ear deploy@<node-ip>:/opt/jboss/wildfly/standalone/deployments/
```

## Acceso a Wildfly Management Console

```bash
# Port forwarding
kubectl port-forward -n wildfly svc/wildfly 9990:9990

# Abrir en navegador: http://localhost:9990
# Credenciales: admin / admin (por defecto desde el Dockerfile)
```

## Resolución de problemas

### El Pod no arranca (CrashLoopBackOff)

```bash
# Ver logs
kubectl logs -n wildfly -l app=geniahr-wildfly --tail=100

# Ver eventos
kubectl get events -n wildfly --sort-by='.lastTimestamp'

# Ver descripción del Pod
kubectl describe pod -n wildfly -l app=geniahr-wildfly
```

### Readiness probe failing

```bash
# Verificar que Wildfly esta respondiendo
kubectl exec -n wildfly -ti deploy/wildfly -- curl -sf http://localhost:8080/

# Aumentar initialDelaySeconds si Wildfly tarda en arrancar
kubectl edit deployment -n wildfly wildfly
```

### PVC pendiente (Pending)

```bash
kubectl describe pvc -n wildfly wildfly-deployments-pvc

# Verificar Storage Classes disponibles
kubectl get storageclass

# Si no hay Storage Class por defecto, editar pvc.yaml y aniadir:
#   storageClassName: <nombre-storage-class>
```

## Mantenimiento

### Actualizar imagen

```bash
# 1. Construir nueva imagen
./scripts/docker/wildfly/wildfly.sh build

# 2. Pushear a registry (si aplica)
docker tag wildfly-ssh:26.1.2.Final <registry>/wildfly-ssh:<nueva-version>
docker push <registry>/wildfly-ssh:<nueva-version>

# 3. Actualizar deployment.yaml con el nuevo tag

# 4. Aplicar cambios
kubectl apply -f infra/k8s/wildfly/deployment.yaml

# 5. Verificar rolling update
kubectl rollout status deployment/wildfly -n wildfly
```

### Escalar

```bash
kubectl scale deployment/wildfly -n wildfly --replicas=3
```

### Verificar estado

```bash
kubectl get all -n wildfly
```

## Referencias

- [Wildfly Documentation](https://docs.wildfly.org/26/)
- [Kustomize](https://kustomize.io/)
- [Dockerfile Wildfly SSH](../docker/wildfly/Dockerfile)
- [Script de gestion Wildfly](../../scripts/docker/wildfly/wildfly.sh)
