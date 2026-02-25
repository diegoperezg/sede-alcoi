# Pràctica 3.1. Dimensionament dels servidors

**Data:** 25/02/2026

**Autors:**
- Aitor Brotons Fernández
- Pablo Vañó Nieto
- Victor Tamajón Pérez
- Diego Pérez Giménez
- Pedro Fernández Muñoz

---

## ÍNDEX DE CONTINGUTS

1. [Introducció i descripció de l'entorn](#1-introducció-i-descripció-de-lentorn)
2. [Maquinari disponible: Servidors físics](#2-maquinari-disponible-servidors-físics)
3. [Disseny i dimensionament dels servidors virtuals](#3-disseny-i-dimensionament-dels-servidors-virtuals)
   - [3.1 Servidor Empresarial Principal — Controlador de Domini (DC Primari)](#31-servidor-empresarial-principal--controlador-de-domini-dc-primari)
   - [3.2 Servidor Empresarial Secundari — Controlador de Domini (DC Secundari)](#32-servidor-empresarial-secundari--controlador-de-domini-dc-secundari)
   - [3.3 Servidor d'Aplicacions — RemoteApp (LibreOffice i GIMP)](#33-servidor-daplicacions--remoteapp-libreoffice-i-gimp)
   - [3.4 Servidor de Monitoratge — Zabbix](#34-servidor-de-monitoratge--zabbix)
   - [3.5 Servidor de Dades — Windows Server + iSCSI + DFS](#35-servidor-de-dades--windows-server--iscsi--dfs)
   - [3.6 Servidor Cabina de Discos — TrueNAS](#36-servidor-cabina-de-discos--truenas)
   - [3.7 Servidor Web Intranet / DMZ](#37-servidor-web-intranet--dmz)
   - [3.8 Servidor Web Estàtic Extern — AWS](#38-servidor-web-estàtic-extern--aws)
4. [Distribució dels servidors virtuals als servidors físics](#4-distribució-dels-servidors-virtuals-als-servidors-físics)
5. [Sistema de còpies de seguretat](#5-sistema-de-còpies-de-seguretat)
   - [5.1 Estratègia i Eines](#51-estratègia-i-eines)
   - [5.2 Planificació de Còpies](#52-planificació-de-còpies)
6. [Infraestructura de xarxa i DMZ](#6-infraestructura-de-xarxa-i-dmz)
7. [Consideracions sobre el SAI](#7-consideracions-sobre-el-sai)
8. [Apartat d'ampliació](#8-apartat-dampliació)

---

## 1. Introducció i descripció de l'entorn

L'entorn de producció real seria un conjunt de seus d'empresa, no obstant, com que no disposem físicament d'aquestes seus, la implementació es realitzarà en un entorn simulat al taller d'informàtica.

Per a la virtualització s'utilitzarà VirtualBox instal·lat sobre màquines GNU/Linux Debian 13 con entorno gráfico, daremos 3GB a la instalación. La infraestructura constarà de tres servidors físics que allotjaran els distints servidors virtuals, més un servidor enrackable dedicat a la DMZ.

Els objectius principals del projecte són:

- Configurar un domini Windows amb controladors de domini primari i secundari.
- Oferir aplicacions remotament mitjançant Windows RemoteApp (Libreoffice, GIMP).
- Centralitzar l'emmagatzemament mitjançant iSCSI i DFS.
- Monitoritzar tota la infraestructura amb Zabbix.
- Publicar un servidor web a la DMZ i un altre al núvol (AWS).
- Garantir la continuïtat del servei mitjançant còpies de seguretat locals i al núvol.

---

## 2. Maquinari disponible: Servidors físics

Disposem de tres servidors físics amb les característiques següents, més un servidor enrackable per a la DMZ:

| Servidor Físic | RAM | Disc NVMe | Discos SSD | Rol |
|---|---|---|---|---|
| SRV-FIS-01 | 16 GB | 256 GB | 2 x 128 GB | Servidors de Domini |
| SRV-FIS-02 | 16 GB | 256 GB | 2 x 128 GB | Aplicacions i Dades |
| SRV-FIS-03 | 16 GB | 256 GB | 2 x 128 GB | Monitoratge i Cabina |
| SRV-RACK-DMZ | Variable | Variable | - | Servidor DMZ (enrackable) |

---

## 3. Disseny i dimensionament dels servidors virtuals

A continuació es detallen tots els servidors virtuals que s'han de configurar, amb el seu dimensionament complet, sistema operatiu, recursos assignats, configuració de discos i targetes de xarxa.

### 3.1 Servidor Empresarial Principal — Controlador de Domini (DC Primari)

**SRV-DC01 — Windows Server 2025 (PDC + WDS + WSUS)**

| Camp | Valor |
|---|---|
| **Funcionalitat** | Controlador de Domini Principal (AD DS), DNS, DHCP, WDS (instal·lació per xarxa de SO clients Windows), WSUS (actualitzacions centralitzades) |
| **Sistema Operatiu** | Windows Server 2025 Standard amb experiència d'escriptori |
| **Nuclis vCPU** | 4 vCPUs |
| **RAM** | 6 GB |
| **Disc 1 (NVMe)** | Sistema Operatiu: 80 GB, NTFS, montat en `C:\` (unitat del sistema) |
| **Disc 2 (SSD RAID via LVM)** | `D:\` — 60 GB NTFS — Emmagatzemament WDS (ISOs via iSCSI des de la cabina) \| `E:\` — 30 GB NTFS — Repositori WSUS |
| **Targetes de Xarxa** | NIC1: Xarxa interna LAN (bridged/host-only al servidor físic) \| NIC2: Xarxa de gestió en adaptador pont |
| **Servidor físic** | SRV-FIS-01 |
| **Observacions** | Les ISOs necessàries per a WDS s'emmagatzemaran via iSCSI connectat a la cabina de discos (TrueNAS). Cal configurar el rol WDS i afegir les imatges de boot i instal·lació. WSUS descarregarà actualitzacions per als clients del domini. Formar part del grup de prioritat alta al SAI. |

---

### 3.2 Servidor Empresarial Secundari — Controlador de Domini (DC Secundari)

**SRV-DC02 — Windows Server 2025 Core (BDC)**

| Camp | Valor |
|---|---|
| **Funcionalitat** | Controlador de Domini Secundari (replica AD DS), DNS secundari. Sense entorn gràfic (Server Core). |
| **Sistema Operatiu** | Windows Server 2025 Standard Core (sense GUI) |
| **Nuclis vCPU** | 2 vCPUs |
| **RAM** | 3 GB |
| **Disc 1 (NVMe)** | Sistema Operatiu: 50 GB, NTFS, montat en `C:\` |
| **Disc 2 (SSD via LVM)** | `D:\` — 20 GB NTFS — Registres i logs del AD |
| **Targetes de Xarxa** | NIC1: Xarxa interna LAN \| NIC2: Xarxa de gestió |
| **Servidor físic** | SRV-FIS-03 |
| **Observacions** | S'administra remotament via PowerShell / RSAT des del DC01 o des dels clients. Promogut com a segon DC per garantir alta disponibilitat del domini. En cas de fallada del DC01, el DC02 assumeix el rol FSMO mitjançant seizing. |

---

### 3.3 Servidor d'Aplicacions — RemoteApp (LibreOffice i GIMP)

**SRV-APP01 — Windows Server 2025 (Remote Desktop Services)**

| Camp | Valor |
|---|---|
| **Funcionalitat** | Servidor de publicació d'aplicacions via Windows RemoteApp: LibreOffice Suite i GIMP. Accessible per a tots els usuaris del domini. |
| **Sistema Operatiu** | Windows Server 2025 Standard amb experiència d'escriptori |
| **Nuclis vCPU** | 4 vCPUs |
| **RAM** | 6 GB |
| **Disc 1 (NVMe)** | Sistema Operatiu + aplicacions: 100 GB, NTFS, montat en `C:\` |
| **Disc 2 (SSD via LVM)** | `D:\` — 30 GB NTFS — Perfils de sessió i dades temporals d'usuaris |
| **Targetes de Xarxa** | NIC1: Xarxa interna LAN |
| **Servidor físic** | SRV-FIS-02 |
| **Observacions** | Cal instal·lar el rol Remote Desktop Services (RDS) amb la llicència adequada. Les aplicacions RemoteApp (LibreOffice i GIMP) es publiquen des del Remote Desktop Web Access (RD Web). Els usuaris del domini accediran a les aplicacions des dels seus clients Windows sense necessitat d'instal·lació local. |

---

### 3.4 Servidor de Monitoratge — Zabbix

**SRV-MON01 — GNU/Linux Ubuntu Server 22.04 LTS (Zabbix)**

| Camp | Valor |
|---|---|
| **Funcionalitat** | Servidor de monitoratge centralitzat Zabbix. Supervisió de clients, servidors, dispositius MikroTik i Cisco, classificats per categories. |
| **Sistema Operatiu** | Ubuntu Server 22.04 LTS (GNU/Linux) |
| **Nuclis vCPU** | 2 vCPUs |
| **RAM** | 4 GB |
| **Disc 1 (NVMe)** | ext4, muntat en `/` — 40 GB (S.O. + Zabbix Server + base de dades MySQL) |
| **Disc 2 (SSD — Grup LVM)** | LVM VG: `vg-dades` \| LV `/var/lib/mysql` — 40 GB, ext4 (base de dades Zabbix) \| LV `/var/log` — 20 GB, ext4 (logs centralitzats) |
| **Targetes de Xarxa** | NIC1: Xarxa interna LAN \| NIC2: Xarxa de gestió |
| **Servidor físic** | SRV-FIS-03 |
| **Observacions** | Instal·lació de Zabbix Server + Zabbix Frontend (Apache + PHP) + MySQL. Configuració d'agents Zabbix en tots els servidors i clients. Monitoratge SNMP per a dispositius MikroTik i Cisco. Creació de grups d'hosts: Servidors, Clients, Xarxa. Alertes per email en cas d'incidents. |

---

### 3.5 Servidor de Dades — Windows Server + iSCSI + DFS

**SRV-DAD01 — Windows Server 2025 (File Server + DFS + iSCSI Initiator)**

| Camp | Valor |
|---|---|
| **Funcionalitat** | Servidor de fitxers centralitzat. Connecta via iSCSI a la cabina TrueNAS per obtenir espai d'emmagatzemament. Utilitza DFS (Distributed File System) per publicar tots els recursos compartits del domini. |
| **Sistema Operatiu** | Windows Server 2025 Standard amb experiència d'escriptori |
| **Nuclis vCPU** | 2 vCPUs |
| **RAM** | 4 GB |
| **Disc 1 (NVMe)** | Sistema Operatiu: 60 GB, NTFS, montat en `C:\` |
| **Disc 2 (iSCSI des de TrueNAS)** | `D:\` — 100 GB NTFS — Recursos compartits DFS (Departaments, Perfils, Dades) |
| **Targetes de Xarxa** | NIC1: Xarxa interna LAN (dades + iSCSI) \| NIC2: Xarxa de gestió |
| **Servidor físic** | SRV-FIS-02 |
| **Observacions** | El volum iSCSI es munta com a disc virtual des de la cabina TrueNAS. Cal activar el rol 'iSCSI Initiator' a Windows i configurar el target a TrueNAS. DFS Namespace i DFS Replication es configuren des d'aquest servidor i des del DC01. Les carpetes de departament seguiran el model de permisos AGDLP. |

---

### 3.6 Servidor Cabina de Discos — TrueNAS

**SRV-NAS01 — TrueNAS SCALE (Cabina de Discos simulada)**

| Camp | Valor |
|---|---|
| **Funcionalitat** | Simula una cabina de discos. Exporta espai d'emmagatzemament via iSCSI (per al servidor de dades i per a les ISOs de WDS). Pot exportar també per NFS/SMB si cal. |
| **Sistema Operatiu** | TrueNAS SCALE (basada en Debian GNU/Linux) |
| **Nuclis vCPU** | 2 vCPUs |
| **RAM** | 4 GB (recomanable 8 GB per ZFS) |
| **Disc 1 (NVMe)** | S.O. TrueNAS: 40 GB (el propi TrueNAS gestiona el pool de ZFS) |
| **Discos SSD (Pool ZFS)** | Disc SSD 1 i SSD 2 del servidor físic: configurats com a pool ZFS en mirall (RAID-1) per a alta disponibilitat. Total ~120 GB disponibles per a iSCSI. |
| **Targets iSCSI** | Target 1: ISOs-WDS (per a SRV-DC01) \| Target 2: Dades-DFS (per a SRV-DAD01) \| Target 3: Backup (per al sistema de còpies) |
| **Targetes de Xarxa** | NIC1: Xarxa interna LAN (iSCSI + gestió) |
| **Servidor físic** | SRV-FIS-03 |
| **Observacions** | TrueNAS utilitza ZFS com a sistema de fitxers, cosa que proporciona checksums d'integritat de dades, snapshots i eficiència en còpies. El pool ZFS en mirall garanteix que si falla un disc físic, les dades no es perden. Els snapshots ZFS seran part del sistema de còpies de seguretat. |

---

### 3.7 Servidor Web Intranet / DMZ

**SRV-WEB-DMZ — GNU/Linux Debian 13 (Apache/Nginx, servidor enrackable)**

| Camp | Valor |
|---|---|
| **Funcionalitat** | Servidor web per a la intranet corporativa. Allotjat a la DMZ. Accessible des de la xarxa interna i, parcialment, des d'Internet (portal web corporatiu). |
| **Sistema Operatiu** | Debian 13 Trixie (GNU/Linux) |
| **Nuclis vCPU** | 2 vCPUs |
| **RAM** | 2 GB |
| **Disc 1 (NVMe del servidor enrackable)** | ext4, muntat en `/` — 30 GB (S.O. + servidor web) \| LV `/var/www` — 20 GB, ext4 (contingut web) \| LV `/var/log` — 10 GB, ext4 (accessos i errors) |
| **Targetes de Xarxa** | NIC1: Xarxa DMZ (IP pública/semi-pública) \| NIC2: Xarxa interna (opcional, per accés intranet) |
| **Servidor físic** | Servidor enrackable dedicat (SRV-RACK-DMZ) |
| **Observacions** | Instal·lació d'Apache2 o Nginx. Certificat SSL auto-signat o Let's Encrypt per HTTPS. El firewall (MikroTik/pfSense) controla l'accés a la DMZ: des de l'exterior nomes port 80/443; des de l'interior, accés complet. Configuració de Virtual Hosts per publicar múltiples llocs si cal. |

---

### 3.8 Servidor Web Estàtic Extern — AWS

**SRV-WEB-AWS — Amazon EC2 (t2.micro / t3.micro) + S3 / CloudFront**

| Camp | Valor |
|---|---|
| **Funcionalitat** | Servidor web estàtic extern accessible des d'Internet. Allotjat al núvol AWS. Alternativament es pot usar AWS S3 + CloudFront per a pàgines estàtiques. |
| **Servei AWS** | Opció A: EC2 t2.micro (Ubuntu Server 22.04) \| Opció B: S3 Static Website + CloudFront (recomanada per a web estàtic) |
| **Sistema Operatiu** | Ubuntu Server 22.04 LTS (si EC2) o gestionat per AWS (si S3) |
| **vCPU / RAM** | EC2 t2.micro: 1 vCPU / 1 GB RAM (capa gratuïta AWS) |
| **Emmagatzemament** | EC2: 8 GB SSD (EBS gp2) \| S3: emmagatzemament objecte (paga per ús) |
| **Xarxa / Accés** | IP Elàstica (Elastic IP) si EC2 \| URL CloudFront si S3+CF \| Grup de Seguretat: port 22 (SSH), 80 (HTTP), 443 (HTTPS) |
| **Servidor físic** | Núvol AWS (Regió eu-west-1 / Europa) |
| **Observacions** | Per a una web estàtica corporativa, S3 + CloudFront és la solució més econòmica i escalable. Si es necessita backend (PHP, BD), llavors EC2. Cal configurar Route 53 per al DNS si es disposa de domini propi. Transferència de dades des de la infraestructura local a AWS via AWS CLI o rsync+SSH. |

---

## 4. Distribució dels servidors virtuals als servidors físics

La distribució s'ha realitzat tenint en compte el balanç de càrrega de RAM i CPU, la funcionalitat de cada servidor i la seva criticitat davant fallades:

| Servidor Virtual | S.O. | RAM | vCPU | Servidor Físic |
|---|---|---|---|---|
| SRV-DC01 (PDC) | Win Server 2025 | 6 GB | 4 | SRV-FIS-01 |
| SRV-DC02 (BDC Core) | Win Server 2025 Core | 3 GB | 2 | SRV-FIS-03 |
| SRV-APP01 (RemoteApp) | Win Server 2025 | 6 GB | 4 | SRV-FIS-02 |
| SRV-DAD01 (File+DFS) | Win Server 2025 | 4 GB | 2 | SRV-FIS-02 |
| SRV-MON01 (Zabbix) | Ubuntu Server 22.04 | 4 GB | 2 | SRV-FIS-03 |
| SRV-NAS01 (TrueNAS) | TrueNAS SCALE | 4 GB | 2 | SRV-FIS-03 |
| SRV-WEB-DMZ (Intranet) | Debian 13 | 2 GB | 2 | SRV-RACK-DMZ |
| SRV-WEB-AWS (Extern) | Ubuntu / AWS S3 | 1 GB | 1 | Amazon AWS |
| **TOTALS SRV-FIS-01** | | **6 GB RAM / 6 vCPU** | | Resta disponible: ~7 GB RAM |
| **TOTALS SRV-FIS-02** | | **10 GB RAM / 8 vCPU** | | Resta disponible: ~6 GB RAM |
| **TOTALS SRV-FIS-03** | | **11 GB RAM / 4 vCPU** | | Resta disponible: ~5 GB RAM |

> **Nota:** El S.O. host de cada servidor físic (Debian13 + VirtualBox) consumeix aproximadament 3 GB de RAM addicionals. La RAM reservada s'ha calculat amb marge per permetre l'ampliació futura.

---

## 5. Sistema de còpies de seguretat

El sistema de còpies de seguretat s'ha dissenyat amb una estratègia **3-2-1**: tres còpies de les dades, en dos suports o ubicacions diferents, una de les quals és fora del lloc (núvol AWS).

### 5.1 Estratègia i Eines

S'usarà una combinació d'eines per cobrir tots els escenaris:

- **Snapshots ZFS (TrueNAS):** còpies instantànies automàtiques dels volums iSCSI amb retenció configurable (diari, setmanal, mensual). Cost zero i recuperació ràpida.
- **Windows Server Backup:** per a les màquines virtuals Windows (SRV-DC01, SRV-DC02, SRV-APP01, SRV-DAD01). Còpies incrementals de les VMs al disc NAS.
- **rsync + cron:** per al servidor web DMZ i el servidor Zabbix. Còpia incremental de `/etc`, `/var/www`, `/var/lib/mysql` cap al servidor NAS.
- **AWS CLI + S3:** transferència de les còpies més crítiques (AD, DFS, DB Zabbix) cap a un bucket S3 a AWS. Xifrades amb AES-256. Transferència nocturna via script cron.

### 5.2 Planificació de Còpies

| Recurs | Eina | Freqüència | Destí Local | Destí AWS |
|---|---|---|---|---|
| AD (SRV-DC01/02) | Windows Server Backup | Diari (incremental) | NAS (iSCSI target Backup) | S3 (setmanal) |
| DFS / Fitxers (SRV-DAD01) | Windows Server Backup | Diari (incremental) | NAS (snapshot ZFS) | S3 (diari) |
| BD Zabbix (SRV-MON01) | rsync + mysqldump | Diari | NAS | S3 (setmanal) |
| Web DMZ (SRV-WEB-DMZ) | rsync | Setmanal | NAS | S3 (mensual) |
| Volums iSCSI (TrueNAS) | Snapshot ZFS auto | Horari / Diari | ZFS local (NAS) | No (massa gran) |

La recuperació de dades es provarà periòdicament (simulacre de restore) per verificar la integritat de les còpies. Es documentarà el procediment de recuperació (RTO < 4h, RPO < 24h).

---

## 6. Infraestructura de xarxa i DMZ

L'entorn disposarà de tres zones de xarxa clarament separades, controlades pel router/firewall (MikroTik o pfSense):

| Zona | Xarxa IP | Hostes principals |
|---|---|---|
| LAN Interna | 192.0.2.2/24 | SRV-DC01, DC02, APP01, DAD01, MON01, NAS01, Clients |
| DMZ | 192.0.2.3/24 | SRV-WEB-DMZ (enrackable) |
| Xarxa de Gestió | 192.0.2.4/24 | Accés SSH/RDP als servidors per als admins |
| AWS (Núvol) | IP pública / VPC AWS | SRV-WEB-AWS, Bucket S3 (còpies) |

Les regles del firewall permetran: des de LAN cap a DMZ (HTTP/HTTPS); des d'Internet cap a DMZ (80/443 only); bloqueig total de DMZ cap a LAN. El servidor Zabbix monitoritzarà tots els dispositius de totes les zones via agents i SNMP.

---

## 7. Consideracions sobre el SAI

El SAI (Sistema d'Alimentació Ininterrompuda) permetrà apagar ordenadament les màquines en cas de tall de llum prolongat. La prioritat d'apagada s'estableix de la següent manera:

| Prioritat | Servidor Virtual | Servidor Físic | Motiu |
|---|---|---|---|
| 1 (últim) | SRV-DC01 | SRV-FIS-01 | Controlador de domini: crítics |
| 2 | SRV-DAD01, SRV-NAS01, SRV-DC02 | SRV-FIS-02/03 | Dades i emmagatzemament. Controlador secundari |
| 3 | SRV-APP01, SRV-MON01, SRV-DC02 | SRV-FIS-02/03 | Aplicacions i monitoratge. Controlador secundari |
| 4 (primer) | SRV-WEB-DMZ | SRV-RACK-DMZ | Menys crític, apaga primer |

La configuració del SAI es farà via software NUT (Network UPS Tools) en GNU/Linux o via WinNUT/PowerChute en Windows, permetent la comunicació entre el SAI i els servidors per iniciar l'apagada segura automàticament.

---

## 8. Apartat d'ampliació

A continuació es proposen millores i ampliacions sobre l'enunciat obligatori que aporten valor afegit a la infraestructura:

### 8.1 Alta Disponibilitat i Balanceig de Càrrega

Es podria implementar un segon servidor web a la DMZ amb HAProxy o Nginx com a load balancer, garantint que si cau un node web, l'altre pren el relleu de forma transparent. Això simula un entorn de producció real de mitja-gran empresa.

### 8.2 VPN Accés Remot

Configuració d'una VPN (OpenVPN o WireGuard) al router MikroTik per permetre l'accés remot segur dels administradors de sistemes. Així es podria administrar tota la infraestructura des de casa o des de qualsevol lloc, simulant el treball en remot corporatiu.

### 8.3 SIEM i Centralització de Logs

Instal·lació d'un servidor ELK Stack (Elasticsearch + Logstash + Kibana) o Graylog per centralitzar tots els logs dels sistemes. Combinat amb Zabbix, permetria una visió completa de l'estat de seguretat i rendiment de la infraestructura.

### 8.4 Gestió d'Identitats (PKI Interna)

Configuració d'una autoritat de certificació interna (PKI) amb el rol AD CS (Active Directory Certificate Services) al DC01. Emetria certificats per a servidors web interns (HTTPS), per a autenticació de clients amb smart cards, i per a la VPN. Millora notable de la seguretat.

### 8.5 Automatització i IaC

Ús d'Ansible per automatitzar la configuració dels servidors GNU/Linux (Zabbix, Debian Web, TrueNAS) i PowerShell DSC per als servidors Windows. Permet reproduir la infraestructura de forma ràpida i documentada, seguint principis d'Infraestructura com a Codi (IaC).

### 8.6 Containerització (Docker)

Implementació del servidor Zabbix en contenidors Docker (Zabbix + MySQL + Nginx) en comptes d'instal·lació nativa. Facilita l'actualització, el backup i la migració del servei. Es podria complementar amb Portainer per a la gestió visual dels contenidors.
