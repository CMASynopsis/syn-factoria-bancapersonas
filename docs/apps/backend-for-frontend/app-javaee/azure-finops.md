# Azure FinOps — Banca Nacional (app-javaee)

> **Análisis de costo mínimo para desplegar `app-javaee` (Java 8 + WildFly 10.1 + MySQL 5.7) en contenedores sobre Azure.**
>
> Stack: `Java 8` · `WildFly 10.1.0.Final` · `MySQL 5.7` · `EAR (EJB + WAR)`
> Empaquetado: `banca-nacional.ear` (context-root: `/banca`)

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Análisis de Alternativas](#2-análisis-de-alternativas)
3. [Opción Recomendada](#3-opción-recomendada)
4. [Arquitectura Propuesta](#4-arquitectura-propuesta)
5. [Desglose de Costos](#5-desglose-de-costos)
6. [Plan de Despliegue](#6-plan-de-despliegue)
7. [Checklist de Optimización FinOps](#7-checklist-de-optimización-finops)
8. [Migración desde MicroK8s on-prem](#8-migración-desde-microk8s-on-prem)

---

## 1. Resumen Ejecutivo

La aplicación `app-javaee` es un monolito Java EE 7 empaquetado como EAR que corre sobre WildFly 10.1 con MySQL 5.7. Actualmente se despliega sobre MicroK8s on-premise usando los scripts en `scripts/k8s/wildfly/`.

### Objetivo

Migrar a Azure con el **mínimo costo operativo** posible, aprovechando servicios serverless y de escala a cero para entornos dev/test, y manteniendo opción productiva de bajo costo.

### Restricciones técnicas

| Aspecto | Requisito |
|---|---|
| Runtime | WildFly 10.1 — requiere JDK 8 o 11 |
| Disco EAR | ~20-50 MB |
| Memoria WildFly | 512 MB (XMS) / 1024 MB (XMX) mínimo |
| Base de datos | MySQL 5.7 — utf8mb4 |
| Sesiones | Stateful (sesiones HTTP, EJB stateful) |
| Tipo de carga | Baja/Media — BFF corporativo interno |

---

## 2. Análisis de Alternativas

### 2.1 Tabla comparativa

| Opción | Costo/mes estimado | Scale-to-zero | Esfuerzo migración | Ideal para |
|---|---|---|---|---|
| **ACA Consumption** ⭐ | **~$0–15** ✅ | Sí ✅ | Medio | Dev/Test, Prod baja carga |
| ACI | ~$45–60 | No ❌ | Bajo | Tareas batch, dev simple |
| VM B1s (Spot) | ~$3–5 | N/A (preemptible) ❌ | Alto | Dev no crítico |
| VM B2s (PAYG) | ~$22–30 | No ❌ | Alto | Prod legacy |
| AKS | ~$75+ (control plane) | Sí | Muy alto | Microservicios (overkill) |
| App Service Linux (custom container) | ~$40–50 | Limitado | Medio | Prod si no hay otra opción |

### 2.2 Análisis detallado

#### ⭐ Azure Container Apps — Consumption Plan (RECOMENDADO)

| Concepto | Valor |
|---|---|
| **Modelo de cobro** | Pay-per-second: vCPU + memoria |
| **vCPU activo** | ~$0.000026/seg |
| **Memoria activa (GiB)** | ~$0.000012/seg |
| **vCPU idle** | ~$0.000007/seg |
| **Memoria idle (GiB)** | ~$0.000003/seg |
| **Free grant mensual** | 180,000 vCPU-seg + 360,000 GiB-seg + 2M requests |
| **Scale-to-zero** | Sí — sin costo cuando no hay tráfico |
| **Sesiones stateful** | Compatible con sticky sessions (session affinity) |
| **Máx recursos por replica** | 4 vCPU, 8 GB RAM (suficiente para WildFly) |

**Ventajas:**
- Único servicio Azure que escala **a cero** — ideal para entornos dev/test que se usan pocas horas al día
- No hay costo de control plane (vs AKS ~$75/mes fijo)
- Soporta contenedores personalizados (WildFly + MySQL module)
- Session affinity para mantener sesiones HTTP en WildFly
- Integración nativa con Azure Container Registry (ACR)
- HTTPS/TLS automático con dominio propio o generado

**Desventajas:**
- No soporta montar módulos JVM a nivel de cluster (el módulo MySQL va dentro de la imagen)
- Tiempo de arranque en frío ~15–30s (desde scale-to-zero)
- No recomendado para sesiones EJB stateful clusterizadas (solo 1 replica)

---

#### Azure Container Instances (ACI)

| Concepto | Valor |
|---|---|
| **Costo estimado (1 vCPU + 2 GB RAM)** | ~$50–60/mes 24/7 |
| **Modelo** | Pay-per-second, siempre activo |
| **Escalado** | Manual, sin auto-scale |
| **Ventaja** | Simplicidad — un solo comando para desplegar |
| **Desventaja** | No escala a cero, más caro que ACA para uso intermitente |

**Veredicto:** Adecuado para pruebas rápidas, pero más caro que ACA para el mismo uso.

---

#### Azure VM — Serie B (Burstable)

| SKU | vCPU | RAM | PAYG/mes | Spot/mes | 1yr reserved/mes |
|---|---|---|---|---|---|
| **B1s** | 1 | 1 GB | ~$8 | ~$3 | ~$5 |
| **B2s** | 2 | 4 GB | ~$22 | ~$8 | ~$14 |
| **B1ms** | 1 | 2 GB | ~$12 | ~$4 | ~$8 |

**Ventajas:**
- Control total del SO, WildFly, JDK
- Spot pricing hasta 90% descuento
- Opción más barata para 24/7

**Desventajas:**
- **No es container-based** — requiere gestionar manualmente WildFly, actualizaciones, parches
- Spot puede ser desalojado en cualquier momento (no apto para prod)
- B1s (1 GB RAM) es insuficiente para WildFly (XMX=1024 MB ya consume toda la RAM)
- B1ms (2 GB RAM) es el mínimo viable
- Mayor overhead operativo (parches SO, seguridad, monitoreo)

**Veredicto:** Solo para dev extremo con Spot B1ms. No recomendado para prod.

---

#### Azure Kubernetes Service (AKS)

| Concepto | Costo/mes |
|---|---|
| **Control plane (gratuito hasta cierto limite)** | ~$75/mes cluster standard |
| **Node pool mínimo (1x B2s)** | ~$22/mes |
| **Load Balancer** | ~$20/mes |
| **Total estimado** | **~$75–100/mes** |

**Ventajas:**
- Portabilidad desde MicroK8s actual
- Escalado automático
- Ecosistema K8s completo

**Desventajas:**
- **Overkill** para un solo monolito
- Costo fijo de control plane (~$75/mes) que no se elimina
- Mayor complejidad operativa
- Para un solo EAR, no se justifica

**Veredicto:** Solo si migran múltiples microservicios a futuro. Para un monolito, no es costo-efectivo.

---

#### Azure App Service — Linux Custom Container

| Plan | vCPU | RAM | Costo/mes |
|---|---|---|---|
| **B1** | 1 | 1.75 GB | ~$40–50 |
| **B2** | 2 | 3.5 GB | ~$70–80 |

**Ventajas:**
- Totalmente administrado
- Auto-scaling
- TLS/SSL integrado
- Slots de deployment

**Desventajas:**
- No escala a cero
- Más caro que ACA
- Limitaciones de contenedores personalizados (WildFly necesita configuraciones especiales)
- Sesiones stateful pueden tener problemas con múltiples instancias

**Veredicto:** Alternativa válida para producción si se necesita soporte administrado, pero el doble de costo que ACA.

---

### 2.3 Matriz de decisión

| Criterio (peso) | ACA Consump. | ACI | VM Spot | AKS |
|---|---|---|---|---|
| Costo mínimo (30%) | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐ |
| Esfuerzo migración (20%) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Operación mantenible (20%) | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| Escalado elástico (15%) | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| Productivo-ready (15%) | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐⭐⭐ |
| **Puntaje total** | **4.4 ⭐** | 2.6 | 2.1 | 3.2 |

---

## 3. Opción Recomendada

### Azure Container Apps — Consumption Plan

Es la opción que ofrece el **costo más bajo posible** para un contenedor WildFly en Azure, gracias a:

1. **Scale-to-zero nativo** — sin tráfico = sin costo
2. **Pay-per-second** granular
3. **Free grant mensual** que cubre un uso dev ligero completamente gratis
4. **Sin costo fijo de control plane** (vs AKS ~$75/mes)
5. **Sin costo de IP/Load Balancer** (vs AKS LB ~$20/mes)

### Para la base de datos

| Opción | Costo/mes | Ideal para |
|---|---|---|
| **Azure DB for MySQL Flexible Server (B1ms)** | ~$15–25 | Prod, dev con datos persistentes |
| **MySQL sidecar container** (en ACA) | ~$0 extra | Dev/test, datos efímeros |
| **Azure MySQL — Free tier** | ~$0 | No disponible actualmente |

**Para mínimo costo absoluto (dev/test):** MySQL como sidecar container dentro del mismo ACA.

**Para entornos con datos persistentes:** Azure DB for MySQL Flexible Server B1ms con backup reducido.

---

## 4. Arquitectura Propuesta

### 4.1 Diagrama de componentes

```
┌────────────────────────────────────────────────────────────────┐
│                     Azure Container Apps                       │
│                  (Consumption Plan — Managed Env)              │
│                                                                │
│  ┌──────────────────────┐      ┌──────────────────────────┐   │
│  │   Container App      │      │   Container App          │   │
│  │   banca-wildfly      │      │   banca-mysql (sidecar)  │   │
│  │                      │      │                          │   │
│  │  wildfly-ssh:10.1    │      │  mysql:5.7               │   │
│  │  puertos: 8080       │      │  puerto: 3306            │   │
│  │         9990 (admin) │      │                          │   │
│  │                      │      │  Volumen temporal:       │   │
│  │  ENV:                │      │  /var/lib/mysql          │   │
│  │   MYSQL_HOST=local   │◄─────┤  DB: banca_db            │   │
│  │   MYSQL_PORT=3306    │      │  User: banca_user        │   │
│  └──────────┬───────────┘      └──────────────────────────┘   │
│             │                                                 │
└─────────────┼─────────────────────────────────────────────────┘
              │
              │ HTTP/HTTPS (443)
              │
     ┌────────┴────────┐
     │  Azure Front    │
     │  Door / Ingress │  (opcional — TLS + dominio)
     └─────────────────┘
```

### 4.2 Componentes

| Componente | Servicio Azure | SKU/Tamaño | Costo |
|---|---|---|---|
| **WildFly container** | ACA Consumption | 1 vCPU, 2 GB RAM | ~$0–15/mes |
| **MySQL sidecar** | ACA Consumption (misma app multi-container) | 0.5 vCPU, 1 GB RAM | Incluido arriba |
| **Registro imágenes** | Azure Container Registry (ACR) | Basic (~$5/mes fijo) | ~$5/mes |
| **Base de datos persistente** (opcional) | Azure DB for MySQL Flexible Server | B1ms (1 vCore, 2 GB) | ~$15–25/mes |
| **Ingress/TLS** (opcional) | Azure Front Door | N/A (costo por request) | ~$0–5/mes |

### 4.3 Perfiles de despliegue

| Perfil | WildFly | Base de datos | Costo total/mes |
|---|---|---|---|
| **dev** ⭐ | ACA + scale-to-zero (8h/día) | MySQL sidecar (efímero) | **~$0–5** |
| **test** ⭐ | ACA + 1 replica mínima | Azure DB MySQL B1ms | **~$15–30** |
| **prod-low** | ACA + 2 réplicas mínimas | Azure DB MySQL B1ms + HA | **~$30–50** |
| **prod-full** | AKS + 2 réplicas | Azure DB MySQL B2s + HA | **~$100–130** |

---

## 5. Desglose de Costos

### 5.1 Escenario Dev — Costo CERO real (menos de $5)

**Asunción:** El entorno dev se usa ~8 horas al día, 22 días al mes, escala a cero el resto.

| Recurso | Configuración | Horas activo | Costo/mes |
|---|---|---|---|
| ACA — vCPU (1) | $0.000026/s × 8h × 3600s × 22d | 176 h | ~$4.12 |
| ACA — Memoria (2 GB) | $0.000012/s × 8h × 3600s × 22d | 176 h | ~$1.90 |
| ACA — Requests (bajas) | 10K/mes (dentro del free grant) | — | $0 |
| **Free grant (180K vCPU-s + 360K GiB-s)** | Aplica automáticamente | — | **~−$2.50** |
| ACR Basic | $5/mes fijo | — | $5.00 |
| MySQL sidecar | Incluido en costo ACA | — | $0 |
| **Total Dev** | | | **~$4–8/mes** |

> 💡 **Nota:** Los primeros meses pueden ser **$0 reales** si se usa el free grant de Azure ($200 crédito inicial) y el free grant mensual de ACA.

### 5.2 Escenario Test — $15–30/mes

**Asunción:** 1 replica siempre activa (sin scale-to-zero), base de datos persistente.

| Recurso | Configuración | Costo/mes |
|---|---|---|
| ACA — vCPU idle (1) | $0.000007/s × 24h × 3600s × 30d | ~$5.44 |
| ACA — Memoria idle (2 GB) | $0.000003/s × 24h × 3600s × 30d | ~$2.33 |
| ACA — vCPU active (~4h/día) | $0.000026/s × 4h × 3600s × 30d | ~$4.12 |
| ACA — Memoria active (~4h/día) | $0.000012/s × 4h × 3600s × 30d | ~$1.90 |
| ACR Basic | $5/mes | ~$5.00 |
| Azure DB for MySQL B1ms | 1 vCore, 2 GB RAM, 20 GB storage | ~$15.00 |
| **Total Test** | | **~$28–34/mes** |

### 5.3 Escenario Prod-Low — $30–50/mes

**Asunción:** 2 réplicas siempre activas, base de datos persistente con HA, backup.

| Recurso | Configuración | Costo/mes |
|---|---|---|
| ACA — vCPU idle (2 × 1) | $0.000007/s × 24h × 30d | ~$10.88 |
| ACA — Memoria idle (2 × 2 GB) | $0.000003/s × 24h × 30d | ~$4.66 |
| ACA — vCPU active (8h/día) | $0.000026/s × 8h × 30d | ~$8.23 |
| ACA — Memoria active (8h/día) | $0.000012/s × 8h × 30d | ~$3.80 |
| ACR Basic | $5/mes | ~$5.00 |
| Azure DB for MySQL B1ms + HA | 1 vCore, 2 GB RAM, backup configurable | ~$18.00 |
| **Total Prod-Low** | | **~$40–55/mes** |

### 5.4 Comparativa visual de costos

```
Costo mensual estimado por escenario:

Dev (ACA + sidecar)         ██░░░░░░░░░░░░░  ~$5
Test (ACA + MySQL DB)       █████████░░░░░░░  ~$30
Prod-Low (ACA 2 replicas)   ██████████████░░  ~$50
VM B1s (PAYG, self-managed) ██████████░░░░░░  ~$35 (+operación)
AKS (1 node B2s)            █████████████████  ~$95
App Service B1 (container)  ██████████████░░  ~$50

Cada █ = ~$7/mes
```

---

## 6. Plan de Despliegue

### 6.1 Prerrequisitos

```bash
# Azure CLI
az login
az account set --subscription "<subscription-id>"

# Recursos base
az group create --name rg-banca-dev --location eastus
az acr create --name bancaacr --resource-group rg-banca-dev --sku Basic --admin-enabled true
```

### 6.2 Dockerfile para Azure (WildFly 10.1 + MySQL 5.7)

Crear `infra/docker/wildfly-azure/Dockerfile`:

```dockerfile
# =============================================================================
# WildFly 10.1 + MySQL 5.7 module — Optimizado para ACA
# =============================================================================
FROM jboss/wildfly:10.1.0.Final

ARG MYSQL_CONNECTOR_VERSION=5.1.49

USER root

# 1. Instalar MySQL module en WildFly
RUN mkdir -p /opt/jboss/wildfly/modules/com/mysql/main
COPY scripts/module.xml /opt/jboss/wildfly/modules/com/mysql/main/
ADD https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar \
    /opt/jboss/wildfly/modules/com/mysql/main/

# 2. Crear usuario admin y deploy (para management)
RUN /opt/jboss/wildfly/bin/add-user.sh admin admin --silent && \
    /opt/jboss/wildfly/bin/add-user.sh deploy deploy --silent

# 3. Configurar datasource MySQL via CLI
RUN /opt/jboss/wildfly/bin/jboss-cli.sh --commands="embed-server --std-out=echo,\
    '/subsystem=datasources/jdbc-driver=mysql:add(driver-name=mysql,driver-module-name=com.mysql,driver-xa-datasource-class-name=com.mysql.jdbc.jdbc2.optional.MysqlXADataSource)',\
    'data-source add --name=BancaDS --jndi-name=java:jboss/datasources/BancaDS \
      --driver-name=mysql --connection-url=jdbc:mysql://\${env.MYSQL_HOST:localhost}:\${env.MYSQL_PORT:3306}/\${env.MYSQL_DB:banca_db} \
      --user-name=\${env.MYSQL_USER:banca_user} --password=\${env.MYSQL_PASSWORD:banca_pass123} \
      --min-pool-size=5 --max-pool-size=20 --validate-on-match=true --background-validation=false',\
    '/subsystem=undertow/server=default-server/http-listener=default:write-attribute(name=proxy-address-forwarding,value=true)'" && \
    rm -rf /opt/jboss/wildfly/standalone/configuration/standalone_xml_history

# 4. Desplegar EAR
COPY apps/backend-for-frontend/app-javaee/banca-ear/target/banca-nacional.ear \
    /opt/jboss/wildfly/standalone/deployments/

USER jboss

EXPOSE 8080 9990

CMD ["-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
```

### 6.3 Build y push a ACR

```bash
# Build de la aplicación (EAR)
cd apps/backend-for-frontend/app-javaee
mvn clean package -DskipTests

# Build de la imagen WildFly + EAR
docker build -t bancaacr.azurecr.io/banca-wildfly:1.0.0 \
  -f infra/docker/wildfly-azure/Dockerfile .

# Push a ACR
az acr login --name bancaacr
docker push bancaacr.azurecr.io/banca-wildfly:1.0.0
```

### 6.4 Despliegue en ACA (Consumption Plan)

```bash
# Variables
ACR_NAME="bancaacr"
IMAGE_NAME="banca-wildfly"
IMAGE_TAG="1.0.0"
ACA_ENV="aca-banca-dev"
ACA_APP="banca-wildfly-app"
RG="rg-banca-dev"
LOCATION="eastus"

# Crear entorno ACA
az containerapp env create \
  --name $ACA_ENV \
  --resource-group $RG \
  --location $LOCATION

# Desplegar WildFly Container App
az containerapp create \
  --name $ACA_APP \
  --resource-group $RG \
  --environment $ACA_ENV \
  --image "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" \
  --registry-server "${ACR_NAME}.azurecr.io" \
  --target-port 8080 \
  --ingress external \
  --cpu 1 \
  --memory 2Gi \
  --env-vars \
    MYSQL_HOST=localhost \
    MYSQL_PORT=3306 \
    MYSQL_DB=banca_db \
    MYSQL_USER=banca_user \
    MYSQL_PASSWORD=banca_pass123 \
  --min-replicas 0 \
  --max-replicas 1 \
  --scale-rule-http-concurrency 10

# Desplegar MySQL sidecar (multi-container)
az containerapp create \
  --name banca-mysql-sidecar \
  --resource-group $RG \
  --environment $ACA_ENV \
  --image mysql:5.7 \
  --cpu 0.5 \
  --memory 1Gi \
  --env-vars \
    MYSQL_ROOT_PASSWORD=root123 \
    MYSQL_DATABASE=banca_db \
    MYSQL_USER=banca_user \
    MYSQL_PASSWORD=banca_pass123 \
  --min-replicas 1 \
  --max-replicas 1
```

> **Nota:** Para entornos dev, ACA escala el WildFly a 0 réplicas cuando no hay tráfico. El sidecar MySQL se mantiene con 1 replica mínima (o se puede reemplazar por Azure DB for MySQL).

### 6.5 Script de despliegue automatizado

Crear `scripts/azure/deploy-aca.sh`:

```bash
#!/bin/bash
set -euo pipefail

# =============================================================================
# Deploy Banca Nacional en ACA (Consumption Plan)
# =============================================================================

PROFILE="${1:-dev}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Cargar variables según perfil
source "${PROJECT_ROOT}/infra/azure/profiles/${PROFILE}.env"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "=== Build EAR ==="
cd "$PROJECT_ROOT/apps/backend-for-frontend/app-javaee"
mvn clean package -DskipTests

log "=== Build & Push Docker Image ==="
az acr login --name "$ACR_NAME"
docker build -t "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" \
  -f "${PROJECT_ROOT}/infra/docker/wildfly-azure/Dockerfile" .
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

log "=== Deploy ACA ==="
az containerapp update \
  --name "$ACA_APP_NAME" \
  --resource-group "$RG" \
  --image "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

log "=== Despliegue completado ==="
```

---

## 7. Checklist de Optimización FinOps

### 7.1 Configuración obligatoria para mínimo costo

- [ ] **Scale-to-zero** habilitado: `--min-replicas 0` en dev/test
- [ ] **Max-replicas** limitado: `--max-replicas 1` en dev, `--max-replicas 2` en prod
- [ ] **ACR Basic SKU**: $5/mes fijo (no usar Premium para dev)
- [ ] **MySQL sidecar** en dev (no pagar Azure DB for MySQL)
- [ ] **CPU/Memoria ajustados**: WildFly con 1 vCPU + 2 GB RAM es suficiente
- [ ] **Free grant aprovechado**: Las primeras 180K vCPU-s y 360K GiB-s son gratis

### 7.2 Configuración recomendada para producción económica

- [ ] **Azure DB for MySQL Flexible Server B1ms** (burstable, no General Purpose)
- [ ] **Backup retention reducido**: 7 días (default 35)
- [ ] **Geo-redundancy deshabilitado**: Solo backup local-redundant (LRS)
- [ ] **Auto-grow deshabilitado**: Storage fijo de 20 GB
- [ ] **ACA idle pricing**: Mínimo 1 replica en idle mode (tarifa reducida)
- [ ] **Azure Savings Plan** (1 año): ~20% descuento sobre PAYG

### 7.3 Monitoreo de costos

```bash
# Ver costos acumulados del mes
az consumption usage list \
  --billing-period-name $(date +%Y%m) \
  --query "[?contains(instanceName, 'banca') || contains(instanceName, 'aca')]" \
  --output table

# Alertas de presupuesto
az consumption budget create \
  --amount 50 \
  --time-grain monthly \
  --start-date $(date +%Y-%m-01) \
  --name "banca-budget" \
  --resource-group rg-banca-dev
```

### 7.4 Errores comunes que incrementan costos

| Error | Impacto | Solución |
|---|---|---|
| Dejar ACA con `--min-replicas 1` en dev | ~$10–15/mes extra | Usar `--min-replicas 0` |
| Usar ACR Premium | ~$60/mes extra | Cambiar a Basic ($5/mes) |
| DB General Purpose en dev | ~$50–80/mes extra | Usar Burstable B1ms |
| Storage DB > 32 GB en dev | ~$5–10/mes extra | Limitar a 20 GB |
| Backup retention 35 días en dev | Sin impacto mayor | Reducir a 7 días |
| Load Balancer estándar (AKS) | ~$20/mes fijo | Evitar AKS para un monolito |

---

## 8. Migración desde MicroK8s on-prem

### 8.1 Correspondencia de conceptos

| MicroK8s actual | Azure ACA (Consumption) |
|---|---|
| `deployment.yaml` | `az containerapp create` |
| `service.yaml` (ClusterIP) | `--ingress external` (ACA managed) |
| `configmap.yaml` | `--env-vars` |
| `secrets.yaml` | Key Vault reference o `--secrets` |
| `pv/pvc.yaml` | Volumen efímero o Azure Files |
| Namespace (`bancapersonas-dev`) | ACA Environment + app name |
| `kubectl apply -f` | `az containerapp create/update` |

### 8.2 Diferencias clave

1. **No más manifiestos YAML K8s** → Todo se define via `az containerapp` o Bicep/ARM
2. **No más SSH en contenedor** → Despliegue via ACR + revisiones ACA
3. **No más NodePort / LoadBalancer** → ACA maneja ingress automáticamente
4. **No más PV/PVC manuales** → Volúmenes temporales o Azure Files (si se necesita persistencia)
5. **No más contextos kubectl** → Azure RBAC + managed identity

### 8.3 Plan de migración por fases

```
Fase 1: Lift & Shift a ACA (1-2 días)
  ├── Crear Dockerfile para Azure (WildFly 10.1 + MySQL module)
  ├── Build + Push a ACR
  ├── Desplegar en ACA Consumption (dev)
  └── Validar funcionalidad

Fase 2: Base de datos (2-3 días)
  ├── Opción A: MySQL sidecar (dev/test)
  ├── Opción B: Azure DB for MySQL Flexible Server (prod)
  └── Migrar datos desde BD on-prem

Fase 3: Producción (1-2 días)
  ├── Ajustar réplicas y recursos
  ├── Configurar TLS/SSL
  ├── Monitoreo y alertas
  └── Documentación operativa
```

---

## Apéndice A: Referencias

| Recurso | URL |
|---|---|
| ACA Pricing | https://azure.microsoft.com/pricing/details/container-apps/ |
| ACA Docs | https://learn.microsoft.com/azure/container-apps/ |
| DB for MySQL Pricing | https://azure.microsoft.com/pricing/details/mysql/flexible-server/ |
| ACR Pricing | https://azure.microsoft.com/pricing/details/container-registry/ |
| Azure Pricing Calculator | https://azure.microsoft.com/pricing/calculator/ |
| FinOps on Azure | https://azure.microsoft.com/solutions/finops/ |

## Apéndice B: Costos al mes — Resumen rápido

```
┌──────────────────────┬─────────┬──────────┬────────────┐
│ Escenario            │ Dev     │ Test     │ Prod-Low   │
├──────────────────────┼─────────┼──────────┼────────────┤
│ ACA (WildFly)        │ ~$0-5   │ ~$14     │ ~$28       │
│ ACR Basic            │ ~$5     │ ~$5      │ ~$5        │
│ MySQL (sidecar/DB)   │ ~$0     │ ~$15     │ ~$18       │
├──────────────────────┼─────────┼──────────┼────────────┤
│ TOTAL                │ ~$5-10  │ ~$29-34  │ ~$46-51    │
└──────────────────────┴─────────┴──────────┴────────────┘
```

> **Conclusión:** Azure Container Apps Consumption Plan con scale-to-zero es la opción más económica para desplegar `app-javaee` en Azure, con costos desde **$0–5/mes en dev** y hasta **~$50/mes en producción baja carga**. La migración desde MicroK8s on-prem es directa al tratarse del mismo modelo de contenedores.

---

*Documento generado: Junio 2026*
*Stack: Java 8 + WildFly 10.1.0.Final + MySQL 5.7*
*Azure Region de referencia: East US (precios pueden variar por región)*
