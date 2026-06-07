# =============================================================================
# Stage 1: Build EAR with Maven + JDK 8
# =============================================================================
FROM maven:3.8-openjdk-8 AS build

ARG APP_VERSION=1.0.0
ARG MYSQL_CONNECTOR_VERSION=5.1.49

WORKDIR /build
COPY . .
RUN mvn clean package -DskipTests -q

RUN mkdir -p /tmp/mysql-module && \
    cp ~/.m2/repository/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar /tmp/mysql-module/

# =============================================================================
# Stage 2: WildFly 10.1 runtime
# =============================================================================
FROM jboss/wildfly:10.1.0.Final

ARG APP_VERSION=1.0.0
ARG MYSQL_CONNECTOR_VERSION=5.1.49
ARG WILDFLY_USER=admin
ARG WILDFLY_PASSWORD=Admin123*

ENV MYSQL_HOST=localhost \
    MYSQL_PORT=3306 \
    MYSQL_DATABASE=banca_db \
    MYSQL_USER=banca_user \
    MYSQL_PASSWORD=banca_pass123

COPY --from=build /tmp/mysql-module/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar /tmp/
COPY --from=build /build/banca-ear/target/banca-nacional.ear /tmp/

USER root

RUN mkdir -p /opt/jboss/wildfly/modules/com/mysql/main && \
    mv /tmp/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar /opt/jboss/wildfly/modules/com/mysql/main/ && \
    echo '<?xml version="1.0" encoding="UTF-8"?>' > /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '<module xmlns="urn:jboss:module:1.3" name="com.mysql">' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '    <resources>' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '        <resource-root path="mysql-connector-java-'"${MYSQL_CONNECTOR_VERSION}"'.jar"/>' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '    </resources>' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '    <dependencies>' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '        <module name="javax.api"/>' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '        <module name="javax.transaction.api"/>' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '    </dependencies>' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml && \
    echo '</module>' >> /opt/jboss/wildfly/modules/com/mysql/main/module.xml

RUN /opt/jboss/wildfly/bin/add-user.sh -u "${WILDFLY_USER}" -p "${WILDFLY_PASSWORD}" --silent

RUN echo "embed-server --std-out=echo" > /tmp/configure-wildfly.cli && \
    echo "batch" >> /tmp/configure-wildfly.cli && \
    echo "/subsystem=datasources/jdbc-driver=mysql:add(driver-name=mysql,driver-module-name=com.mysql,driver-class-name=com.mysql.jdbc.Driver)" >> /tmp/configure-wildfly.cli && \
    echo "data-source add --name=BancaDS --jndi-name=java:jboss/datasources/BancaDS --driver-name=mysql --connection-url=jdbc:mysql://\${env.MYSQL_HOST}:\${env.MYSQL_PORT}/\${env.MYSQL_DATABASE}?useSSL=false --user-name=\${env.MYSQL_USER} --password=\${env.MYSQL_PASSWORD} --min-pool-size=5 --max-pool-size=20 --enabled=true" >> /tmp/configure-wildfly.cli && \
    echo "run-batch" >> /tmp/configure-wildfly.cli && \
    echo "stop-embedded-server" >> /tmp/configure-wildfly.cli && \
    /opt/jboss/wildfly/bin/jboss-cli.sh --file=/tmp/configure-wildfly.cli && \
    rm /tmp/configure-wildfly.cli

RUN mv /tmp/banca-nacional.ear /opt/jboss/wildfly/standalone/deployments/

RUN chown -R jboss:jboss /opt/jboss/wildfly/standalone/

USER jboss

EXPOSE 8080 9990

HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -sf http://localhost:8080/banca/login > /dev/null 2>&1 || exit 1

CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
