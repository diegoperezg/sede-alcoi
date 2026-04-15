# Gestió d'Incidències — Seu Alcoi

**Autors:**
- Aitor Brotons Fernández
- Pablo Vañó Nieto
- Victor Tamajón Pérez
- Diego Pérez Giménez
- Pedro Fernández Muñoz

---

## ÍNDEX DE CONTINGUTS

1. [Introducció](#1-introducció)
2. [Classificació d'incidències](#2-classificació-dincidències)
3. [Fallada de disc dur en servidors físics](#3-fallada-de-disc-dur-en-servidors-físics)
4. [Fallada d'un servidor físic](#4-fallada-dun-servidor-físic)
5. [Fallada d'un servidor virtual](#5-fallada-dun-servidor-virtual)
6. [Fallada del router MikroTik](#6-fallada-del-router-mikrotik)
7. [Fallada d'un switch](#7-fallada-dun-switch)
8. [Tall de subministrament elèctric](#8-tall-de-subministrament-elèctric)
9. [Fallada de la cabina de discos (TrueNAS)](#9-fallada-de-la-cabina-de-discos-truenas)
10. [Fallada de la connectivitat amb AWS](#10-fallada-de-la-connectivitat-amb-aws)
11. [Monitoratge i detecció primerenca](#11-monitoratge-i-detecció-primerenca)
12. [Seguretat física del CPD](#12-seguretat-física-del-cpd)
13. [Taula resum d'incidències](#13-taula-resum-dincidències)

---

## 1. Introducció

Aquest document recull el **Pla de Recuperació front a Incidències** de la seu d'Alcoi. L'objectiu és establir les mesures preventives i els procediments d'actuació per a minimitzar l'impacte de possibles fallades en els components de la infraestructura: servidors, dispositius de xarxa, sistemes d'alimentació i elements físics del CPD.

Aquest pla **no contempla la política de còpies de seguretat**, la qual serà objecte d'una pràctica posterior. El focus és exclusivament la prevenció i contenció d'incidències.

---

## 2. Classificació d'incidències

Les incidències es classifiquen en tres nivells de gravetat:

| Nivell | Descripció | Exemples |
|--------|------------|---------|
| **Crític** | Afecta serveis essencials i no hi ha redundància activa | Fallada del PDC sense BDC operatiu, tall elèctric sense SAI |
| **Alt** | Afecta un servei important però existeix mecanisme de fallback | Fallada de SRV-DC01 amb SRV-DC02 disponible, fallada d'un disc en RAID |
| **Mig/Baix** | Afecta un servei no crític o el servei segueix disponible | Fallada del servidor web DMZ, problemes de monitoratge |

---

## 3. Fallada de disc dur en servidors físics

### Situació

Cada servidor físic (SRV-FIS-01, SRV-FIS-02, SRV-FIS-03) disposa d'un disc NVMe per al sistema operatiu host i dos discos SSD per a les màquines virtuals.

### Mesures preventives

- **RAID via LVM:** Els discos SSD de cada servidor físic estan configurats en un grup LVM que permet la gestió flexible dels volums. Es recomana configurar els SSD en **mirall (RAID-1)** via LVM (`--type mirror`) per als volums crítics on s'allotgen les VMs.
- **ZFS RAID-1 a TrueNAS (SRV-NAS01):** La cabina de discos utilitza ZFS en mirall sobre els dos discos SSD del SRV-FIS-03. Si un disc falla, ZFS continua operatiu amb l'altre disc i alerta automàticament.
- **Supervisió S.M.A.R.T.:** Activar la supervisió automàtica de salut dels discos via `smartd` en els servidors GNU/Linux i via el gestor de la controladora en Windows. Zabbix ha de recollir aquestes alertes.
- **Discos de recanvi:** Mantenir al CPD almenys un disc SSD i un NVMe de recanvi compatibles amb els servidors físics.

### Actuació davant la fallada

1. Zabbix genera alerta de disc degradat o fallida S.M.A.R.T.
2. L'administrador verifica l'estat del RAID/LVM (`mdadm --detail` o `lvm pvdisplay`).
3. Es substitueix el disc defectuós en calent si el xassís ho permet, o es planifica una finestra de manteniment.
4. Es reconstrueix el RAID/mirall amb el nou disc.

---

## 4. Fallada d'un servidor físic

### SRV-FIS-01 (allotja SRV-DC01 i SRV-DAD01)

| Servei afectat | Mesura de continuïtat |
|---|---|
| SRV-DC01 (PDC) | SRV-DC02 (BDC) al SRV-FIS-03 assumeix el rol de controlador de domini. Els clients segueixen autenticant-se al domini. |
| SRV-DAD01 (File Server / DFS) | Els recursos DFS queden inaccessibles fins a la restauració. Prioritat alta de recuperació. |

### SRV-FIS-02 (allotja SRV-APP01 i SRV-DAD01)

| Servei afectat | Mesura de continuïtat |
|---|---|
| SRV-APP01 (RemoteApp) | Les aplicacions RemoteApp (LibreOffice, GIMP) queden inoperatives. Els usuaris han d'usar instal·lacions locals temporalment. |
| SRV-DAD01 (File Server / DFS) | Igual que el cas anterior: prioritat alta de recuperació. |

### SRV-FIS-03 (allotja SRV-DC02, SRV-MON01, SRV-NAS01)

| Servei afectat | Mesura de continuïtat |
|---|---|
| SRV-DC02 (BDC) | El PDC (SRV-DC01) continua atenent l'autenticació del domini. |
| SRV-MON01 (Zabbix) | Es perd la monitorització. Verificar l'estat dels serveis manualment fins a la restauració. |
| SRV-NAS01 (TrueNAS) | Els volums iSCSI (dades DFS, ISOs WDS) queden inaccessibles. Impacte crític. |

### Mesures preventives generals

- Distribuir les VMs crítiques en parelles redundants entre servidors físics diferents (DC primari i secundari en hosts separats).
- Documentar el procediment de migració de VMs entre servidors físics (exportació/importació VirtualBox).
- Mantenir una imatge del S.O. host (Debian + VirtualBox) llesta per a reinstal·lació ràpida.
- Revisar periòdicament l'estat tèrmic i les alertes de maquinari via IPMI/iDRAC si el servidor ho permet.

---

## 5. Fallada d'un servidor virtual

### SRV-DC01 — Controlador de Domini Principal

- **Redundància:** SRV-DC02 actua com a BDC (Backup Domain Controller) i replica tots els objectes de l'Active Directory. En cas de fallada del DC01, els clients segueixen autenticant-se mitjançant el DC02.
- **Transferència de rols FSMO:** Si la fallada del DC01 és prolongada, cal fer un **seizing** dels rols FSMO al DC02 via PowerShell (`Move-ADDirectoryServerOperationMasterRole`).
- **Prevenció:** Mantenir la replicació AD monitoritzada (Zabbix + event logs). Verificar periòdicament amb `repadmin /showrepl`.

### SRV-DC02 — Controlador de Domini Secundari

- Si cau el DC02, el DC01 segueix atenent tot el servei de domini sense interrupció.
- Restaurar el DC02 al seu servidor físic assignat (SRV-FIS-03) amb prioritat moderada.

### SRV-APP01 — Servidor d'Aplicacions RemoteApp

- No hi ha servidor de RemoteApp redundant. En cas de fallada, els usuaris han d'usar instal·lacions locals de LibreOffice i GIMP.
- Documentar el procés de reinici de la VM i dels rols RDS per a una recuperació ràpida.

### SRV-DAD01 — Servidor de Fitxers / DFS

- La fallada d'aquest servidor interromp l'accés als recursos compartits del domini.
- Prevenció: el volum de dades resideix en la cabina TrueNAS via iSCSI, de manera que les dades en si estan protegides per ZFS RAID-1 al NAS. La recuperació consisteix a tornar a activar la VM i reconnectar el target iSCSI.

### SRV-MON01 — Zabbix

- La fallada del servidor de monitoratge no afecta la producció, però deixa l'equip d'IT sense visibilitat.
- Restaurar amb prioritat moderada. Mentre no estigui operatiu, revisar l'estat dels servidors manualment o via scripts de verificació.

### SRV-NAS01 — TrueNAS (Cabina de Discos)

- **Impacte crític:** sense el NAS, el servidor de fitxers (SRV-DAD01) perd el seu volum de dades iSCSI i el DC01 perd les ISOs de WDS.
- ZFS RAID-1 protegeix les dades davant la fallada d'un disc, però no davant la fallada de la VM sencera.
- Prevenció: supervisar l'estat del pool ZFS via Zabbix (plugin TrueNAS/SNMP). Activar alertes per estat `DEGRADED` o `FAULTED`.

### SRV-WEB-DMZ — Servidor Web Intranet

- Servei de baixa criticitat interna. La fallada no afecta les operacions del domini ni els fitxers.
- Reiniciar la VM o el servei Apache/Nginx. El MikroTik continuarà aplicant les regles de firewall de la DMZ.

---

## 6. Fallada del router MikroTik

El MikroTik és el **punt central de routing, NAT i firewall** de la seu. La seva fallada implica la pèrdua total de connectivitat entre segments de xarxa i amb Internet.

### Mesures preventives

- **Exportació de la configuració:** exportar i guardar regularment la configuració completa del MikroTik (`/export file=backup-mikrotik`) en un directori accessible des de la xarxa interna i localment.
- **Dispositiu de recanvi:** tenir disponible un segon MikroTik (o un router configurable equivalent) amb la configuració exportada llesta per a ser importada (`/import file=backup-mikrotik`).
- **Supervisió SNMP:** Zabbix monitoritza el MikroTik via SNMP. Alerta automàtica si el dispositiu deixa de respondre.
- **Accés de gestió local:** en cas de pèrdua de connectivitat remota, accedir físicament al MikroTik via cable sèrie (Winbox o terminal) per diagnosticar la fallada.

### Actuació davant la fallada

1. Verificar que la fallada és del MikroTik i no del proveïdor ISP.
2. Intentar accés per Winbox o consola sèrie per reiniciar o diagnosticar.
3. Si el maquinari ha fallat, substituir pel dispositiu de recanvi i importar la última configuració exportada.
4. Verificar les regles de firewall i les rutes estàtiques/dinàmiques després de la restauració.

---

## 7. Fallada d'un switch

### Switch Cisco 48 ports (commutació servidors i administració)

- **Impacte alt:** connecta tots els servidors virtuals i els departaments d'Informàtica i Administració.
- Prevenció: exportar la configuració (`copy running-config tftp://...` o a la memòria flash local). Disposar d'un switch de recanvi amb capacitat equivalent o configuració bàsica operativa.
- En cas de fallada parcial (un port), redirigir el cable a un port lliure del switch. El Cisco 48 disposa de ports de reserva suficients.

### Switch TP-Link 8 ports (nucli d'agregació)

- És el punt d'interconnexió entre el MikroTik, el Cisco i el TP-Link 16 ports.
- Prevenció: disposar d'un switch de recanvi (qualsevol switch no gestionable de 8+ ports serveix com a substitució temporal per mantenir la connectivitat).

### Switch TP-Link 16 ports (departaments perifèrics)

- Connecta els departaments de Vigilància, Comercial, Producció i Emmagatzemament.
- La seva fallada aïlla aquests departaments però no afecta els servidors ni Administració/IT.
- Prevenció: disposar d'un switch de recanvi o redirigir temporalment als ports del Cisco disponibles.

### Switch D-Link (SAN / xarxa de fibra per iSCSI)

- Connecta exclusivament SRV-DC01 i SRV-DAD01 amb la cabina TrueNAS via iSCSI (xarxa SAN).
- La seva fallada interromp l'accés iSCSI als volums de dades: **impacte crític** per al DFS i les ISOs WDS.
- Prevenció: guardar la configuració del D-Link. Disposar d'un switch de recanvi compatible o redirigir el tràfic iSCSI temporalment per la LAN principal (degradació de rendiment però manteniment del servei).

---

## 8. Tall de subministrament elèctric

### Sistema d'Alimentació Ininterrompuda (SAI)

El CPD disposa d'un SAI que protegeix els tres servidors físics, el servidor DMZ i els dispositius de xarxa. En cas de tall elèctric:

- El SAI entra en funcionament de forma automàtica i subministra energia als dispositius connectats.
- El software **NUT (Network UPS Tools)** en els servidors GNU/Linux i **WinNUT/PowerChute** en Windows rep les senyals del SAI i inicia l'**apagada ordenada** quan la bateria arriba al llindar crític.

### Ordre d'apagada davant tall perllongat

| Ordre | Servidor Físic | VMs allotjades | Raó |
|-------|----------------|----------------|-----|
| 1r (primer en apagar-se) | SRV-FIS-02 | SRV-APP01, SRV-DAD01 | Serveis no crítics per a l'autenticació |
| 2n | SRV-FIS-03 | SRV-DC02, SRV-MON01, SRV-NAS01 | NAS s'apaga un cop el DAD01 ja ho ha fet |
| 3r (últim) | SRV-FIS-01 | SRV-DC01 | PDC: últim en apagar-se per assegurar el domini fins al final |

El servidor DMZ (SRV-RACK-DMZ) s'apaga en primer lloc per ser el menys crític.

### Mesures preventives addicionals

- Revisar periòdicament l'estat de la bateria del SAI i fer proves de descàrrega controlada.
- Assegurar que tots els servidors estan connectats al SAI (no directament a la xarxa elèctrica).
- Configurar el NUT en mode **master/slave**: un servidor GNU/Linux actua com a master NUT i envia senyals d'apagada als esclaus (la resta de servidors i Windows via client NUT).
- Disposar d'un generador elèctric o d'un SAI secundari si es preveu un tall de llarga durada.

---

## 9. Fallada de la cabina de discos (TrueNAS)

TrueNAS (SRV-NAS01) és un component crític ja que exporta els volums iSCSI al servidor de fitxers i les ISOs al DC01.

### Mesures preventives

- **ZFS RAID-1 (mirall):** els dos discos SSD del SRV-FIS-03 formen un pool ZFS en mirall. La fallada d'un disc no interromp el servei; ZFS continua operatiu amb l'altre disc.
- **Alertes ZFS:** configurar Zabbix per rebre notificacions de l'estat del pool ZFS via SNMP o script extern (`zpool status`). Alertar davant qualsevol estat diferent de `ONLINE`.
- **Supervisió dels targets iSCSI:** Zabbix ha de verificar que els targets iSCSI estan accessibles des de SRV-DC01 i SRV-DAD01 (monitoratge de l'estat de la connexió iSCSI al client Windows).
- **Disc SSD de recanvi:** mantenir un disc de recanvi compatible al CPD per a la substitució immediata en cas de fallada d'un dels discos del pool.

### Actuació davant la degradació del pool ZFS

1. Zabbix genera alerta `ZFS POOL DEGRADED`.
2. L'administrador identifica el disc fallat amb `zpool status`.
3. Es substitueix el disc en calent (si TrueNAS ho permet) i s'inicia el **resilver** (reconstrucció del mirall).
4. Verificar que el resilver s'ha completat correctament (`zpool status` → `ONLINE`).

---

## 10. Fallada de la connectivitat amb AWS

El servidor web extern (SRV-WEB-AWS) i el bucket S3 de còpies estan allotjats a AWS (regió eu-west-1).

### Mesures preventives

- **Monitoratge de disponibilitat:** Zabbix (o un monitor extern) ha de verificar periòdicament que el servei web AWS respon (HTTP check).
- **DNS alternatiu:** si el servidor web AWS cau, el servidor web DMZ pot servir com a punt d'accés temporal a la intranet corporativa.
- **Credencials AWS documentades:** guardar les credencials IAM i la configuració de l'AWS CLI en un lloc segur i accessible per a l'administrador, per permetre la gestió de les instàncies EC2/S3 en cas d'incident.
- **Límit de costos AWS:** configurar alertes de facturació a AWS per detectar un ús anòmal que pugui indicar un incident de seguretat o una configuració incorrecta.

---

## 11. Monitoratge i detecció primerenca

El servidor Zabbix (SRV-MON01) és la peça clau per a la detecció primerenca de qualsevol incidència. Ha d'estar configurat per supervisar:

| Element supervisat | Mètode | Alerta |
|---|---|---|
| Servidors físics i VMs (CPU, RAM, disc, xarxa) | Agent Zabbix | > 85% ús sostingut |
| Estat dels serveis (AD, DNS, DHCP, iSCSI, Apache) | Zabbix agent / check TCP | Servei inactiu |
| Dispositius de xarxa (MikroTik, Cisco, TP-Link, D-Link) | SNMP v2c | Dispositiu no accessible |
| Salut dels discos S.M.A.R.T. | Script / agent | Errors S.M.A.R.T. detectats |
| Estat del pool ZFS (TrueNAS) | SNMP / script SSH | Pool diferent de `ONLINE` |
| Temperatura del CPD (si hi ha sonda) | SNMP / sensor | > 28 °C |
| SAI (nivell de bateria, estat) | NUT + Zabbix | Bateria < 30% o SAI en bateria |
| Disponibilitat web AWS | HTTP check extern | Codi resposta ≠ 200 |

Les alertes s'enviaran per **correu electrònic** a l'administrador de sistemes. Per a incidències crítiques es pot configurar també notificació per Telegram o SMS via script.

---

## 12. Seguretat física del CPD

La prevenció d'incidències no es limita al programari; la seguretat física del CPD és igualment important:

- **Accés restringit:** el CPD ha de tenir accés limitat al personal autoritzat (clau, tarja o codi). Registrar els accessos.
- **Control de temperatura i humitat:** mantenir la temperatura entre 18 °C i 27 °C i la humitat relativa entre 40% i 60%. Instal·lar climatització adequada i una sonda de temperatura supervisada per Zabbix.
- **Protecció contra incendis:** disposar d'extintors de CO₂ o gas inert (mai aigua o pols) en el CPD. Considerar un sistema de detecció de fum.
- **Etiquetatge del cablejat:** tots els cables de xarxa i alimentació han d'estar etiquetats correctament per facilitar la identificació ràpida en cas d'incidència.
- **Ordre i gestió del cablejat:** usar braços portacables i brides per evitar que un cable mal connectat provoqui una fallada per accident.
- **Documentació actualitzada:** mantenir el diagrama de xarxa, la distribució del rack i les configuracions dels dispositius sempre actualitzats i accessibles.

---

## 13. Taula resum d'incidències

| Incidència | Nivell | Mesura preventiva principal | Servei afectat |
|---|---|---|---|
| Fallada disc SSD servidor físic | Alt | RAID-1 LVM / ZFS RAID-1 | VMs del servidor afectat |
| Fallada servidor físic SRV-FIS-01 | Crític | DC02 assumeix el domini | Domini (DC01), Fitxers (DAD01) |
| Fallada servidor físic SRV-FIS-02 | Alt | DC01 operatiu, DC02 operatiu | RemoteApp (APP01) |
| Fallada servidor físic SRV-FIS-03 | Alt | DC01 operatiu | Monitoratge, NAS, DC02 |
| Fallada SRV-DC01 | Alt | DC02 pren el relleu (BDC → FSMO seizing) | Autenticació domini |
| Fallada SRV-NAS01 | Crític | ZFS RAID-1, disc de recanvi | iSCSI (DFS + ISOs WDS) |
| Fallada MikroTik | Crític | Dispositiu de recanvi + config exportada | Conectivitat total |
| Fallada Switch Cisco | Alt | Switch de recanvi + config exportada | Servidors i IT/Admin |
| Fallada Switch D-Link SAN | Crític | Switch de recanvi o redirecció per LAN | Accés iSCSI |
| Tall elèctric | Alt → Crític | SAI + NUT + apagada ordenada | Tots els serveis |
| Sobrecalentament CPD | Crític | Climatització + sonda Zabbix | Tots els serveis |
| Fallada SRV-WEB-DMZ | Baix | Reinici VM / servei Apache/Nginx | Portal web intranet |
| Fallada SRV-WEB-AWS | Mig | DMZ com a fallback, alertes AWS | Portal web extern |
