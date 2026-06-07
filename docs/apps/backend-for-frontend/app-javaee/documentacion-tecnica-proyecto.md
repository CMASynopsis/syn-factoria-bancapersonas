# Documentación Técnica - Sistema Bancario Nacional

## 📋 Información General del Proyecto

**Nombre:** Banca Nacional - Sistema de Banca en Línea  
**Versión:** 1.0.0  
**Tipo:** Aplicación Empresarial Java EE 7  
**Arquitectura:** Multi-módulo Maven (EAR)  
**Fecha de Análisis:** 2026-06-04

---

## 🏗️ Arquitectura del Sistema

### Stack Tecnológico Actual

| Componente | Versión | Propósito |
|------------|---------|-----------|
| **Java** | 8 (1.8) | Lenguaje de programación |
| **Java EE** | 7.0 | Framework empresarial |
| **Application Server** | WildFly 10.1.0.Final | Servidor de aplicaciones |
| **Base de Datos** | MySQL 5.7.44 | Sistema de gestión de BD |
| **Build Tool** | Maven 3.x | Gestión de dependencias y construcción |
| **Empaquetado** | EAR (Enterprise Archive) | Formato de distribución |

### Dependencias Principales

- **Java EE 7 API** (javax:javaee-api:7.0) - Provided
- **MySQL Connector** (mysql:mysql-connector-java:5.1.49) - Provided
- **Log4j2** (org.apache.logging.log4j:2.17.2)
- **BCrypt** (org.mindrot:jbcrypt:0.4)
- **JSTL** (javax.servlet:jstl:1.2)

---

## 📦 Estructura del Proyecto

### Módulos Maven

```
banca-parent (POM)
├── banca-ejb (EJB Module) → banca-ejb.jar
├── banca-web (WAR Module) → banca-web.war
└── banca-ear (EAR Module) → banca-nacional.ear
```

### Árbol de Directorios

```
c:/BancaPersonas/
├── pom.xml (POM padre)
├── README.md
├── banca-ejb/
│   ├── pom.xml
│   └── src/main/java/com/banca/
│       ├── model/ (3 clases)
│       │   ├── Usuario.java
│       │   ├── Cuenta.java
│       │   └── Transferencia.java
│       ├── dao/ (3 clases)
│       │   ├── UsuarioDAO.java
│       │   ├── CuentaDAO.java
│       │   └── TransferenciaDAO.java
│       └── service/ (6 clases)
│           ├── AuthServiceLocal.java
│           ├── AuthServiceBean.java
│           ├── CuentaServiceLocal.java
│           ├── CuentaServiceBean.java
│           ├── TransferenciaServiceLocal.java
│           └── TransferenciaServiceBean.java
├── banca-web/
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/banca/
│       │   ├── controller/ (4 servlets)
│       │   │   ├── LoginServlet.java
│       │   │   ├── LogoutServlet.java
│       │   │   ├── HomeServlet.java
│       │   │   └── TransferenciaServlets.java
│       │   └── filter/
│       │       └── AuthFilter.java
│       └── webapp/
│           ├── index.jsp
│           ├── css/style.css
│           └── WEB-INF/
│               ├── web.xml
│               └── views/ (7 JSPs)
│                   ├── header.jsp
│                   ├── login.jsp
│                   ├── home.jsp
│                   └── transferencia/
│                       ├── propia.jsp
│                       ├── mismo-banco.jsp
│                       └── otro-banco.jsp
├── banca-ear/
│   ├── pom.xml
│   └── src/main/application/META-INF/
│       └── application.xml
└── scripts/
    ├── banca_db_mysql57.sql
    └── module.xml
```

---

## 🗄️ Modelo de Datos

### Diagrama Entidad-Relación

```
USUARIO (1) ──────< (N) CUENTA (1) ──────< (N) TRANSFERENCIA
```

### Tablas de Base de Datos

#### 1. USUARIO
Almacena información de usuarios del sistema.

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| id | BIGINT | PK, AUTO_INCREMENT | Identificador único |
| username | VARCHAR(50) | NOT NULL, UNIQUE | Nombre de usuario |
| password | VARCHAR(255) | NOT NULL | Hash BCrypt |
| nombres | VARCHAR(100) | NOT NULL | Nombres |
| apellidos | VARCHAR(100) | NOT NULL | Apellidos |
| email | VARCHAR(150) | NOT NULL, UNIQUE | Correo electrónico |
| telefono | VARCHAR(20) | NULL | Teléfono |
| estado | VARCHAR(20) | NOT NULL | ACTIVO/INACTIVO/BLOQUEADO |
| rol | VARCHAR(20) | NOT NULL | CLIENTE/ADMIN |
| intentos_fallidos | TINYINT | NOT NULL, DEFAULT 0 | Intentos de login |
| fecha_creacion | DATETIME | NOT NULL, DEFAULT NOW() | Fecha de registro |
| ultimo_acceso | DATETIME | NULL | Último acceso |

#### 2. CUENTA
Almacena cuentas bancarias.

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| id | BIGINT | PK, AUTO_INCREMENT | Identificador único |
| numero_cuenta | VARCHAR(13) | NOT NULL, UNIQUE | Número de cuenta |
| cci | VARCHAR(20) | NOT NULL, UNIQUE | CCI (20 dígitos) |
| tipo_cuenta | VARCHAR(20) | NOT NULL | AHORROS/CORRIENTE |
| moneda | VARCHAR(3) | NOT NULL | PEN/USD |
| saldo | DECIMAL(15,2) | NOT NULL | Saldo total |
| saldo_disponible | DECIMAL(15,2) | NOT NULL | Saldo disponible |
| estado | VARCHAR(20) | NOT NULL | ACTIVA/INACTIVA/BLOQUEADA |
| usuario_id | BIGINT | NOT NULL, FK | Propietario |
| fecha_apertura | DATETIME | NOT NULL | Fecha de apertura |

#### 3. TRANSFERENCIA
Registra transferencias bancarias.

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| id | BIGINT | PK, AUTO_INCREMENT | Identificador único |
| numero_operacion | VARCHAR(20) | NOT NULL, UNIQUE | Número de operación |
| tipo_transferencia | VARCHAR(20) | NOT NULL | PROPIA/MISMO_BANCO/OTRO_BANCO |
| cuenta_origen_id | BIGINT | NOT NULL, FK | Cuenta origen |
| cuenta_destino_id | BIGINT | NULL, FK | Cuenta destino |
| cuenta_destino_cci | VARCHAR(20) | NULL | CCI destino |
| banco_destino | VARCHAR(100) | NULL | Banco destino |
| titular_destino | VARCHAR(200) | NULL | Titular destino |
| monto | DECIMAL(15,2) | NOT NULL | Monto |
| moneda | VARCHAR(3) | NOT NULL | Moneda |
| glosa | VARCHAR(200) | NULL | Descripción |
| estado | VARCHAR(20) | NOT NULL | PROCESADA/PENDIENTE/RECHAZADA |
| fecha_operacion | DATETIME | NOT NULL | Fecha de operación |
| usuario_id | BIGINT | NOT NULL | Usuario que realizó |

---

## 🔧 Componentes del Sistema

### Capa de Modelo (3 clases)

#### Usuario.java
- **Responsabilidad:** Representa un usuario del sistema
- **Atributos:** id, username, password, nombres, apellidos, email, telefono, estado, rol
- **Métodos:** getNombreCompleto()

#### Cuenta.java
- **Responsabilidad:** Representa una cuenta bancaria
- **Atributos:** id, numeroCuenta, cci, tipoCuenta, moneda, saldo, saldoDisponible, estado
- **Métodos:** getNumeroCuentaFormateado() (formato: 123-456-789-0123)

#### Transferencia.java
- **Responsabilidad:** Representa una transferencia bancaria
- **Atributos:** numeroOperacion, tipoTransferencia, cuentas, monto, estado, fechas
- **Métodos:** getTipoTransferenciaDescripcion()

### Capa DAO (3 clases)

#### UsuarioDAO.java
**Métodos principales:**
- `findByUsername(Connection, String)` - Buscar usuario por username
- `updateUltimoAcceso(Connection, Long)` - Actualizar último acceso
- `incrementarIntentosFallidos(Connection, String)` - Incrementar intentos fallidos
- `resetearIntentosFallidos(Connection, String)` - Resetear intentos

**Características:**
- JDBC puro (sin ORM)
- PreparedStatements para prevenir SQL injection
- Mapeo manual ResultSet → Objeto

#### CuentaDAO.java
**Métodos principales:**
- `findByUsuario(Connection, Long)` - Obtener cuentas de un usuario
- `findById(Connection, Long)` - Buscar cuenta por ID
- `findByNumeroCuenta(Connection, String)` - Buscar por número
- `actualizarSaldo(Connection, Long, BigDecimal, BigDecimal)` - Actualizar saldos

**Query destacado:**
```sql
SELECT c.*, u.nombres, u.apellidos 
FROM cuenta c 
INNER JOIN usuario u ON c.usuario_id = u.id
```

#### TransferenciaDAO.java
**Métodos principales:**
- `insertar(Connection, Transferencia)` - Insertar nueva transferencia
- `findByUsuario(Connection, Long)` - Historial de transferencias

**Características especiales:**
- Usa `LIMIT 20` (sintaxis MySQL)
- Retorna ID generado con `RETURN_GENERATED_KEYS`
- Maneja campos NULL para transferencias interbancarias

### Capa de Servicios EJB (6 clases)

#### AuthServiceBean.java
**Tipo:** EJB Stateless  
**Transacción:** REQUIRED  
**Responsabilidad:** Autenticación de usuarios

**Método principal:**
```java
public LoginResult login(String username, String password)
```

**Proceso:**
1. Validar parámetros
2. Buscar usuario en BD
3. Verificar hash BCrypt
4. Actualizar último acceso
5. Retornar resultado (exitoso/fallido)

**Características:**
- Usa BCrypt.checkpw() para verificación
- Logging con Log4j2
- Inyección de DataSource con @Resource

#### CuentaServiceBean.java
**Tipo:** EJB Stateless  
**Transacción:** SUPPORTS (solo lectura)  
**Responsabilidad:** Consultas de cuentas

**Métodos:**
- `obtenerCuentasUsuario(Long)` - Lista de cuentas
- `obtenerCuentaPorNumero(String)` - Buscar cuenta

#### TransferenciaServiceBean.java
**Tipo:** EJB Stateless  
**Transacción:** REQUIRED (transaccional)  
**Responsabilidad:** Gestión de transferencias

**Métodos principales:**

1. **transferirPropia()** - Entre cuentas propias
   - Validaciones: misma moneda, saldo suficiente
   - Proceso: débito origen + crédito destino

2. **transferirMismoBanco()** - A cuenta del mismo banco
   - Validaciones: cuenta destino existe, no misma cuenta
   - Proceso: débito origen + crédito destino

3. **transferirOtroBanco()** - Interbancaria (CCI)
   - Validaciones: CCI 20 dígitos, monto máximo S/ 50,000
   - Proceso: solo débito origen (destino externo)

**Características transaccionales:**
- Container-Managed Transactions (CMT)
- RuntimeException → Rollback automático
- Operaciones atómicas
- Logging detallado

**Método auxiliar:**
```java
private String generarNroOp() {
    return UUID.randomUUID().toString()
               .replace("-", "")
               .substring(0, 16)
               .toUpperCase();
}
```

### Capa Web (5 componentes)

#### LoginServlet.java
**URL:** `/login`  
**Responsabilidad:** Gestión de login

**Flujo:**
- GET: Muestra formulario de login
- POST: Procesa credenciales, crea sesión, redirige a home

**Inyección:**
```java
@EJB
private AuthServiceLocal authService;
```

#### HomeServlet.java
**URL:** `/home`  
**Responsabilidad:** Dashboard principal

**Proceso:**
1. Obtener usuario de sesión
2. Cargar cuentas (vía EJB)
3. Cargar historial de transferencias
4. Renderizar vista home.jsp

#### TransferenciaServlets.java
**URLs:** `/transferencia/propia`, `/transferencia/mismo-banco`, `/transferencia/otro-banco`  
**Responsabilidad:** Gestión de transferencias

**Patrón:**
- GET: Muestra formulario
- POST: Procesa transferencia, muestra resultado

#### AuthFilter.java
**Patrón:** `@WebFilter("/*")`  
**Responsabilidad:** Filtro de autenticación

**Lógica:**
1. Verificar si URL es pública (login, css, js)
2. Si no, verificar sesión activa
3. Si no hay sesión, redirigir a login
4. Agregar headers de seguridad

**URLs públicas:**
```java
/login, /index.jsp, /css/, /js/, /images/
```

**Headers de seguridad:**
```java
Cache-Control: no-cache, no-store, must-revalidate
Pragma: no-cache
Expires: 0
```

### Capa de Vista (7 JSPs)

#### login.jsp
- Formulario de inicio de sesión
- Logo SVG del banco
- Validación HTML5
- Manejo de errores

#### home.jsp
- Dashboard principal
- Tarjetas de cuentas con saldos
- Menú de transferencias
- Historial de operaciones (últimas 20)

**Librerías JSTL:**
```jsp
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
```

#### header.jsp
- Cabecera común
- Logo y nombre de usuario
- Botón de logout

#### Vistas de transferencia
- **propia.jsp** - Entre cuentas propias
- **mismo-banco.jsp** - Mismo banco
- **otro-banco.jsp** - Interbancaria (CCI)

---

## 🔐 Seguridad

### Autenticación
- **Método:** BCrypt para hash de contraseñas
- **Implementación:** `BCrypt.checkpw(password, hash)`
- **Almacenamiento:** VARCHAR(255) en BD

### Autorización
- **Filtro:** AuthFilter intercepta todas las peticiones
- **Sesión:** Timeout de 30 minutos
- **Control:** Objeto Usuario en sesión HTTP

### Control de Intentos Fallidos
- Incrementa contador en cada login fallido
- Resetea en login exitoso
- Base para bloqueo de cuenta

### Headers de Seguridad
```
Cache-Control: no-cache, no-store, must-revalidate
Pragma: no-cache
Expires: 0
```

---

## 🔄 Flujos de Negocio

### Flujo de Login
```
Usuario → LoginServlet → AuthServiceBean → UsuarioDAO → MySQL
                                ↓
                         Verificar BCrypt
                                ↓
                    Crear sesión / Mostrar error
```

### Flujo de Transferencia
```
Usuario → TransferenciaServlet → TransferenciaServiceBean
                                         ↓
                                  [TRANSACCIÓN]
                                         ↓
                    CuentaDAO.actualizarSaldo() (origen)
                                         ↓
                    CuentaDAO.actualizarSaldo() (destino)
                                         ↓
                    TransferenciaDAO.insertar()
                                         ↓
                              COMMIT / ROLLBACK
```

---

## 📊 Configuración de WildFly

### DataSource
**JNDI:** `java:jboss/datasources/BancaDS`

```xml
<datasource jndi-name="java:jboss/datasources/BancaDS"
            pool-name="BancaDS" enabled="true">
    <connection-url>
        jdbc:mysql://localhost:3306/banca_db?useSSL=false
    </connection-url>
    <driver>mysql</driver>
    <pool>
        <min-pool-size>5</min-pool-size>
        <max-pool-size>20</max-pool-size>
    </pool>
    <security>
        <user-name>banca_user</user-name>
        <password>banca_pass123</password>
    </security>
</datasource>
```

### Driver MySQL
**Módulo:** `com.mysql`  
**Clase:** `com.mysql.jdbc.Driver`  
**JAR:** `mysql-connector-java-5.1.49.jar`

---

## 🚀 Proceso de Despliegue

### 1. Compilación
```bash
mvn clean package
# Genera: banca-ear/target/banca-nacional.ear
```

### 2. Despliegue
```bash
cp banca-ear/target/banca-nacional.ear \
   $WILDFLY_HOME/standalone/deployments/
```

### 3. Acceso
```
http://localhost:8080/banca/login
```

**Usuarios de prueba:**
- jgarcia / Admin123*
- mramirez / Admin123*
- admin / Admin123*

---

## 📈 Métricas del Proyecto

| Métrica | Cantidad |
|---------|----------|
| Módulos Maven | 3 |
| Clases Java | 16 |
| Interfaces EJB | 3 |
| Servlets | 4 |
| Filtros | 1 |
| Archivos JSP | 7 |
| Tablas BD | 3 |
| Líneas Java | ~1,500 |
| Líneas JSP | ~800 |
| Líneas SQL | ~200 |

### Distribución por Capa
- **Modelo:** 3 clases (~150 líneas)
- **DAO:** 3 clases (~300 líneas)
- **Service:** 6 clases (~400 líneas)
- **Controller:** 4 clases (~250 líneas)
- **Filter:** 1 clase (~50 líneas)
- **Vista:** 7 archivos (~800 líneas)

---

## 🎯 Patrones de Diseño

### 1. Data Access Object (DAO)
- **Ubicación:** `com.banca.dao`
- **Propósito:** Encapsular acceso a BD
- **Beneficio:** Separación de responsabilidades

### 2. Service Layer (EJB)
- **Ubicación:** `com.banca.service`
- **Propósito:** Lógica de negocio transaccional
- **Beneficio:** Gestión automática de transacciones

### 3. Front Controller (Servlet)
- **Ubicación:** `com.banca.controller`
- **Propósito:** Manejo de peticiones HTTP
- **Beneficio:** Punto único de entrada

### 4. Filter Chain
- **Ubicación:** `com.banca.filter`
- **Propósito:** Lógica transversal (autenticación)
- **Beneficio:** Código reutilizable

### 5. Transfer Object (DTO)
- **Ubicación:** Clases internas en Services
- **Ejemplos:** LoginResult, TransferenciaResult
- **Beneficio:** Encapsulación de resultados

---

## 🔍 Características Técnicas Destacadas

### 1. Gestión de Transacciones
- **Tipo:** Container-Managed Transactions (CMT)
- **Propagación:** REQUIRED en servicios transaccionales
- **Rollback:** Automático en RuntimeException
- **Aislamiento:** Gestionado por MySQL (READ COMMITTED)

### 2. Inyección de Dependencias
```java
@EJB
private AuthServiceLocal authService;

@Resource(lookup = "java:jboss/datasources/BancaDS")
private DataSource dataSource;
```

### 3. Logging
- **Framework:** Log4j2
- **Niveles:** INFO, WARN, ERROR
- **Ubicación:** Todos los servicios y DAOs

### 4. Validaciones
- **Capa Web:** Validación HTML5 en formularios
- **Capa Servicio:** Validaciones de negocio
- **Capa DAO:** PreparedStatements (prevención SQL injection)

### 5. Manejo de Errores
- **SQLException:** Capturada y logueada
- **RuntimeException:** Provoca rollback automático
- **Mensajes:** Amigables para el usuario

---

## 📝 Notas Técnicas Importantes

### MySQL 5.7 vs 8.0
| Aspecto | MySQL 5.7 | MySQL 8.0 |
|---------|-----------|-----------|
| Driver class | `com.mysql.jdbc.Driver` | `com.mysql.cj.jdbc.Driver` |
| Connector/J | 5.1.49 | 8.0.x |
| URL | Sin `serverTimezone` | Requiere `serverTimezone` |
| Auth | `mysql_native_password` | `caching_sha2_password` |

### Compatibilidad Java EE 7
- **Servlet API:** 3.1
- **EJB API:** 3.2
- **JSTL:** 1.2
- **JSP:** 2.3

### Limitaciones Actuales
- No usa JPA (usa JDBC puro)
- No tiene API REST
- No tiene tests unitarios
- No usa CDI (solo EJB)

---

## 🎓 Conclusiones

### Fortalezas del Proyecto
✅ Arquitectura clara en capas  
✅ Separación de responsabilidades  
✅ Gestión transaccional robusta  
✅ Seguridad básica implementada  
✅ Código bien estructurado  

### Áreas de Mejora
⚠️ Migrar a Jakarta EE 10  
⚠️ Actualizar a Java 21  
⚠️ Implementar tests unitarios  
⚠️ Agregar API REST  
⚠️ Usar JPA en lugar de JDBC  
⚠️ Implementar CDI  

### Recomendaciones
1. Migrar a WildFly 31+ para soporte Java 21
2. Actualizar MySQL Connector a 8.x
3. Refactorizar javax.* a jakarta.*
4. Implementar suite de tests
5. Considerar microservicios para escalabilidad

---

**Documento generado:** 2026-06-04  
**Versión del proyecto:** 1.0.0  
**Stack:** Java 8 + WildFly 10.1 + MySQL 5.7
