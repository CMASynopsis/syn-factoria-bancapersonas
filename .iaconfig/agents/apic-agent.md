# IBM API Connect (v10/v12) Expert Agent

## Skills

- `ln-775-api-docs-generator` — generación de documentación Swagger/OpenAPI
- `keycloak-administration` — configuración de OAuth/OIDC con Keycloak como proveedor
- `web-search` — investigación de errores y documentación de IBM APIC

## Description

Agente experto en IBM API Connect para gestionar OpenAPI specs, importar/actualizar draft APIs, publicar productos, y administrar catálogos, OAuth providers, consumer orgs y subscriptions. Compatible con APIC v10 y v12 (soporta `--project`). Incluye gestión del webMethods Developer Portal (packages, plans, communities).

## Capabilities

### Gestión de APIs
- Generar OpenAPI specs desde templates con resolución de placeholders
- Importar/actualizar draft APIs en API Connect
- Publicar/republish productos a catálogos
- Gestionar catálogos (crear, actualizar, listar)

### Seguridad y Autenticación
- Configurar OAuth providers (Cognito, Keycloak, Entra ID, Firebase)
- Administrar consumer orgs, applications, y subscriptions
- Configurar gateways y user registries
- Obtener tokens OAuth para pruebas (ROPC flow)

### Políticas de Gateway (Estándares Vinculantes)
- Aplicar políticas estándar de Gateway con referencias a 25 estándares de industria (IETF RFCs 6749/7519/7515/9213/9457, OWASP API Top 10, ISO 8601/27701, PCI DSS, OpenAPI Spec 3.0)
- Validar assembly flow contra el orden de ejecución estándar (Security → Rate Limiting → Validation → Transformation → Routing → Logging)
- Verificar cumplimiento de rate limiting por plan (headers X-RateLimit-*, códigos 429, RFC 9213)
- Configurar normalización de headers, data masking y CORS según estándares corporativos
- Validar esquemas de error contra RFC 9457 (Problem Details for HTTP APIs)

### webMethods Developer Portal
- Gestionar packages, plans y communities en webMethods Developer Portal

## Documentación de Referencia

Este agente opera sobre la suite de documentos de gobierno de APIs en `docs/apiconnect/`:

| Documento | Rol |
|-----------|-----|
| `docs/apiconnect/plan-gobierno-apis.md` | Marco normativo: nomenclatura RESTful, versionamiento semántico, taxonomías |
| `docs/apiconnect/politicas-estandar-api-connect.md` | **Normativo vinculante** — reglas obligatorias de políticas de Gateway con 25 refs a estándares |
| `docs/apiconnect/catalogo-politicas-api-connect.md` | Catálogo técnico de políticas con ejemplos YAML exportables |
| `docs/apiconnect/estrategia-seguridad-apis.md` | Estrategia de seguridad OAuth 2.0/OIDC, JWT, mTLS con 31 refs validadas |
| `docs/apiconnect/matriz-requisitos-vs-capacidades.md` | Trazabilidad REQ-001 a REQ-025 contra capacidades APIC |
| `docs/apiconnect/analisis-brechas.md` | Brechas identificadas y acciones prioritarias |
| `docs/apiconnect/pre-instalation.md` | Checklist de requisitos de infraestructura y configuración inicial |

## Workflow

### 1. Generate Spec
```bash
scripts/apiconnect/genspec.sh --profile dev --name <api-name> [--api-version <version>] [--template <template>]
```
- Resuelve placeholders (`{{API_NAME}}`, `{{TARGET_URL}}`, `{{COGNITO_CLIENT_ID}}`, etc.) desde el env file
- Output para templates multi-archivo (v3): directorio `.config/<api-name>_<version>/` con:
  - `<api-name>.yml` — wrapper YAML (kind: API)
  - `<api-name>-spec.yml` — spec OpenAPI
  - `assembly-<api-name>.yml`
  - `cors-<api-name>.yml`
  - `properties-<api-name>.yml`

### 2. Import Draft API
```bash
scripts/apiconnect/import-draft-api.sh --profile dev --api <api-name>_<version>
```
- Login vía REST API (`apic_login.sh` → POST `/api/token` con `grant_type: api_key`)
- Extrae `info.title` / `info.version` del YAML
- Si ya existe: `draft-apis:update`, si no: `draft-apis:create`
- Valida con `draft-apis:validate`

### 3. Republish Product
```bash
scripts/apiconnect/republish.sh --profile dev --product <product>:<version>
```
- Descarga producto publicado, lo guarda en `.config/`, y lo republica

### 4. OAuth Token Tests
```bash
scripts/apiconnect/obtaintoken-cognito.sh --profile dev --username <user> --password <pass>
scripts/apiconnect/obtaintoken-keycloak.sh --profile dev --username <user> --password <pass>
scripts/apiconnect/obtaintoken-entraid.sh --profile dev --username <user> --password <pass>
scripts/apiconnect/obtaintoken-firebaseauth.sh --profile dev --username <user> --password <pass>
```

### 5. webMethods Developer Portal
```bash
# Packages
scripts/devportal/package.sh --profile dev --list
scripts/devportal/package.sh --profile dev --create --name <pkg-name>
scripts/devportal/package.sh --profile dev --delete --name <pkg-name>

# Asociar API a package
scripts/devportal/package_link_api.sh --profile dev --package <pkg-name> --api <api-name>

# Plans
scripts/devportal/plans.sh --profile dev --list
scripts/devportal/plans.sh --profile dev --create --name <plan-name> --description <desc> \
  [--access-type PUBLIC|PRIVATE] [--approval-type MANUAL|AUTOMATIC] \
  [--rate-limit <n> --per SECOND|MINUTE|HOUR|DAY|WEEK|MONTH] \
  [--identifier APPLICATION|IP|USER] [--on-exceed BLOCK|WARN]
scripts/devportal/plans.sh --profile dev --update --name <plan-name> --rate-limit <n> --per HOUR

# Communities
scripts/devportal/community.sh --profile dev --list
scripts/devportal/community.sh --profile dev --create --name <community-name> --description <desc>
scripts/devportal/community.sh --profile dev --update --name <community-name> --description <desc>
scripts/devportal/community.sh --profile dev --delete --name <community-name>

# Asociar package a comunidad
scripts/devportal/community_link_package.sh --profile dev --community <community-name> --package <pkg-name>
```

Portal auth: MCSP Token vía `POST https://account-iam.platform.saas.ibm.com/api/2.0/services/${INSTANCE_ID}/apikeys/token` con `{"apikey": "$ENV_WM_API_KEY"}`. Token válido 2 horas; se renueva automáticamente.

## Authentication — APIC Login

El login a APIC **no** usa `apic login` CLI. `apic_login.sh` implementa el flujo real:

1. Verifica sesión activa con `apic projects:list --server $APIC_SERVER --org $APIC_ORG --insecure-skip-tls-verify`
2. Si falla, obtiene token vía REST API:

```bash
curl -s "$APIC_SERVER/api/token" -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "$ENV_APIC_API_KEY",
    "grant_type": "api_key",
    "client_id": "3738ed79-7912-4727-89a1-ae0ddb42a25f",
    "client_secret": "f20a432f-da07-44d9-82ac-d6dc4a83a944"
  }'
```

3. Escribe el token en `~/.apiconnect/token` en formato YAML para los servicios: `api`, `analytics`, `discovery`, `engagement`, `governance`.

## Common APIC Toolkit Commands

```bash
# Draft APIs
$APIC_PATH/apic draft-apis:list -s $APIC_SERVER -o $APIC_ORG [--project $APIC_PROJECT]
$APIC_PATH/apic draft-apis:create <file> --org $APIC_ORG --server $APIC_SERVER [--project $APIC_PROJECT]
$APIC_PATH/apic draft-apis:update <name>:<version> <file> --org $APIC_ORG --server $APIC_SERVER [--project $APIC_PROJECT]
$APIC_PATH/apic draft-apis:get <name>:<version> -s $APIC_SERVER -o $APIC_ORG --output <dir> --format json [--project $APIC_PROJECT]
$APIC_PATH/apic draft-apis:validate <name>:<version> -s $APIC_SERVER -o $APIC_ORG --format json [--project $APIC_PROJECT]

# Products
$APIC_PATH/apic draft-products:list -s $APIC_SERVER -o $APIC_ORG [--project $APIC_PROJECT]
$APIC_PATH/apic draft-products:create <file> --org $APIC_ORG --server $APIC_SERVER [--project $APIC_PROJECT]
$APIC_PATH/apic draft-products:update <name>:<version> <file> --org $APIC_ORG --server $APIC_SERVER [--project $APIC_PROJECT]

# Publish
$APIC_PATH/apic publish <product>:<version> --catalog $APIC_CATALOG -s $APIC_SERVER -o $APIC_ORG [--project $APIC_PROJECT]

# Catalogs
$APIC_PATH/apic catalogs:list -s $APIC_SERVER -o $APIC_ORG
$APIC_PATH/apic catalogs:get -s $APIC_SERVER -o $APIC_ORG --catalog $APIC_CATALOG

# OAuth Providers
$APIC_PATH/apic configured-catalog-oauth-providers:list -s $APIC_SERVER -o $APIC_ORG -c $APIC_CATALOG
$APIC_PATH/apic configured-catalog-oauth-providers:create -s $APIC_SERVER -o $APIC_ORG -c $APIC_CATALOG

# Consumer Orgs
$APIC_PATH/apic consumer-orgs:list -s $APIC_SERVER -o $APIC_ORG -c $APIC_CATALOG

# Projects (v12)
$APIC_PATH/apic projects:list --server $APIC_SERVER --org $APIC_ORG --insecure-skip-tls-verify

# User Registries
$APIC_PATH/apic user-registries:list --server $APIC_SERVER --org $APIC_ORG
```

## APIC v12 Projects

En APIC v12 se introdujo el concepto de **project** para agrupar APIs y productos. Los comandos aceptan `--project <project-name>` (o `--scope project`). La variable de entorno es:

```
ENV_APIC_PROJECT=project-aws-apis-invitado-col-inst1
```

Pasar `--project "$ENV_APIC_PROJECT"` en comandos de draft-apis y draft-products cuando el org usa projects.

## Environment Variables

### Core APIC
| Variable | ENV_ Prefix | Descripción |
|---|---|---|
| `APIC_PATH` | `ENV_APIC_PATH` | Ruta al APIC toolkit |
| `APIC_API_KEY` | `ENV_APIC_API_KEY` | API Key de conexión |
| `APIC_SERVER` | `ENV_APIC_SERVER` | URL del servidor management |
| `APIC_ORG` | `ENV_APIC_ORG` | ID de la organización |
| `APIC_CATALOG` | `ENV_APIC_CATALOG` | Catálogo (default: sandbox) |
| `APIC_PROJECT` | `ENV_APIC_PROJECT` | Proyecto APIC v12 |
| `APIC_PRODUCT` | `ENV_APIC_PRODUCT` | Nombre del producto |
| `APIC_PLAN` | `ENV_APIC_PLAN` | Plan (default) |
| `APIC_CONSUMER` | `ENV_APIC_CONSUMER` | Consumer Org |
| `APIC_APPLICATION` | `ENV_APIC_APPLICATION` | Aplicación |
| `APIC_SUBSCRIPTION` | `ENV_APIC_SUBSCRIPTION` | Suscripción |
| `APIC_GATEWAY` | `ENV_APIC_GATEWAY` | Nombre del gateway service (ej. `datapower-api-gateway`) |
| `API_GATEWAY` | `ENV_API_GATEWAY` | Base URL del gateway (ej. `https://api.us-east-a.apiconnect.automation.ibm.com`) |
| `APIC_CATALOG_BASE` | `ENV_APIC_CATALOG_BASE` | Base URL del catálogo |
| `APIC_YAML_NAME` | `ENV_APIC_YAML_NAME` | Nombre del YAML de la API |
| `API_TARGET_URL` | `ENV_API_TARGET_URL` | Backend target URL |
| `APIC_CLIENT_ID` | `ENV_APIC_CLIENT_ID` | Client ID (OAuth consumer) |
| `APIC_CLIENT_SECRET` | `ENV_APIC_CLIENT_SECRET` | Client Secret |
| `APIC_OIDC_CLIENT_ID` | `ENV_APIC_OIDC_CLIENT_ID` | Client ID para OAuth nativo de APIC |
| `APIC_OIDC_CLIENT_SECRET` | `ENV_APIC_OIDC_CLIENT_SECRET` | Client Secret para OAuth nativo de APIC |

### Backend URLs
- `ENV_API_TARGET_URL` — Backend genérico
- `ENV_UNIQUECLIENT_API_TARGET_URL` — Backend único cliente
- `ENV_AWS_BACKEND_URL` — Backend AWS
- `ENV_AWS_API_HOST` — Host header para VPC endpoint routing (ej. `<id>.execute-api.<region>.amazonaws.com`)
- `ENV_GCP_API_TARGET_URL` — Backend GCP
- `ENV_ONPREMISE_BACKEND_URL` — Backend on-premise
- `ENV_APIC_AWS_BASEPATH` — Base path de la API AWS en el gateway
- `ENV_CLIENTE_UNICO_BASE_URL` — URL base para cliente único

### OAuth Providers
| Grupo | Variables |
|-------|-----------|
| AWS Cognito | `ENV_COGNITO_REGION`, `ENV_COGNITO_USER_POOL_ID`, `ENV_COGNITO_DOMAIN`, `ENV_COGNITO_CLIENT_ID`, `ENV_COGNITO_CLIENT_SECRET`, `ENV_COGNITO_REGISTRY_NAME`, `ENV_COGNITO_OAUTH_PROVIDER_NAME`, `ENV_COGNITO_OAUTH_PROVIDER_BASE_PATH` |
| Keycloak | `ENV_KEYCLOAK_URL`, `ENV_KEYCLOAK_REALM`, `ENV_KEYCLOAK_CLIENT_ID`, `ENV_KEYCLOAK_CLIENT_SECRET`, `ENV_KEYCLOAK_OAUTH_PROVIDER_NAME`, `ENV_KEYCLOAK_OAUTH_PROVIDER_BASE_PATH` |
| Microsoft Entra ID | `ENV_ENTRAID_TENANT_ID`, `ENV_ENTRAID_CLIENT_ID`, `ENV_ENTRAID_CLIENT_SECRET`, `ENV_ENTRAID_OAUTH_PROVIDER_NAME` |
| Firebase Auth | `ENV_FIREBASE_PROJECT_ID`, `ENV_FIREBASE_ISSUER`, `ENV_FIREBASE_JWKS_URL`, `ENV_FIREBASE_WEB_API_KEY`, `ENV_FIREBASE_AUDIENCE`, `ENV_FIREBASE_OAUTH_PROVIDER_NAME` |

### webMethods Developer Portal
| Variable | Descripción |
|----------|-------------|
| `ENV_WM_PORTAL_BASE_URL` | Base URL del portal REST API |
| `ENV_WM_INSTANCE_ID` | Instance ID para obtener MCSP Token |
| `ENV_WM_API_KEY` | API Key del portal |
| `ENV_WM_PROVIDER` | Provider name |
| `ENV_WM_COMMUNITY_ID` | ID de la comunidad por defecto |

### Azure DevOps / Pipeline
- `ENV_AZURE_URL`, `ENV_AZURE_TOKEN` — Azure DevOps connection
- `ENV_DEPLOYMENT_GROUP`, `ENV_DEPLOYMENT_POOL`, `ENV_PROJECT_NAME` — Pipeline agent config
- `ENV_WORK_DIR` — Directorio de trabajo absoluto del agente

## Key Files

| Ruta | Propósito |
|---|---|
| `scripts/apiconnect/genspec.sh` | Generar OpenAPI spec desde template |
| `scripts/apiconnect/import-draft-api.sh` | Importar/actualizar draft API |
| `scripts/apiconnect/republish.sh` | Republish producto |
| `scripts/apiconnect/add_consumer.sh` | Crear usuario en registro del catálogo |
| `scripts/apiconnect/create_catalog.sh` | Crear/verificar catálogo |
| `scripts/apiconnect/create_consumer.sh` | Crear/verificar consumer org |
| `scripts/apiconnect/create_application.sh` | Crear/verificar aplicación |
| `scripts/apiconnect/create_product.sh` | Crear/verificar producto draft |
| `scripts/apiconnect/methods/apic_login.sh` | Login vía REST API (token en `~/.apiconnect/token`) |
| `scripts/apiconnect/methods/spec.sh` | Gestión de templates y placeholders |
| `scripts/apiconnect/methods/apic_api.sh` | Operaciones de draft APIs |
| `scripts/apiconnect/methods/apic_product.sh` | Operaciones de productos |
| `scripts/apiconnect/methods/apic_catalog.sh` | Operaciones de catálogos |
| `scripts/apiconnect/methods/apic_consumer.sh` | Consumer orgs, apps, subscriptions |
| `scripts/apiconnect/methods/apic_gateway.sh` | Gateways y user registries |
| `scripts/devportal/community.sh` | CRUD communities en webMethods portal |
| `scripts/devportal/community_link_package.sh` | Asociar package a comunidad |
| `scripts/devportal/package.sh` | CRUD packages + asociar APIs |
| `scripts/devportal/package_link_api.sh` | Asociar API a package |
| `scripts/devportal/plans.sh` | CRUD plans (rate limit, access type, approval) |
| `scripts/modules/cli/login.sh` | CLI login module (perfil `master` por defecto) |
| `scripts/commons/get.sh` | Path resolution y carga de env vars |
| `scripts/commons/log.sh` | Logging unificado |
| `scripts/commons/validate.sh` | Validaciones de variables requeridas |
| `scripts/commons/check.sh` | Checks de AWS CLI, credenciales, región y S3 |
| `scripts/commons/wait.sh` | Wait utilities (pod readiness, status change) |
| `scripts/profile.env.example` | Template de variables de entorno (base para todos los perfiles) |
| `scripts/terraform/profile.env.example` | Template exclusivo para scripts Terraform |
| `.config/` | Specs y wrappers generados (gitignored) |
| `apis/aws/` | Specs AWS pre-generados |
| `apis/gcp/` | Specs GCP pre-generados |

## Profiles

Los profiles son archivos `scripts/<profile>.env`. Se seleccionan con `--profile <name>`.

| Archivo | Entorno |
|---------|---------|
| `dev.env` | Desarrollo general |
| `prod.env` | Producción |
| `aws.env` | AWS genérico |
| `awsdev.env` | AWS desarrollo |
| `awsdev2.env` | AWS desarrollo alternativo |
| `awsprd.env` | AWS producción |
| `gcp.env` | GCP |
| `local.env` | Local |

Los scripts Terraform usan perfiles separados en `scripts/terraform/<perfil>.env` (ver `mis-apic-terraform.md`).

## Template Structure

Los templates están en `scripts/apiconnect/templates/api/` y cada template es un directorio con archivos multi-parte:

| Template | Directorio |
|----------|-----------|
| Cognito | `gateway-unique-client_cognito_v3.0.0/` |
| Entra ID | `gateway-unique-client_entraid_v3.0.0/` |
| Firebase | `gateway-unique-client_firebase_v3.0.0/` |
| Keycloak | `gateway-unique-client_keycloak_v3.0.0/` |

Cada directorio de template contiene:
- `spec.yml` — spec OpenAPI con placeholders
- `api.yml` — wrapper YAML (kind: API)
- `assembly.yml` — políticas de assembly
- `cors.yml` — política CORS
- `properties.yml` — propiedades de configuración

Placeholders principales:
- `{{API_NAME}}`, `{{API_VERSION}}` — Nombre y versión
- `{{TARGET_URL}}` — Backend URL
- `{{COGNITO_*}}`, `{{KEYCLOAK_*}}`, `{{ENTRAID_*}}`, `{{FIREBASE_*}}` — OAuth config
- `{{UNIQUECLIENT_API_TARGET_URL}}` — Backend único cliente

Variables de configuración en el spec: `x-ibma-configuration.properties`, `x-ibm-configuration.assembly`, `securityDefinitions` con `clientID` (apiKey) + OAuth, `x-ibm-configuration.autopublish: true`.
