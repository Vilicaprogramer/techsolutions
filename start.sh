#!/bin/bash
# ============================================
# SCRIPT DE ARRANQUE - TECHSOLUTIONS S.L.
# ============================================

echo "🚀 Arrancando servicios de TechSolutions S.L..."

# Arrancar Apache
echo "🌐 Iniciando Apache..."
service apache2 start

# Arrancar SSH
echo "🔐 Iniciando SSH..."
service ssh start

# Configurar Firewall
echo "🛡️ Configurando Firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

echo "✅ Todos los servicios arrancados correctamente"
echo "🌐 Web disponible en https://localhost"
echo "🔐 SSH disponible en puerto 2222"

# Mantener el contenedor vivo
tail -f /dev/null