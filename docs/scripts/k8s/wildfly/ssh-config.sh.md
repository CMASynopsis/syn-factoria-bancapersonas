# ssh-config.sh

Generación y distribución de claves SSH para conexión desde el cliente kubectl al nodo Kubernetes.

## Ubicación

```
scripts/k8s/wildfly/ssh-config.sh
```

## Uso

```bash
./scripts/k8s/wildfly/ssh-config.sh <comando> [opciones]
```

## Comandos

| Comando | Descripción |
|---------|-------------|
| `create` | Genera un par de claves SSH si no existe |
| `copy` | Copia la clave pública al servidor remoto vía `ssh-copy-id` |
| `test` | Prueba la conexión SSH al servidor |
| `connect` | Abre una sesión SSH interactiva al servidor remoto (con TTY para sudo) |
| `info` | Muestra información del par de claves |

## Opciones

| Opción | Descripción |
|--------|-------------|
| `-p, --profile <perfil>` | Perfil de configuración: `dev` (default), `staging`, `prod` |
| `-n, --node <host>` | Host o IP del nodo Kubernetes |
| `-u, --user <user>` | Usuario SSH (default: `$USER` o `root`) |
| `-k, --key <path>` | Ruta a la clave privada SSH |
| `-P, --passphrase` | Solicitar passphrase para proteger la clave privada (por defecto se genera sin passphrase para CI/CD) |
| `-h, --help` | Muestra la ayuda |

## Variables de Entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `SSH_HOST` | `(vacío)` | Host o IP del nodo Kubernetes |
| `SSH_USER` | `$USER` o `root` | Usuario SSH |
| `SSH_KEY_PATH` | `~/.ssh/id_rsa_wildfly` | Ruta a la clave privada SSH |
| `SSH_KEY_TYPE` | `rsa` | Tipo de clave (rsa, ed25519) |
| `SSH_KEY_BITS` | `4096` | Bits de la clave (para rsa) |

## Flujo completo

```bash
# 1. Generar par de claves (solo una vez)
./scripts/k8s/wildfly/ssh-config.sh create

# 2. Copiar clave pública al nodo
./scripts/k8s/wildfly/ssh-config.sh copy -n nodo1 -u admin

# 3. Verificar conexión
./scripts/k8s/wildfly/ssh-config.sh test -n nodo1

# 4. Preparar volúmenes en el nodo
./scripts/k8s/wildfly/volumes.sh create -n nodo1 -u admin

# 5. Desplegar Wildfly
./scripts/k8s/wildfly/configure.sh apply
```

## Ejemplos

```bash
# Crear clave con ruta por defecto (~/.ssh/id_rsa_wildfly)
./scripts/k8s/wildfly/ssh-config.sh create

# Crear clave en ruta personalizada
./scripts/k8s/wildfly/ssh-config.sh create -k ~/.ssh/mi_clave

# Copiar clave al servidor
./scripts/k8s/wildfly/ssh-config.sh copy -n 10.0.0.1 -u admin

# Copiar con clave específica
./scripts/k8s/wildfly/ssh-config.sh copy -n nodo1 -u admin -k ~/.ssh/id_rsa_wildfly

# Probar conexión
./scripts/k8s/wildfly/ssh-config.sh test -n nodo1

# Conectar sesión SSH interactiva (con TTY para sudo)
./scripts/k8s/wildfly/ssh-config.sh connect -n nodo1

# Crear clave con passphrase (protegida)
./scripts/k8s/wildfly/ssh-config.sh create -P

# Ver información (detecta si tiene passphrase)
./scripts/k8s/wildfly/ssh-config.sh info

# Usando variables de entorno
SSH_HOST=nodo1 SSH_USER=admin ./scripts/k8s/wildfly/ssh-config.sh copy
```
