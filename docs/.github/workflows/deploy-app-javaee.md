# Pipeline: Deploy Banca Nacional

## Identificación

| Campo | Valor |
|-------|-------|
| **Archivo** | `.github/workflows/deploy-app-javaee.yml` |
| **Nombre** | `Deploy Banca Nacional` |
| **Propósito** | Compilar el EAR de Banca Nacional y desplegarlo en un WildFly remoto |
| **Trigger** | `workflow_dispatch` (manual) o push a `main` / `master` con cambios en `apps/backend-for-frontend/app-javaee/**` |

## Diagrama de flujo

![Diagrama de flujo del pipeline](mermaid-diagrams/deploy-app-javaee-flowchart.mmd)

> Diagrama: [`mermaid-diagrams/deploy-app-javaee-flowchart.mmd`](mermaid-diagrams/deploy-app-javaee-flowchart.mmd)

## Jobs

### `build-and-deploy`

| Propiedad | Valor |
|-----------|-------|
| **Runner** | `ubuntu-latest` |
| **Environment** | `${{ vars.DEPLOY_ENVIRONMENT || 'dev' }}` (GitHub Environment) |
| **Concurrencia** | Por rama, cancela ejecuciones previas en progreso |

### Steps

| # | Step | Acción | Detalle |
|---|------|--------|---------|
| 1 | Checkout | `actions/checkout@v4` | Clona el repositorio |
| 2 | Set up JDK 8 | `actions/setup-java@v4` | JDK 8 (Temurin), cachea dependencias Maven |
| 3 | Build EAR | `mvn clean package -DskipTests` | Compila el proyecto multi-módulo, genera `banca-ear/target/banca-nacional.ear` |
| 4 | Copy EAR | `appleboy/scp-action@v1.0.0` | Copia el `.ear` a `/tmp/` del servidor remoto |
| 5 | Deploy | `appleboy/ssh-action@v1.0.0` | Mueve el EAR a `deployments/`, elimina marcadores `.deployed`/`.failed` |
| 6 | Verify | `appleboy/ssh-action@v1.0.0` | Espera hasta 60s a que aparezca `.ear.deployed` |

## Variables y Secrets

### Configuración requerida en GitHub

Crear un **Environment** en `Settings > Environments > dev` (o el que indique `DEPLOY_ENVIRONMENT`).

#### Secrets (encriptados)

| Nombre | Descripción | Ejemplo |
|--------|-------------|---------|
| `DEPLOY_HOST` | IP o hostname del servidor WildFly | `192.168.1.100` |
| `DEPLOY_USER` | Usuario SSH | `wildfly-admin` |
| `DEPLOY_KEY` | Clave privada SSH (formato PEM) | `-----BEGIN OPENSSH PRIVATE KEY-----...` |

#### Variables (texto plano)

| Nombre | Default | Descripción |
|--------|---------|-------------|
| `DEPLOY_PORT` | `22` | Puerto SSH |
| `WILDFLY_DEPLOY_PATH` | `/opt/wildfly/standalone/deployments` | Ruta remota donde WildFly escanea despliegues |
| `DEPLOY_ENVIRONMENT` | `dev` | Nombre del Environment de GitHub a usar |

## Mecanismo de despliegue

WildFly monitoriza el directorio `deployments/` y reacciona a cambios en los artefactos:

| Archivo | Significado |
|---------|-------------|
| `banca-nacional.ear` | Artefacto de despliegue |
| `banca-nacional.ear.deployed` | Despliegue exitoso |
| `banca-nacional.ear.failed` | Despliegue fallido |
| `banca-nacional.ear.isdeploying` | Desplegando actualmente |

El pipeline:
1. Elimina los marcadores `.deployed` y `.failed` previos
2. Sobrescribe el `.ear` con la nueva versión
3. WildFly detecta el cambio y despliega automáticamente

## Perfiles (Environments)

El pipeline soporta múltiples perfiles vía GitHub Environments:

| Perfil | Environment | Uso |
|--------|-------------|-----|
| dev | `dev` | Desarrollo / pruebas |
| prod | `prod` | Producción |

Cada Environment tiene sus propios secrets y variables, permitiendo distintos servidores destino sin modificar el workflow.

## Uso

### Activación automática (push)

1. Configurar el Environment en GitHub con los secrets y variables necesarios
2. Hacer push a `main` o `master` con cambios en `apps/backend-for-frontend/app-javaee/`
3. El pipeline compila, copia y despliega automáticamente
4. La verificación espera hasta 60s por el marcador `.deployed`

### Ejecución manual (workflow_dispatch)

El pipeline se puede lanzar manualmente desde la interfaz de GitHub Actions:

1. Ir a `Actions > Deploy Banca Nacional > Run workflow`
2. Configurar los parámetros:

   | Parámetro | Tipo | Requerido | Default | Descripción |
   |-----------|------|-----------|---------|-------------|
   | `environment` | `choice` | Sí | `dev` | Entorno destino. Selecciona automáticamente el Environment de GitHub correspondiente (cada uno con sus propios secrets/variables) |
   | `skip_verify` | `boolean` | No | `false` | Si se activa, salta el paso de verificación (útil para despliegues rápidos o cuando se sabe que el EAR es correcto) |

3. Hacer clic en **Run workflow**

Esto ejecuta el mismo pipeline que un push, pero con la flexibilidad de elegir el entorno y opciones adicionales.

#### Casos de uso típicos

- **Rollback a una versión anterior**: Hacer checkout de un commit anterior localmente, compilar el EAR manualmente y lanzar el workflow con `environment: prod`.
- **Despliegue rápido sin verificación**: Usar `skip_verify: true` cuando se necesita desplegar urgentemente y se confía en el artefacto.
- **Pruebas en dev**: Lanzar el workflow con `environment: dev` para validar un cambio sin necesidad de hacer push.

## Posibles fallos

| Síntoma | Causa | Solución |
|---------|-------|----------|
| `SSH authentication failed` | `DEPLOY_KEY` incorrecta o `DEPLOY_HOST` erróneo | Verificar secrets en GitHub Environment |
| `Deployment failed` | Error en la aplicación (ej: `Invalid salt revision`) | Revisar `server.log` del WildFly remoto |
| `Timeout` | WildFly no disponible o deploy lento | Aumentar timeout o verificar conectividad |
| `No such file: .../banca-nacional.ear` | Cambió la estructura del proyecto | Verificar `source` en `scp-action` y `strip_components` |
