# 🏢 TechSolutions S.L. — Despliegue Seguro de Aplicación Web Corporativa

**Módulo:** Despliegue de APP  
**Ciclo:** Desarrollo de Aplicaciones Web (DAW)  
**Entorno de despliegue:** Docker sobre Ubuntu 22.04 LTS  

---

## Índice

1. [Introducción y Planificación](#1-introducción-y-planificación)
2. [Configuración de SSH Seguro](#2-configuración-de-ssh-seguro)
3. [Despliegue y Aseguramiento de Apache](#3-despliegue-y-aseguramiento-de-apache)
4. [Firewall y Protección Adicional](#4-firewall-y-protección-adicional)
5. [Pruebas de Funcionamiento y Seguridad](#5-pruebas-de-funcionamiento-y-seguridad)
6. [Conclusiones y Documentación](#6-conclusiones-y-documentación)

---

## 1. Introducción y Planificación

### 1.1 Contexto del proyecto

La empresa ficticia **TechSolutions S.L.** necesita desplegar un portal web interno para la gestión de proyectos de sus empleados.

Este proyecto aplica los conocimientos adquiridos en el módulo de Despliegue de APP, abarcando tres áreas fundamentales de la administración de sistemas:

- **Servidor web Apache** con soporte HTTPS
- **Acceso remoto seguro** mediante SSH
- **Medidas de seguridad** mediante firewall UFW

### 1.2 Decisión de entorno: Docker en lugar de VirtualBox

El enunciado propone el uso de una máquina virtual con VirtualBox. Sin embargo, por limitaciones de hardware en el equipo de trabajo, se ha optado por **Docker** como tecnología de virtualización alternativa.

> *UFW requiere el parámetro `--cap-add=NET_ADMIN` en Docker para tener permisos sobre el kernel de red.

Adicionalmente, el uso de Docker aporta una ventaja significativa: toda la infraestructura queda **codificada como código** (`Dockerfile` y `docker-compose.yml`), lo que permite reproducir el entorno completo con un único comando.

### 1.3 Arquitectura del sistema

```
                    NAVEGADOR / CLIENTE SSH
                           │
                    ┌──────▼──────┐
                    │  🛡️ FIREWALL │  UFW: solo puertos 22, 80, 443
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
         Puerto 80/443              Puerto 22
         🌐 APACHE                  🔐 SSH
              │                         │
    /var/www/techsolutions        Usuario: admin-tech
         index.html               Autenticación: clave pública
         /admin/ 🔒               Root: bloqueado
```

### 1.4 Estructura del repositorio

```
techsolutions/
├── 📄 README.md                      ← Este documento
├── 🐳 Dockerfile                     ← Construcción del servidor
├── 🐳 docker-compose.yml             ← Orquestación del entorno
├── 📜 start.sh                       ← Script de arranque de servicios
├── config/
│   ├── apache/
│   │   ├── techsolutions.conf        ← VirtualHost HTTP (redirección)
│   │   └── techsolutions-ssl.conf    ← VirtualHost HTTPS (principal)
│   └── ssh/
│       ├── sshd_config               ← Configuración SSH endurecida
│       └── authorized_keys           ← Clave pública del administrador
└── web/
    ├── index.html                    ← Portal principal
    └── admin/
        └── index.html                ← Panel de administración
```

### 1.5 Instrucciones de despliegue

**Requisitos previos:**
- Docker Desktop instalado y en ejecución
- Git instalado

**Clonar y desplegar:**

```bash
git clone https://github.com/Vilicaprogramer/techsolutions.git
cd techsolutions
docker-compose up --build
```

Una vez arrancado, los servicios estarán disponibles en:

| Servicio | URL / Comando |
|---|---|
| Portal web | `https://localhost` |
| Panel de administración | `https://localhost/admin` |
| Acceso SSH | `ssh -p 2222 admin-tech@localhost` |

---

## 2. Configuración de SSH Seguro

### 2.1 Generación del par de claves

Las claves se generan en el **ordenador del administrador** (nunca en el servidor):

```bash
ssh-keygen -t rsa -b 4096 -C "admin@techsolutions.local"
```

| Parámetro | Significado |
|---|---|
| `-t rsa` | Algoritmo RSA |
| `-b 4096` | Longitud de 4096 bits (más seguro que el estándar de 2048) |
| `-C` | Comentario identificativo |

Esto genera dos archivos:
- `~/.ssh/id_rsa` → Clave privada (proteger como si fuera una contraseña maestra)
- `~/.ssh/id_rsa.pub` → Clave pública (la que se copia al servidor)

### 2.2 Configuración SSH aplicada

El archivo `config/ssh/sshd_config` contiene la configuración del servidor SSH. Las directivas más relevantes desde el punto de vista de la seguridad son:

```bash
# Bloquear el acceso del usuario root
PermitRootLogin no

# Prohibir autenticación con contraseña
PasswordAuthentication no

# Habilitar autenticación con clave pública
PubkeyAuthentication yes

# Restringir el acceso a un único usuario
AllowUsers admin-tech

# Tiempo máximo para autenticarse (30 segundos)
LoginGraceTime 30

# Máximo de intentos fallidos por conexión
MaxAuthTries 3

# Deshabilitar reenvío de puertos (reducir superficie de ataque)
AllowTcpForwarding no
X11Forwarding no
```

### 2.3 Decisiones de seguridad justificadas

**¿Por qué bloquear root?**
El usuario `root` existe en todos los sistemas Linux con ese nombre exacto. Un atacante ya sabe que ese usuario existe, así que solo tiene que adivinar la contraseña. Bloquearlo obliga al atacante a adivinar también el nombre de usuario.

**¿Por qué `MaxAuthTries 3`?**
Limitar los intentos por conexión ralentiza significativamente los ataques automatizados. Cada nueva conexión tiene un coste de tiempo para el atacante.

**¿Por qué `LoginGraceTime 30`?**
Si alguien abre una conexión SSH pero no completa la autenticación en 30 segundos, la conexión se cierra automáticamente. Evita conexiones "zombi" que consuman recursos.

**¿Por qué `AllowTcpForwarding no`?**
El reenvío de puertos SSH puede usarse para crear túneles que salten el firewall. Desactivarlo limita lo que un atacante podría hacer si consiguiera acceso.

---

## 3. Despliegue y Aseguramiento de Apache

### 3.1 Generación del certificado autofirmado

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/apache2/ssl/techsolutions.key \
  -out    /etc/apache2/ssl/techsolutions.crt \
  -subj "/C=ES/ST=Madrid/L=Madrid/O=TechSolutions SL/CN=techsolutions.local"
```

| Parámetro | Significado |
|---|---|
| `-x509` | Formato estándar de certificado |
| `-nodes` | Sin contraseña en la clave (para que Apache arranque automáticamente) |
| `-days 365` | Válido durante un año |
| `-newkey rsa:2048` | Genera una nueva clave RSA de 2048 bits |

### 3.2 Configuración de los VirtualHosts

Apache usa el concepto de **VirtualHost** para poder servir diferentes sitios web desde el mismo servidor. En este proyecto se configuran dos:

**VirtualHost HTTP (puerto 80)** — `config/apache/techsolutions.conf`

Su única función es redirigir todo el tráfico HTTP hacia HTTPS. De este modo, aunque un usuario escriba `http://`, automáticamente llegará a la versión segura:

```apache
RewriteEngine On
RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
```

El código `301` indica al navegador que la redirección es permanente, y este la memoriza para futuros accesos.

**VirtualHost HTTPS (puerto 443)** — `config/apache/techsolutions-ssl.conf`

Es el VirtualHost principal. Además del cifrado SSL, incluye varias medidas de seguridad adicionales:

```apache
# Solo protocolos modernos (TLS 1.2 y 1.3)
# TLS 1.0 y 1.1 tienen vulnerabilidades conocidas
SSLProtocol -all +TLSv1.2 +TLSv1.3

# Evita el listado de archivos en directorios sin index
Options -Indexes

# Cabeceras de seguridad HTTP
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set Strict-Transport-Security "max-age=31536000"
```

### 3.4 Protección del panel de administración

El directorio `/admin` contiene información sensible y requiere una capa adicional de autenticación. Se implementa mediante **HTTP Basic Authentication**:

```apache
<Directory /var/www/techsolutions/admin>
    AuthType Basic
    AuthName "Zona Restringida - TechSolutions S.L."
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
</Directory>
```

Las credenciales se almacenan en el archivo `.htpasswd`, donde las contraseñas se guardan como **hash bcrypt**, no en texto plano:

```bash
htpasswd -cb /etc/apache2/.htpasswd admin techsolutions2025
# Resultado en .htpasswd:
# admin:$apr1$xyz...  ← contraseña hasheada, no recuperable
```

**Credenciales de acceso al panel:**
- Usuario: `admin`
- Contraseña: `techsolutions2025`

### 3.7 ¿Por qué `Options -Indexes`?

Sin esta directiva, si un usuario accede a una carpeta que no tiene archivo `index.html`, Apache muestra un listado de todos los archivos de esa carpeta. Esto puede exponer archivos de configuración, copias de seguridad o cualquier otro archivo sensible. Con `-Indexes`, Apache devuelve un error 403 (Prohibido) en su lugar.

---

## 4. Firewall y Protección Adicional

### 4.1 UFW: Uncomplicated Firewall

**UFW** es la herramienta de gestión de firewall de Ubuntu. Simplifica la configuración de `iptables`, que es el sistema de filtrado de paquetes del kernel Linux.

### 4.2 Principio de mínimo privilegio aplicado al firewall

La política configurada sigue el principio de **mínimo privilegio**: todo lo que no esté explícitamente permitido, está prohibido.

```bash
# Política base: bloquear todo el tráfico entrante
ufw default deny incoming

# Permitir todo el tráfico saliente (el servidor puede iniciar conexiones)
ufw default allow outgoing

# Excepciones: solo los puertos estrictamente necesarios
ufw allow 22/tcp    # SSH: administración remota
ufw allow 80/tcp    # HTTP: redirección a HTTPS
ufw allow 443/tcp   # HTTPS: portal web
```

### 4.3 ¿Por qué estos tres puertos?

**Puerto 22 (SSH):** Necesario para que los administradores puedan gestionar el servidor de forma remota. Sin este puerto, cualquier cambio requeriría acceso físico.

**Puerto 80 (HTTP):** Se mantiene abierto únicamente para redirigir a los usuarios hacia HTTPS. Si estuviera cerrado, los usuarios que escriban `http://` en lugar de `https://` no podrían llegar al servidor.

**Puerto 443 (HTTPS):** Es el puerto principal de la aplicación. Todo el tráfico real de la web pasa por aquí, cifrado.

Cualquier otro puerto (bases de datos, paneles de administración internos, APIs en desarrollo) queda bloqueado, reduciendo al mínimo la superficie de ataque.

### 4.5 Integración con Docker

En entornos Docker, UFW requiere permisos especiales sobre el kernel del sistema operativo anfitrión. Esto se configura en el `docker-compose.yml` mediante:

```yaml
cap_add:
  - NET_ADMIN   # Permite modificar reglas de red
  - NET_RAW     # Permite acceso a paquetes de red en bruto
```

Sin estos permisos, UFW devuelve un error de permisos al intentar modificar las tablas de `iptables`.

---

## 5. Pruebas de Funcionamiento y Seguridad

### 5.1 Prueba 1: Portal web accesible por HTTPS

**Acción:** Acceder a `https://localhost` desde el navegador.

**Resultado esperado:** El navegador muestra un aviso de certificado no confiable (esperado con certificados autofirmados). Al aceptar, se carga el portal de TechSolutions con el candado visible en la barra de direcciones.

**Verificación del candado:**

El icono de candado confirma que la comunicación entre el navegador y el servidor está cifrada mediante TLS. Haciendo clic en él se pueden ver los detalles del certificado autofirmado.

---

### 5.2 Prueba 2: Redirección HTTP → HTTPS

**Acción:** Acceder a `http://localhost` (sin S).

**Resultado esperado:** El navegador es redirigido automáticamente a `https://localhost`. El usuario nunca llega a usar la conexión no cifrada.

**Verificación con curl:**
```bash
curl -I http://localhost
# HTTP/1.1 301 Moved Permanently
# Location: https://localhost/
```

---

### 5.3 Prueba 3: Panel de administración protegido

**Acción:** Acceder a `https://localhost/admin`.

**Resultado esperado:** El navegador muestra un diálogo de autenticación solicitando usuario y contraseña.

- Con credenciales incorrectas → Error 401 (No autorizado)
- Con credenciales correctas (admin / techsolutions2025) → Acceso al panel

---

### 5.4 Prueba 4: Conexión SSH con clave pública

**Acción:**
```bash
ssh -p 2222 admin-tech@localhost
```

**Resultado esperado:** Conexión exitosa sin solicitar contraseña. El sistema operativo usa automáticamente la clave privada almacenada en `~/.ssh/id_rsa`.

```
admin-tech@techsolutions:~$
```

---

### 5.5 Prueba 5: Root bloqueado en SSH

**Acción:**
```bash
ssh -p 2222 root@localhost
```

**Resultado esperado:**
```
Permission denied (publickey).
```

El servidor rechaza la conexión del usuario root independientemente de si se usa clave o contraseña, tal como dicta la directiva `PermitRootLogin no`.

---

### 5.6 Prueba 6: Contraseñas bloqueadas en SSH

**Acción:**
```bash
ssh -p 2222 -o PreferredAuthentications=password admin-tech@localhost
```

**Resultado esperado:**
```
Permission denied (publickey).
```

El servidor rechaza explícitamente cualquier intento de autenticación por contraseña, tal como dicta `PasswordAuthentication no`.

---

### 5.7 Prueba 7: Firewall activo

**Acción (dentro del contenedor):**
```bash
ufw status verbose
```

**Resultado esperado:**
```
Status: active
Default: deny (incoming), allow (outgoing)

To          Action      From
--          ------      ----
22/tcp      ALLOW IN    Anywhere
80/tcp      ALLOW IN    Anywhere
443/tcp     ALLOW IN    Anywhere
```

---

### 5.8 Prueba 8: Listado de directorios bloqueado

**Acción:** Acceder a `https://localhost/admin/` (si no hubiera index.html).

**Resultado esperado:** Error 403 Forbidden. Apache no muestra el contenido del directorio gracias a `Options -Indexes`.

---

## 6. Conclusiones y Documentación

### 6.1 Resumen de medidas de seguridad implementadas

| Área | Medida | Amenaza que mitiga |
|---|---|---|
| SSH | Autenticación con clave pública | Ataques de fuerza bruta |
| SSH | `PermitRootLogin no` | Acceso directo como superusuario |
| SSH | `MaxAuthTries 3` | Ataques automatizados |
| SSH | `AllowUsers admin-tech` | Acceso de usuarios no autorizados |
| Apache | HTTPS con TLS 1.2/1.3 | Interceptación de comunicaciones |
| Apache | Redirección HTTP → HTTPS | Uso accidental de conexión no cifrada |
| Apache | `Options -Indexes` | Exposición de estructura de archivos |
| Apache | Autenticación básica en `/admin` | Acceso no autorizado al panel |
| Apache | Cabeceras de seguridad HTTP | Clickjacking, XSS, MIME sniffing |
| Firewall | `deny incoming` por defecto | Exposición de servicios innecesarios |
| Firewall | Solo puertos 22, 80 y 443 | Reducción de superficie de ataque |

### 6.2 Reflexión sobre el uso de Docker

La decisión de utilizar Docker en lugar de VirtualBox ha resultado ser una fortaleza del proyecto, no una limitación. La infraestructura como código garantiza que el entorno sea **100% reproducible**: cualquier persona que descargue el repositorio y ejecute `docker-compose up --build` obtendrá exactamente el mismo resultado, independientemente de su sistema operativo o configuración local.

### 6.3 Aprendizajes clave

Antes de hacer esta práctica, pensaba que la seguridad era algo que se configuraba al final, como un paso extra. Ahora entiendo que no funciona así: cada decisión que tomas al configurar un servidor tiene implicaciones de seguridad, desde elegir si permites contraseñas en SSH hasta decidir qué puertos deja pasar el firewall.

Lo que más me ha ayudado ha sido trabajar cada servicio por separado antes de juntarlo todo. Cuando intenté configurarlo todo a la vez al principio me perdía, pero al entender primero Apache, luego SSH y luego el firewall por separado, fui capaz de ver para qué sirve cada pieza y por qué está ahí. Creo que esa es la 
diferencia entre seguir unos pasos sin entenderlos y realmente aprender algo.

---

## Referencias

- [Documentación oficial de Apache HTTP Server](https://httpd.apache.org/docs/)
- [Manual de OpenSSH](https://www.openssh.com/manual.html)
- [Documentación de UFW en Ubuntu](https://help.ubuntu.com/community/UFW)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)

---

*Proyecto desarrollado como práctica del módulo de Despliegue de APP — DAW*
