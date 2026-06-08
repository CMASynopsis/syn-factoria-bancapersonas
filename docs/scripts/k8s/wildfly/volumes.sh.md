# volumes.sh

Pre-crea y gestiona los directorios de volúmenes en el nodo Kubernetes para Wildfly.

## Ubicación

```
scripts/k8s/wildfly/volumes.sh
```

## Uso

```bash
./scripts/k8s/wildfly/volumes.sh <comando> [opciones]
```

## Comandos

| Comando | Descripción |
|---------|-------------|
| `create` | Crea los directorios de volúmenes en el nodo y asigna ownership a UID 1000 (jboss) |
| `check` | Verifica que los directorios existan y tengan permisos correctos |
| `delete` | Elimina los directorios de volúmenes (pide confirmación) |

## Opciones

| Opción | Descripción |
|--------|-------------|
| `-p, --profile <perfil>` | Perfil de configuración: `dev` (default), `staging`, `prod` |
| `-n, --node <host>` | Host o IP del nodo Kubernetes (requerido si `SSH_HOST` no está definido) |
| `-u, --user <user>` | Usuario SSH (default: `$USER` o `root`) |
| `-k, --key <path>` | Ruta a la clave privada SSH |
| `-h, --help` | Muestra la ayuda |

## Variables de Entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `SSH_HOST` | `(vacío)` | Host o IP del nodo Kubernetes (requerido) |
| `SSH_USER` | `$USER` o `root` | Usuario SSH |
| `SSH_KEY_PATH` | `(vacío)` | Ruta a la clave privada SSH |
| `VOLUME_BASE_DIR` | `/mnt/data/wildfly` | Directorio base para los volúmenes |
| `WILDFLY_DEPLOY_USER` | `deploy` | Usuario de despliegue Wildfly |
| `STORAGE_SIZE` | `1Gi` | Tamaño del volumen |

## Configuración de Clave SSH

Usa `ssh-config.sh` para generar, copiar y probar la clave SSH antes de ejecutar
`volumes.sh`:

```bash
# 1. Generar clave (si no existe)
./scripts/k8s/wildfly/ssh-config.sh create

# 2. Copiar clave pública al nodo
./scripts/k8s/wildfly/ssh-config.sh copy -n nodo1 -u admin

# 3. Probar conexión
./scripts/k8s/wildfly/ssh-config.sh test -n nodo1

# 4. Preparar volúmenes
./scripts/k8s/wildfly/volumes.sh create -n nodo1 -u admin
```

> **Nota sobre passphrase:** si generaste la clave con `-P` (protegida por passphrase),
> debes cargarla en `ssh-agent` antes de ejecutar `volumes.sh`:
> ```bash
> ssh-add ~/.ssh/id_rsa_wildfly    # pide la passphrase una vez
> ./scripts/k8s/wildfly/volumes.sh create -n nodo1 -u admin
> ```

## Configuración sudoers (requisito)

`volumes.sh` ejecuta `mkdir`, `chown`, `chmod`, `rm` y `stat` con `sudo` en el nodo
remoto. Para que funcione sin TTY (necesario en automatización), hay que agregar
una regla NOPASSWD en el nodo remoto.

Conéctate al nodo (o usa `ssh-config.sh connect`) y ejecuta:

```bash
echo "elperez ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/chown, /bin/chmod, /bin/rm, /bin/test, /usr/bin/stat, /bin/df" | sudo tee /etc/sudoers.d/wildfly-volumes
```

Reemplaza `elperez` por el usuario SSH correspondiente (`$SSH_USER`).

Esto permite que los comandos usados por `remote_exec()` en `volumes.sh` corran sin
pedir contraseña:

| Comando | Uso en volumes.sh |
|---------|-------------------|
| `/bin/mkdir` | Crear directorio base y deployments |
| `/bin/chown` | Asignar ownership a UID 1000 (jboss) |
| `/bin/chmod` | Asignar permisos 775 |
| `/bin/rm` | Eliminar volúmenes (delete) |
| `/bin/test` | Verificar existencia de directorios |
| `/usr/bin/stat` | Verificar permisos y ownership |
| `/bin/df` | Mostrar espacio en disco |

También puedes pasar la clave directamente con `-k` o `SSH_KEY_PATH`:

```bash
./scripts/k8s/wildfly/volumes.sh create -n 10.0.0.1 -u admin -k ~/.ssh/id_rsa
SSH_KEY_PATH=~/.ssh/id_rsa ./scripts/k8s/wildfly/volumes.sh create -n nodo1
```

O usar `~/.ssh/config` para acceso persistente:

```
# ~/.ssh/config
Host nodo1
  HostName 10.0.0.1
  User admin
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

## Funciones

| Función | Descripción |
|---------|-------------|
| `remote_exec <host> <command>` | Ejecuta un comando remoto vía SSH con opciones seguras |
| `get_deployments_dir` | Retorna la ruta del directorio de deployments |
| `create_volumes <host>` | Crea directorios, asigna ownership (UID 1000) y permisos (775) |
| `check_volumes <host>` | Verifica existencia, permisos y espacio en disco |
| `delete_volumes <host>` | Elimina el directorio base de volúmenes |

## Flujo de create

1. Conecta vía SSH al nodo con las credenciales proporcionadas
2. Crea el directorio `{VOLUME_BASE_DIR}/deployments`
3. Asigna ownership recursivo a `1000:1000` (UID del usuario jboss en el contenedor)
4. Asigna permisos `775` (rwx para owner y grupo, rx para otros)
5. Verifica que el directorio se haya creado correctamente

## Propósito

El PVC `wildfly-deployments-pvc` monta el directorio de deployments de Wildfly
(`/opt/jboss/wildfly/standalone/deployments`) para que los artefactos `.ear`/`.war`
persistan entre reinicios del Pod y puedan ser copiados vía SCP/SSH por pipelines CI/CD.

Este script prepara el directorio en el nodo **antes** de aplicar los manifiestos,
asegurando que:
- El directorio exista antes de que el PVC lo reclame
- Los permisos permitan al usuario jboss (UID 1000) escribir en él
- El espacio en disco sea suficiente

## Ejemplos

```bash
# Crear volúmenes en nodo1 con usuario actual
./scripts/k8s/wildfly/volumes.sh create -n nodo1

# Especificar usuario y clave SSH
./scripts/k8s/wildfly/volumes.sh create -n 10.0.0.1 -u admin -k ~/.ssh/id_rsa

# Verificar estado de los volúmenes
./scripts/k8s/wildfly/volumes.sh check -n nodo1

# Con perfil staging
./scripts/k8s/wildfly/volumes.sh create -p staging -n nodo2

# Usando variables de entorno
SSH_HOST=nodo1 SSH_USER=admin ./scripts/k8s/wildfly/volumes.sh create

# Directorio base personalizado
VOLUME_BASE_DIR=/data/wildfly ./scripts/k8s/wildfly/volumes.sh create -n nodo1

# Eliminar volúmenes (pide confirmación)
./scripts/k8s/wildfly/volumes.sh delete -n nodo1
```

## Orden recomendado

```bash
# 1. Preparar volúmenes en el nodo
./scripts/k8s/wildfly/volumes.sh create -n nodo1

# 2. Desplegar Wildfly
./scripts/k8s/wildfly/configure.sh apply

# 3. Verificar estado
./scripts/k8s/wildfly/run.sh status
```
