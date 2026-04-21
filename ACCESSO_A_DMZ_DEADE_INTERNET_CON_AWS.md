# Configuració de Reverse Proxy amb AWS EC2 — Seu Alcoi

---

## Índex de continguts

1. [Introducció](#1-introducció)
2. [Arquitectura del flux de dades](#2-arquitectura-del-flux-de-dades)
3. [Configuració de la instància EC2 (AWS)](#3-configuració-de-la-instància-ec2-aws)
4. [Configuració del túnel invers des de la LAN](#4-configuració-del-túnel-invers-des-de-la-lan)
5. [Configuració del Reverse Proxy (Nginx)](#5-configuració-del-reverse-proxy-nginx)
6. [Automatització i persistència amb Autossh](#6-automatització-i-persistència-amb-autossh)
7. [Seguretat i Certificats SSL](#7-seguretat-i-certificats-ssl)
8. [Monitoratge de la connectivitat](#8-monitoratge-de-la-connectivitat)
9. [Taula resum de configuració](#9-taula-resum-de-configuració)

---

## 1. Introducció

Aquest document detalla el procediment per a establir un Reverse Proxy en una instància EC2 d'AWS que permeti l'accés extern a serveis allotjats en la LAN de la seu d'Alcoi. Aquesta solució és ideal per a entorns amb CGNAT o restriccions de firewall en el router local, utilitzant un túnel SSH invers com a pont segur.

---

## 2. Arquitectura del flux de dades

El tràfic segueix una ruta estructurada per garantir que el servidor local no estigui exposat directament a Internet:

1. El client extern realitza una petició a la IP pública (elàstica) de la EC2.
2. Nginx (a la EC2) rep la petició i la redirigeix al port local del túnel.
3. El túnel SSH invers transporta la petició des de la EC2 fins al servidor de la LAN.
4. El servidor local processa la petició i retorna la resposta pel mateix camí.

---

## 3. Configuració de la instància EC2 (AWS)

### Mesures preventives en AWS

**Security Group:** Cal configurar les regles d'entrada (Inbound rules) per permetre el tràfic:

| Protocol | Port | Origen |
|----------|------|--------|
| HTTP | 80 | 0.0.0.0/0 |
| HTTPS | 443 | 0.0.0.0/0 |
| SSH | 22 | IP de l'administrador |

**Habilitar Gateway Ports:** Per defecte, SSH només permet túnels locals. Cal editar la configuració del servei a la instància:

```bash
sudo nano /etc/ssh/sshd_config
```

Modificar o afegir la línia:

```
GatewayPorts yes
```

Reiniciar el servei:

```bash
sudo systemctl restart ssh
```

---

## 4. Configuració del túnel invers des de la LAN

### Execució del túnel

Des del servidor de la LAN (per exemple, `SRV-WEB-DMZ` o `SRV-FIS-01`), s'ha d'obrir el túnel cap a AWS:

```bash
ssh -i "clau-seu-alcoi.pem" -N -R 8080:localhost:80 ec2-user@IP-PUBLICA-EC2
```

- `-R 8080:localhost:80`: Indica que el port 8080 de la EC2 es redirigirà al port 80 del servidor local.
- `-N`: No executa cap terminal remot, només manté el túnel.

---

## 5. Configuració del Reverse Proxy (Nginx)

Per tal d'evitar l'ús de ports no estàndards (com el 8080) i gestionar el tràfic HTTPS, s'utilitza Nginx a la EC2.

### Configuració del lloc

Crear el fitxer `/etc/nginx/conf.d/reverse-proxy.conf`:

```nginx
server {
    listen 80;
    server_name IP-PUBLICA-EC2;

    # Redirigir tot el tràfic HTTP a HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name IP-PUBLICA-EC2;

    ssl_certificate /etc/ssl/certs/selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/selfsigned.key;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

> **Nota:** Substitueix `IP-PUBLICA-EC2` per la IP elàstica real de la teva instància.

Verificar la configuració i reiniciar Nginx:

```bash
sudo nginx -t
sudo systemctl restart nginx
```

---

## 6. Automatització i persistència amb Autossh

### Situació

Un túnel SSH simple pot tallar-se per inactivitat o microtalls de xarxa. Per garantir la continuïtat del servei (Nivell Crític), s'ha d'utilitzar `autossh` al servidor local.

### Instal·lació i configuració

```bash
sudo apt install autossh

autossh -M 0 -f -N -i "clau.pem" \
  -o "ServerAliveInterval 30" \
  -o "ServerAliveCountMax 3" \
  -R 8080:localhost:80 ec2-user@IP-PUBLICA-EC2
```

---

## 7. Seguretat i Certificats SSL (Self-Signed)

És imprescindible xifrar la comunicació entre l'usuari i la EC2. Com que no es disposa d'un domini registrat, s'utilitzaran certificats autofirmats (self-signed).

### Generació del certificat

A la instància EC2, executar:

```bash
sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/selfsigned.key \
  -out /etc/ssl/certs/selfsigned.crt \
  -subj "/C=ES/ST=Valencia/L=Alcoi/O=SeuAlcoi/CN=IP-PUBLICA-EC2"
```

- `-days 365`: El certificat serà vàlid durant un any. Caldrà renovar-lo abans de la caducitat.
- `-subj`: Substitueix `IP-PUBLICA-EC2` per la IP elàstica real de la instància.

### Protegir la clau privada

```bash
sudo chmod 600 /etc/ssl/private/selfsigned.key
```

### Consideracions importants

- **Avís del navegador:** Els certificats autofirmats no estan signats per una CA de confiança, de manera que els navegadors mostraran un avís de seguretat. Els usuaris hauran d'acceptar l'excepció manualment.
- **Renovació:** Recordar regenerar el certificat abans que caduqui (365 dies).
- **Migració futura:** Si en algun moment s'adquireix un domini, es pot substituir fàcilment per un certificat de Let's Encrypt amb `certbot --nginx`.

**Resultat:** El tràfic anirà xifrat per HTTPS (self-signed) fins a AWS, i des d'allà viatjarà pel túnel SSH (també xifrat) fins a la seu d'Alcoi.

---

## 8. Monitoratge de la connectivitat

El servidor `SRV-MON01` (Zabbix) ha d'integrar aquest nou flux:

| Element | Mètode | Alerta |
|---------|--------|--------|
| Disponibilitat EC2 | ICMP Ping | Instància AWS caiguda |
| Estat Túnel SSH | Check TCP port 8080 (a EC2) | Túnel desconnectat |
| Servei Web Extern | HTTP Check (Port 443) | Error de certificat (self-signed) o servei 502 |

---

## 9. Taula resum de configuració

| Component | Configuració Clau | Funció |
|-----------|-------------------|--------|
| EC2 AWS | `GatewayPorts yes` | Permet el tràfic extern pel túnel |
| Nginx (EC2) | Proxy Pass a port 8080 + SSL self-signed | Gestiona HTTPS i reverse proxy |
| Autossh (LAN) | `ServerAliveInterval 30` | Manté la connexió permanent |
| Security Group | Port 80, 443 oberts | Permet accés web des d'Internet |
