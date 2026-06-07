# =============================================================================
# Wildfly + SSH - Docker Image
# =============================================================================
# Proposito: Imagen de Wildfly con servidor SSH integrado para despliegue
#            automatizado via pipelines CI/CD (SCP + SSH).
#
# Puertos expuestos:
#   22   - SSH (mapeable via WILDFLY_SSH_PORT)
#   8080 - HTTP (Wildfly)
#   9990 - Admin (Wildfly Management)
#
# Variables de build:
#   WILDFLY_VERSION  - Version de Wildfly (default: 26.1.2.Final)
#   DEPLOY_USER      - Usuario para despliegues SSH (default: deploy)
#   DEPLOY_PASSWORD  - Password del usuario (default: deploy)
#
# Build:
#   docker build -t wildfly-ssh:26.1.2.Final \
#     --build-arg WILDFLY_VERSION=26.1.2.Final \
#     -f infra/docker/wildfly/Dockerfile .
# =============================================================================

ARG WILDFLY_VERSION=26.1.2.Final
FROM quay.io/wildfly/wildfly:${WILDFLY_VERSION}

ARG WILDFLY_VERSION=26.1.2.Final
ARG DEPLOY_USER=deploy
ARG DEPLOY_PASSWORD=deploy

LABEL maintainer="Factoria Bancapersonas"
LABEL description="Wildfly ${WILDFLY_VERSION} con SSH para despliegue automatizado"
LABEL version="${WILDFLY_VERSION}"
LABEL wildfly.version="${WILDFLY_VERSION}"
LABEL jdk.version="11"

# =============================================================================
# 1. Instalar OpenSSH Server y utilidades
# =============================================================================
USER root

# CentOS 7 base — repos EOL migrados a vault.centos.org
RUN sed -i 's|mirror.centos.org|vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|^#baseurl|baseurl|' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|^mirrorlist|#mirrorlist|' /etc/yum.repos.d/CentOS-*.repo && \
    yum install -y \
        openssh-server \
        openssh-clients \
        sudo \
        passwd \
        procps-ng \
        curl \
        iproute \
        && yum clean all

# =============================================================================
# 2. Configurar SSH
# =============================================================================
RUN mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    \
    # Configurar SSHD para key-based auth rapida (sin DNS/GSSAPI)
    sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
    sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config && \
    sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/' /etc/ssh/sshd_config && \
    \
    # Generar host keys
    ssh-keygen -A

# =============================================================================
# 3. Crear usuario deploy para CI/CD
# =============================================================================
RUN useradd -m -s /bin/bash -d /home/${DEPLOY_USER} ${DEPLOY_USER} && \
    echo "${DEPLOY_USER}:${DEPLOY_PASSWORD}" | chpasswd && \
    mkdir -p /home/${DEPLOY_USER}/.ssh && \
    chmod 700 /home/${DEPLOY_USER}/.ssh && \
    touch /home/${DEPLOY_USER}/.ssh/authorized_keys && \
    chmod 600 /home/${DEPLOY_USER}/.ssh/authorized_keys && \
    chown -R ${DEPLOY_USER}:${DEPLOY_USER} /home/${DEPLOY_USER}/.ssh && \
    \
    # Acceso sudo sin password para systemctl/ service
    echo "${DEPLOY_USER} ALL=(ALL) NOPASSWD: /usr/sbin/sshd, /usr/bin/systemctl, /usr/sbin/service" >> /etc/sudoers && \
    \
    # Permitir SSH password-based para setup inicial (deshabilitar en produccion)
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# =============================================================================
# 4. Configurar Wildfly para modo standalone y deployments
# =============================================================================
ENV WILDFLY_HOME=/opt/jboss/wildfly
ENV DEPLOYMENTS_DIR=${WILDFLY_HOME}/standalone/deployments
ENV JBOSS_HOME=${WILDFLY_HOME}

# Crear usuario admin para Wildfly Management Console
RUN ${WILDFLY_HOME}/bin/add-user.sh admin admin --silent && \
    ${WILDFLY_HOME}/bin/add-user.sh -a ${DEPLOY_USER} ${DEPLOY_PASSWORD} --silent

# Asegurar permisos para el usuario deploy
RUN chown -R jboss:jboss ${WILDFLY_HOME} && \
    usermod -aG jboss ${DEPLOY_USER} && \
    chmod -R g+w ${DEPLOYMENTS_DIR}

# =============================================================================
# 5. Entrypoint: inicia SSH y Wildfly
# =============================================================================
COPY --chown=jboss:jboss infra/docker/wildfly/entrypoint.sh /opt/jboss/entrypoint.sh
RUN chmod +x /opt/jboss/entrypoint.sh

EXPOSE 22 8080 9990

# Entrypoint se ejecuta como root para iniciar sshd, luego baja a jboss
USER root
ENTRYPOINT ["/opt/jboss/entrypoint.sh"]
CMD ["-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
