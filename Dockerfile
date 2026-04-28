# ============================================
# DOCKERFILE - SERVIDOR TECHSOLUTIONS S.L.
# Base: Ubuntu Server 22.04 LTS
# ============================================

FROM ubuntu:22.04

# Evita preguntas interactivas durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# ============================================
# PASO 1 — Actualizar e instalar todo lo necesario
# ============================================
RUN apt-get update && apt-get install -y \
    apache2 \
    apache2-utils \
    openssl \
    openssh-server \
    ufw \
    nano \
    && apt-get clean

# ============================================
# PASO 2 — Configurar Apache
# ============================================

# Activar módulos necesarios
RUN a2enmod ssl rewrite headers

# Copiar los archivos de la web
COPY web/ /var/www/techsolutions/

# Copiar configuración de los VirtualHosts
COPY config/apache/techsolutions.conf     /etc/apache2/sites-available/
COPY config/apache/techsolutions-ssl.conf /etc/apache2/sites-available/

# Activar techsolutions y desactivar el sitio por defecto
RUN a2ensite techsolutions.conf techsolutions-ssl.conf && \
    a2dissite 000-default.conf

# ============================================
# PASO 3 — Generar certificado SSL autofirmado
# ============================================
RUN mkdir -p /etc/apache2/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/apache2/ssl/techsolutions.key \
    -out    /etc/apache2/ssl/techsolutions.crt \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=TechSolutions SL/CN=techsolutions.local"

# ============================================
# PASO 4 — Crear usuario admin del panel web
# ============================================
# Usuario: admin | Contraseña: techsolutions2025
RUN htpasswd -cb /etc/apache2/.htpasswd admin techsolutions2025

# ============================================
# PASO 5 — Configurar SSH seguro
# ============================================

# Crear el usuario administrador del sistema
RUN useradd -m -s /bin/bash admin-tech && \
    mkdir -p /home/admin-tech/.ssh && \
    chmod 700 /home/admin-tech/.ssh

# Copiar configuración SSH
COPY config/ssh/sshd_config /etc/ssh/sshd_config

# Copiar clave pública del administrador
COPY config/ssh/authorized_keys /home/admin-tech/.ssh/authorized_keys
RUN chmod 600 /home/admin-tech/.ssh/authorized_keys && \
    chown -R admin-tech:admin-tech /home/admin-tech/.ssh

# Generar las claves del servidor SSH
RUN ssh-keygen -A

# ============================================
# PASO 6 — Permisos correctos
# ============================================
RUN chown -R www-data:www-data /var/www/techsolutions && \
    chmod -R 755 /var/www/techsolutions

# ============================================
# PASO 7 — Script de arranque
# ============================================
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Puertos que expone el contenedor
EXPOSE 22 80 443

# Comando que se ejecuta al arrancar el contenedor
CMD ["/start.sh"]