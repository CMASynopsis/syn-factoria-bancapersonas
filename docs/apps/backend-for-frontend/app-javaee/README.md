# Banca Nacional — EAR
### Stack: Java 8 · WildFly 10.1.0.Final · MySQL 5.7.44

---

## Estructura del proyecto

```
banca-ear-mysql/                    ← POM padre
├── pom.xml
├── banca-ejb/                      ← Módulo EJB (lógica + DAOs)
│   └── src/main/java/com/banca/
│       ├── model/                  ← Usuario, Cuenta, Transferencia
│       ├── dao/                    ← UsuarioDAO, CuentaDAO, TransferenciaDAO
│       └── service/                ← EJBs Stateless
│           ├── AuthServiceLocal / AuthServiceBean
│           ├── CuentaServiceLocal / CuentaServiceBean
│           └── TransferenciaServiceLocal / TransferenciaServiceBean
├── banca-web/                      ← Módulo WAR (Servlets + JSP)
│   └── src/main/
│       ├── java/com/banca/
│       │   ├── controller/         ← Servlets con @EJB
│       │   └── filter/             ← AuthFilter
│       └── webapp/
│           ├── WEB-INF/views/      ← JSPs
│           └── css/style.css
├── banca-ear/                      ← Módulo EAR (empaquetador)
│   └── src/main/application/META-INF/application.xml
└── scripts/
    ├── banca_db_mysql57.sql        ← Script BD para MySQL 5.7
    └── module.xml                  ← Módulo MySQL para WildFly
```

---

## PASO 1 — Descargar WildFly 10.1.0.Final

```
https://download.jboss.org/wildfly/10.1.0.Final/wildfly-10.1.0.Final.zip
```

```bash
unzip wildfly-10.1.0.Final.zip
export WILDFLY_HOME=/ruta/a/wildfly-10.1.0.Final
```

---

## PASO 2 — Instalar driver MySQL 5.7 en WildFly

```bash
# 2.1 Descargar MySQL Connector/J 5.1.49
#     https://downloads.mysql.com/archives/c-j/
#     Product: Connector/J | Version: 5.1.49 | Platform: Platform Independent

# 2.2 Crear carpeta del módulo
mkdir -p $WILDFLY_HOME/modules/com/mysql/main

# 2.3 Copiar el JAR
cp mysql-connector-java-5.1.49.jar \
   $WILDFLY_HOME/modules/com/mysql/main/

# 2.4 Copiar el descriptor del módulo
cp scripts/module.xml \
   $WILDFLY_HOME/modules/com/mysql/main/
```

---

## PASO 3 — Configurar DataSource en WildFly

Editar: `$WILDFLY_HOME/standalone/configuration/standalone.xml`

### 3.1 Registrar el driver (dentro de `<drivers>`)

```xml
<driver name="mysql" module="com.mysql">
    <driver-class>com.mysql.jdbc.Driver</driver-class>
</driver>
```

### 3.2 Agregar el DataSource (dentro de `<datasources>`)

```xml
<datasource jndi-name="java:jboss/datasources/BancaDS"
            pool-name="BancaDS"
            enabled="true"
            use-java-context="true">

    <!-- MySQL 5.7: sin serverTimezone, sin cj en el driver class -->
    <connection-url>
        jdbc:mysql://localhost:3306/banca_db?useSSL=false&amp;characterEncoding=UTF-8
    </connection-url>
    <driver>mysql</driver>

    <pool>
        <min-pool-size>5</min-pool-size>
        <max-pool-size>20</max-pool-size>
        <prefill>true</prefill>
    </pool>

    <security>
        <user-name>banca_user</user-name>
        <password>banca_pass123</password>
    </security>

    <validation>
        <valid-connection-checker
            class-name="org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLValidConnectionChecker"/>
        <exception-sorter
            class-name="org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLExceptionSorter"/>
    </validation>
</datasource>
```

---

## PASO 4 — Crear la base de datos MySQL 5.7

```bash
mysql -u root -p < scripts/banca_db_mysql57.sql
```

---

## PASO 5 — Compilar el proyecto

```bash
# Desde la raíz del proyecto
mvn clean package

# Se genera el EAR en:
# banca-ear/target/banca-nacional.ear
```

---

## PASO 6 — Crear usuario admin de WildFly

```bash
$WILDFLY_HOME/bin/add-user.sh admin Admin123* --silent
```

---

## PASO 7 — Iniciar WildFly y desplegar el EAR

```bash
# Iniciar WildFly
$WILDFLY_HOME/bin/standalone.sh

# En otra terminal: copiar el EAR
cp banca-ear/target/banca-nacional.ear \
   $WILDFLY_HOME/standalone/deployments/

# WildFly auto-despliega al detectar el archivo
# Verificar en los logs: "banca-nacional.ear" deployed successfully
```

---

## PASO 8 — Acceder a la aplicación

```
http://localhost:8080/banca/login
```

| Usuario  | Contraseña | Rol     |
|----------|------------|---------|
| jgarcia  | Admin123*  | CLIENTE |
| mramirez | Admin123*  | CLIENTE |
| admin    | Admin123*  | ADMIN   |

---

## Consola de administración WildFly

```
http://localhost:9990
Usuario: admin
Password: Admin123*
```

---

## Diferencias clave MySQL 5.7 vs 8.0 en este proyecto

| Aspecto | MySQL 5.7 (este proyecto) | MySQL 8.0 |
|---|---|---|
| Driver class | `com.mysql.jdbc.Driver` | `com.mysql.cj.jdbc.Driver` |
| Connector/J | 5.1.49 | 8.0.x |
| URL | Sin `serverTimezone` | Requiere `serverTimezone` |
| Auth | `mysql_native_password` | `caching_sha2_password` |
| LIMIT | `LIMIT 20` ✅ | `LIMIT 20` ✅ |

---

## Escenario de migración (demo completa)

```
ORIGEN (este proyecto):
  CentOS 7  +  Java 8  +  WildFly 10.1  +  MySQL 5.7
        ↓             PROCESO DE MIGRACIÓN
DESTINO:
  Rocky Linux 9  +  Java 17  +  WildFly 26  +  MySQL 8.0
```
