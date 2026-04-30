# POLÍTICA DE COPIAS DE SEGURIDAD

**Sede Alcoi — Infraestructura Corporativa Virtualizada**

Versión 1.0 | Fecha: 30 de abril de 2026 | Clasificación: CONFIDENCIAL — Uso interno

---

## 1. Introducción

El presente documento establece la política de copias de seguridad para la infraestructura corporativa virtualizada de la Sede Alcoi, compuesta por aproximadamente 50 empleados distribuidos en distintos departamentos. La infraestructura se soporta sobre tres servidores físicos con VirtualBox sobre Debian 13, un servidor enrackable dedicado a la DMZ y un componente cloud en AWS.

Esta política define los procedimientos, responsabilidades, frecuencias y mecanismos de verificación necesarios para garantizar la disponibilidad, integridad y recuperabilidad de los datos y servicios críticos de la Sede Alcoi ante cualquier incidente: fallo de hardware, corrupción de datos, error humano, ataque de ransomware o desastre natural.

Los servidores virtuales cubiertos por esta política son: **SRV-DC01** (PDC + WDS + WSUS), **SRV-DC02** (BDC Core), **SRV-APP01** (RemoteApp), **SRV-DAD01** (File Server + DFS), **SRV-MON01** (Zabbix), **SRV-NAS01** (TrueNAS / Cabina de discos), **SRV-WEB-DMZ** (servidor web intranet) y **SRV-WEB-AWS** (web estática en la nube).

---

## 2. Objetivos

La política de copias de seguridad de la Sede Alcoi persigue los siguientes objetivos fundamentales:

- **Continuidad del negocio:** Minimizar el tiempo de inactividad ante cualquier incidente que afecte a los sistemas de información de la Sede Alcoi, garantizando que los servicios críticos puedan restaurarse dentro de los plazos definidos.
- **Protección de datos:** Salvaguardar la información corporativa almacenada en los servidores de ficheros (DFS), Active Directory, bases de datos de monitorización y configuraciones de los servicios.
- **Cumplimiento normativo:** Asegurar el cumplimiento de la legislación vigente en materia de protección de datos (RGPD/LOPDGDD) y las políticas internas de seguridad de la información.
- **Integridad verificable:** Establecer mecanismos de verificación periódica que garanticen que las copias son utilizables y los datos íntegros.
- **Resiliencia ante ransomware:** Mantener al menos una copia offline o inmutable que no pueda ser comprometida en caso de cifrado malicioso de los sistemas en producción.

---

## 3. RTO y RPO

Los parámetros de **RTO (Recovery Time Objective)** y **RPO (Recovery Point Objective)** definen, respectivamente, el tiempo máximo aceptable para restaurar un servicio y la cantidad máxima de datos que la Sede Alcoi puede permitirse perder (medida en tiempo transcurrido desde la última copia válida).

### 3.1 Clasificación por criticidad

Cada servidor se clasifica en un nivel de criticidad que determina sus parámetros RTO/RPO:

| Servidor | Criticidad | RTO | RPO | Justificación |
|---|---|---|---|---|
| SRV-DC01 (PDC) | **CRÍTICA** | 1 hora | 4 horas | Autenticación, DNS, DHCP: sin él no hay dominio |
| SRV-DC02 (BDC) | ALTA | 2 horas | 4 horas | Réplica AD: asume FSMO si cae DC01 |
| SRV-DAD01 (Datos) | **CRÍTICA** | 1 hora | 1 hora | Ficheros corporativos de todos los departamentos |
| SRV-APP01 (Apps) | ALTA | 4 horas | 24 horas | RemoteApp: impacto en productividad |
| SRV-NAS01 (TrueNAS) | **CRÍTICA** | 2 horas | 4 horas | Cabina iSCSI: sin ella no hay datos ni WDS |
| SRV-MON01 (Zabbix) | MEDIA | 8 horas | 24 horas | Monitorización: importante pero no bloquea operativa |
| SRV-WEB-DMZ | MEDIA | 4 horas | 24 horas | Web intranet/corporativa en DMZ |
| SRV-WEB-AWS | BAJA | 8 horas | 48 horas | Web estática: reconstruible desde repositorio |

> *Nota: Los valores de RTO contemplan la restauración desde copias locales (TrueNAS). Si se requiere restaurar desde la nube, los tiempos pueden incrementarse en función del ancho de banda disponible en la Sede Alcoi.*

---

## 4. Tipos de Copias de Seguridad

Se establecen tres tipos de copias de seguridad complementarias, cuya combinación optimiza el equilibrio entre consumo de almacenamiento, ventana de backup y granularidad de restauración.

### 4.1 Copia completa (Full Backup)

Captura íntegra de todo el servidor virtual (discos, configuración, estado del sistema operativo). Para los servidores VirtualBox se utilizará la exportación OVA/OVF nativa de VBoxManage. Para TrueNAS se emplearán snapshots ZFS completos. Es la copia más pesada pero la más rápida de restaurar ya que no depende de copias anteriores.

### 4.2 Copia incremental

Registra únicamente los bloques o ficheros modificados desde la última copia (ya sea completa o incremental). Reduce significativamente el espacio y el tiempo de copia. La restauración requiere la última copia completa más todas las incrementales posteriores en secuencia. Se implementará mediante herramientas como rsync con hardlinks o Borg Backup.

### 4.3 Copia diferencial

Registra todos los cambios acumulados desde la última copia completa. Crece más que la incremental pero simplifica la restauración (solo se necesita la última completa + la última diferencial). Se utilizará en servidores de criticidad CRÍTICA como alternativa bisemanal para tener un punto de restauración rápido.

### 4.4 Snapshots ZFS (TrueNAS)

Los snapshots nativos de ZFS en SRV-NAS01 proporcionan puntos de restauración instantáneos a nivel de bloque. Son extremadamente eficientes (solo almacenan deltas) y permiten recuperar ficheros individuales o volúmenes iSCSI completos en segundos. Se configurarán snapshots automáticos cada 4 horas con retención de 7 días.

### 4.5 Copia de estado del sistema (System State)

Específica para los controladores de dominio (SRV-DC01 y SRV-DC02). Incluye Active Directory, SYSVOL, registro de Windows, certificados y configuración de arranque. Se realiza con Windows Server Backup (wbadmin) y es imprescindible para la restauración autoritativa del AD.

### Resumen comparativo

| Tipo | Ventaja principal | Desventaja | Uso en esta infraestructura |
|---|---|---|---|
| Completa | Restauración rápida e independiente | Mayor tamaño y ventana de backup | Semanal para todos los servidores |
| Incremental | Mínimo espacio y tiempo | Restauración encadenada | Diaria para todos los servidores |
| Diferencial | Balance tamaño/velocidad restauración | Crece a lo largo de la semana | Bisemanal para servidores críticos |
| Snapshot ZFS | Instantáneo, sin impacto en rendimiento | Solo en TrueNAS | Cada 4 horas en SRV-NAS01 |
| System State | Recuperación de AD autoritativa | Solo aplica a DCs | Diaria en DC01 y DC02 |

---

## 5. Planificación de Copias

La ventana de backup se sitúa preferentemente fuera del horario laboral de la Sede Alcoi (20:00–07:00) para minimizar el impacto en el rendimiento de los servicios. Las copias se escalonan para evitar la saturación del almacenamiento y la red.

### 5.1 Calendario semanal

| Servidor | Lunes | Martes | Miércoles | Jueves | Viernes | Sábado | Domingo |
|---|---|---|---|---|---|---|---|
| SRV-DC01 | INC | INC | DIF | INC | INC | DIF | FULL |
| SRV-DC02 | INC | INC | DIF | INC | INC | DIF | FULL |
| SRV-DAD01 | INC | INC | DIF | INC | INC | DIF | FULL |
| SRV-APP01 | INC | INC | INC | INC | INC | — | FULL |
| SRV-NAS01 | INC | INC | INC | INC | INC | — | FULL |
| SRV-MON01 | INC | — | INC | — | INC | — | FULL |
| SRV-WEB-DMZ | INC | — | INC | — | INC | — | FULL |
| SRV-WEB-AWS | — | — | INC | — | — | — | FULL |

*INC = Incremental | DIF = Diferencial | FULL = Completa | — = Sin copia programada*

### 5.2 Horarios de ejecución

| Hora | Acción |
|---|---|
| 20:00 | System State de SRV-DC01 y SRV-DC02 (wbadmin) |
| 21:00 | Backup de SRV-DC01 (VBoxManage export / rsync) |
| 22:00 | Backup de SRV-DC02 |
| 22:30 | Backup de SRV-DAD01 |
| 23:30 | Backup de SRV-APP01 |
| 00:30 | Backup de SRV-NAS01 (snapshot ZFS + replicación) |
| 01:30 | Backup de SRV-MON01 |
| 02:00 | Backup de SRV-WEB-DMZ |
| 03:00 | Sincronización a la nube (AWS S3) de las copias críticas |
| 04:00–06:00 | Snapshots ZFS adicionales automáticos (cada 4h) |

### 5.3 Copias adicionales bajo demanda

Además de la planificación periódica, se realizarán copias completas extraordinarias antes de cualquier cambio significativo en la infraestructura de la Sede Alcoi: actualizaciones del sistema operativo, migraciones de roles, instalación de nuevos servicios, cambios en la configuración de Active Directory o modificaciones en la estructura de DFS.

---

## 6. Ubicación de las Copias

Se aplica la **estrategia 3-2-1**: al menos **3 copias** de los datos, en **2 soportes distintos**, con **1 copia fuera del sitio** (offsite). Esta estrategia protege a la Sede Alcoi contra fallos localizados (disco, servidor, incendio) y ataques que comprometan la red local.

### 6.1 Copia 1 — Local en TrueNAS (SRV-NAS01)

- Almacenamiento primario de las copias en el pool ZFS en mirall (RAID-1) de TrueNAS.
- Las copias se almacenan en un dataset ZFS dedicado con compresión LZ4 activada.
- Los snapshots ZFS proporcionan puntos de restauración adicionales instantáneos.
- Accesible vía red local de la Sede Alcoi para restauraciones rápidas (objetivo RTO mínimo).

### 6.2 Copia 2 — Disco externo USB / NAS secundario

- Un disco externo USB 3.0 conectado al servidor orquestador recibe una réplica semanal de las copias completas.
- Este disco se rota mensualmente y se almacena en una ubicación física distinta (armario ignífugo o sede alternativa).
- Proporciona protección ante ransomware: al estar desconectado la mayor parte del tiempo, no es accesible desde la red.

### 6.3 Copia 3 — Nube (AWS S3)

- Las copias de los servidores de criticidad CRÍTICA (DC01, DAD01, NAS01) se replican semanalmente a un bucket de AWS S3 con versionado habilitado.
- Se utilizará la clase de almacenamiento **S3 Glacier Instant Retrieval** para optimizar costes manteniendo tiempos de acceso razonables.
- La transferencia se realiza cifrada (TLS en tránsito + AES-256 en reposo con SSE-S3).
- El bucket S3 tendrá activado Object Lock en modo Compliance para garantizar la inmutabilidad de las copias durante el periodo de retención.

### Resumen de ubicaciones

| Ubicación | Soporte | Servidores cubiertos | Frecuencia sync | Finalidad |
|---|---|---|---|---|
| TrueNAS local | ZFS RAID-1 (SSD) | Todos | Diaria | Restauración rápida (RTO mínimo) |
| Disco USB externo | HDD USB 3.0 | Críticos + AD | Semanal | Air-gap anti-ransomware |
| AWS S3 Glacier | Cloud object storage | DC01, DAD01, NAS01 | Semanal | Offsite / disaster recovery |

---

## 7. Seguridad de las Copias

### 7.1 Cifrado

- **En tránsito:** Todas las transferencias de copias entre servidores y hacia la nube se realizan sobre canales cifrados: SSH/SCP para transferencias locales y TLS 1.2+ para las subidas a AWS S3.
- **En reposo (local):** Las copias almacenadas en TrueNAS se benefician del cifrado nativo de ZFS (dataset encryption con AES-256-GCM). La clave de cifrado se almacena en un fichero protegido fuera del pool ZFS.
- **En reposo (nube):** AWS S3 Server-Side Encryption (SSE-S3) con AES-256. Opcionalmente se puede activar SSE-KMS con claves gestionadas por AWS KMS para mayor control.
- **En reposo (USB):** Los discos USB externos se cifrarán con LUKS (Linux Unified Key Setup). La contraseña del volumen LUKS se custodia en un sobre sellado en la caja fuerte de la Sede Alcoi.

### 7.2 Integridad

- ZFS realiza verificación automática de checksums (SHA-256) en cada lectura, detectando y autocorrigiendo bit-rot gracias al mirror.
- Tras cada copia, el script de backup genera un hash SHA-256 del fichero resultante y lo almacena en un fichero de manifiesto junto a la copia.
- Mensualmente se ejecuta un scrub ZFS completo en TrueNAS para verificar la integridad de todos los bloques del pool.
- Las copias en S3 se verifican con ETags MD5 durante la subida y con verificación periódica de integridad mediante AWS CLI.

### 7.3 Protección anti-ransomware

- Los snapshots ZFS son de solo lectura por diseño: no pueden ser modificados ni eliminados por malware que comprometa una VM.
- El bucket S3 con Object Lock impide la eliminación o modificación de objetos durante el periodo de retención, incluso con credenciales de administrador.
- El disco USB permanece desconectado excepto durante la ventana de sincronización semanal (air-gap).
- Las credenciales de acceso a AWS y a TrueNAS para backups utilizan cuentas de servicio dedicadas con permisos mínimos (principio de menor privilegio).

---

## 8. Control de Acceso

El acceso a las copias de seguridad de la Sede Alcoi se restringe estrictamente siguiendo el principio de menor privilegio. Solo el personal autorizado del departamento de sistemas puede gestionar, verificar o restaurar copias.

### 8.1 Roles y permisos

| Rol | Permisos | Personal asignado |
|---|---|---|
| Administrador de backup | Configurar, ejecutar, verificar y restaurar copias. Acceso completo a TrueNAS, AWS S3 y scripts. | Administrador de sistemas (máx. 2 personas) |
| Operador de backup | Verificar el estado de las copias y lanzar restauraciones preautorizadas. Sin acceso a modificar políticas. | Técnico de soporte designado |
| Auditor | Acceso de solo lectura a los logs y manifiestos de copias para auditoría y cumplimiento. | Responsable de seguridad / DPO |
| Resto de empleados | Sin acceso a las copias de seguridad ni a los sistemas de backup. | Todos los demás |

### 8.2 Mecanismos de control

- Autenticación mediante claves SSH dedicadas (Ed25519) para los scripts automatizados, sin contraseña interactiva.
- Las cuentas de servicio de backup en Active Directory pertenecen al grupo «Backup Operators» con GPO restrictiva.
- Acceso a la consola web de TrueNAS limitado por IP de origen (solo estaciones de administración de la Sede Alcoi).
- Las credenciales de AWS IAM para la sincronización a S3 utilizan una política que solo permite s3:PutObject y s3:GetObject sobre el bucket de backups.
- Todos los accesos a las copias quedan registrados en los logs de Zabbix y del sistema operativo.
- Cualquier acceso excepcional requiere aprobación documentada del responsable de sistemas y queda registrado en el libro de incidencias.

---

## 9. Política de Retención

La retención define durante cuánto tiempo se conservan las copias antes de ser eliminadas. El objetivo es mantener un historial suficiente para cubrir escenarios de recuperación sin consumir almacenamiento excesivo.

| Tipo de copia | Retención local (TrueNAS) | Retención USB | Retención nube (S3) |
|---|---|---|---|
| Incremental diaria | 14 días | — | — |
| Diferencial bisemanal | 30 días | — | — |
| Completa semanal | 4 semanas (28 días) | 4 semanas | 8 semanas |
| Completa mensual (1ª del mes) | 6 meses | 3 meses | 12 meses |
| Completa anual (1 enero) | 2 años | 1 año | 3 años |
| Snapshots ZFS | 7 días (cada 4h) | — | — |
| System State AD | 30 días | 4 semanas | 8 semanas |

La eliminación de copias caducadas se ejecuta automáticamente mediante scripts que respetan los periodos indicados. Antes de la eliminación se genera un informe que se envía al administrador de backup para su revisión.

> *Nota legal: En caso de que la legislación vigente o requerimientos judiciales exijan la conservación de datos más allá de estos periodos, se crearán copias de retención legal (legal hold) que no se eliminarán hasta que se levante la obligación.*

---

## 10. Automatización

Todos los procesos de copia se automatizan mediante scripts Bash ejecutados por cron en el nodo orquestador (uno de los servidores físicos Debian 13 de la Sede Alcoi). La intervención manual se limita a la supervisión, las pruebas de restauración y la gestión de incidencias.

### 10.1 Componentes del sistema automatizado

| Componente | Descripción | Ubicación |
|---|---|---|
| backup.conf | Fichero de configuración centralizado con IPs, rutas, parámetros de compresión y exclusiones | /opt/backup-system/ |
| backup-main.sh | Script principal de orquestación: itera por servidores, ejecuta VBoxManage, transfiere copias | /opt/backup-system/ |
| backup-ad.sh | Script específico para System State de los DCs (wbadmin vía WinRM/SSH) | /opt/backup-system/ |
| backup-zfs.sh | Gestión de snapshots y replicación ZFS en TrueNAS | /opt/backup-system/ |
| sync-cloud.sh | Sincronización a AWS S3 con aws-cli, verificación de integridad post-subida | /opt/backup-system/ |
| cleanup.sh | Eliminación automática de copias según política de retención | /opt/backup-system/ |
| verify.sh | Verificación de hashes SHA-256 y comprobación de restaurabilidad | /opt/backup-system/ |

### 10.2 Herramientas utilizadas

- **VBoxManage:** Herramienta CLI nativa de VirtualBox para exportar VMs en formato OVA (Open Virtual Appliance), clonar discos y gestionar snapshots de las máquinas virtuales.
- **rsync:** Transferencia incremental eficiente de ficheros entre los servidores físicos y TrueNAS vía SSH.
- **wbadmin:** Windows Server Backup para copias de System State en los controladores de dominio, ejecutado remotamente vía PowerShell/WinRM.
- **ZFS send/receive:** Replicación nativa de datasets ZFS para copias incrementales a nivel de bloque en TrueNAS.
- **AWS CLI (aws s3 sync):** Sincronización de copias al bucket S3 con soporte multipart para ficheros grandes y verificación de integridad.
- **Borg Backup (opcional):** Alternativa de backup deduplicado y cifrado para los servidores Linux (Zabbix, DMZ), con soporte de retención flexible.

### 10.3 Monitorización del sistema de backup

Zabbix (SRV-MON01) monitoriza el estado de los procesos de backup mediante:

- Items personalizados que verifican la fecha y tamaño de la última copia de cada servidor.
- Triggers que generan alertas si una copia no se ha completado en el plazo esperado o si el tamaño es anómalamente pequeño (indicativo de fallo parcial).
- Dashboard dedicado en Zabbix Frontend con el estado visual de todos los backups.
- Notificaciones por email al administrador de backup en caso de fallo, y resumen diario del estado de todas las copias.

---

## 11. Pruebas de Restauración

Una copia de seguridad que no se ha probado es una copia que no existe. Se establece un calendario de pruebas de restauración periódicas para verificar que las copias son íntegras, completas y restaurables dentro de los parámetros RTO definidos.

### 11.1 Calendario de pruebas

| Frecuencia | Alcance de la prueba | Responsable |
|---|---|---|
| Mensual | Restauración de ficheros individuales desde DFS (SRV-DAD01) y verificación de contenido | Operador de backup |
| Mensual | Restauración de System State del DC01 en un entorno de pruebas aislado | Administrador de backup |
| Trimestral | Restauración completa de una VM crítica (rotativa: DC01, DAD01, NAS01) en un host de pruebas | Administrador de backup |
| Trimestral | Restauración desde la nube (AWS S3) de una copia completa para medir tiempos reales | Administrador de backup |
| Semestral | Simulacro de desastre completo: restauración de DC01 + DAD01 + NAS01 y verificación de servicios | Equipo de sistemas completo |
| Anual | Prueba de recuperación ante desastre total (DR): reconstrucción del dominio desde cero usando backups | Equipo de sistemas + Dirección TI |

### 11.2 Procedimiento de prueba

Cada prueba de restauración se documenta en un **informe de prueba** que incluye: fecha, servidor restaurado, copia utilizada, tiempo real de restauración (comparado con el RTO), verificaciones realizadas (servicios activos, datos accesibles, integridad), resultado (APTO / NO APTO) y observaciones o acciones correctoras.

Los informes de prueba se almacenan en el repositorio documental del departamento de sistemas de la Sede Alcoi y se revisan en las auditorías de seguridad.

---

## 12. Procedimiento de Recuperación

Este apartado define los pasos a seguir para la restauración de servicios en función del tipo de incidente. El orden de restauración respeta las dependencias entre servicios de la Sede Alcoi.

### 12.1 Orden de restauración (prioridad)

En caso de caída múltiple o desastre total, los servidores se restauran en el siguiente orden estricto, basado en las dependencias de servicios:

| Prioridad | Servidor | Justificación |
|---|---|---|
| 1º | SRV-NAS01 (TrueNAS) | Cabina iSCSI: sin ella no hay almacenamiento para datos ni WDS |
| 2º | SRV-DC01 (PDC) | Controlador de dominio principal: AD DS, DNS, DHCP |
| 3º | SRV-DC02 (BDC) | Réplica AD: confirmar replicación correcta tras restaurar DC01 |
| 4º | SRV-DAD01 (Datos) | Servidor de ficheros DFS: recuperar datos departamentales |
| 5º | SRV-APP01 (RemoteApp) | Aplicaciones remotas: productividad de los usuarios |
| 6º | SRV-MON01 (Zabbix) | Monitorización: visibilidad del estado de la infraestructura |
| 7º | SRV-WEB-DMZ | Web intranet/corporativa |
| 8º | SRV-WEB-AWS | Web estática: última prioridad, reconstruible desde repositorio |

### 12.2 Escenarios de recuperación

#### Escenario A: Pérdida de una única VM

Ante la pérdida de una sola máquina virtual (fallo de disco virtual, corrupción del SO, error de configuración irreversible):

- Identificar la última copia válida en TrueNAS (consultar manifiesto de backups).
- Copiar la imagen OVA desde TrueNAS al servidor físico correspondiente mediante rsync/SCP.
- Importar la VM con `VBoxManage importappliance`, ajustando la red si es necesario.
- Arrancar la VM, verificar los servicios y comprobar la conectividad con el dominio.
- Si es un DC, forzar la replicación del AD con `repadmin /syncall`.
- Documentar la incidencia y el tiempo real de restauración.

#### Escenario B: Pérdida de un servidor físico

Si falla completamente un servidor físico (SRV-FIS-01, SRV-FIS-02 o SRV-FIS-03):

- Sustituir o reparar el hardware. Reinstalar Debian 13 + VirtualBox en el nuevo equipo.
- Restaurar las VMs asignadas a ese servidor físico desde TrueNAS, siguiendo el orden de prioridad.
- Si las copias locales no están disponibles (p.ej., fallo simultáneo de NAS), recurrir a las copias en AWS S3.
- Redistribuir temporalmente las VMs críticas a los servidores físicos supervivientes si hay RAM suficiente.

#### Escenario C: Ataque de ransomware

En caso de cifrado malicioso de uno o varios servidores de la Sede Alcoi:

- Aislar inmediatamente todos los servidores afectados de la red (desconectar NICs).
- Evaluar el alcance: determinar qué servidores están comprometidos y cuáles están intactos.
- NO utilizar las copias en TrueNAS si existe sospecha de que el NAS también ha sido comprometido.
- Restaurar desde el disco USB (air-gap) o desde AWS S3 (Object Lock garantiza inmutabilidad).
- Reconstruir las VMs en servidores físicos limpios (reinstalación completa del host).
- Cambiar todas las contraseñas del dominio, claves SSH, credenciales AWS y tokens de acceso.
- Analizar el vector de ataque antes de reconectar los servicios a la red.

#### Escenario D: Desastre total (pérdida del sitio)

Ante la pérdida física completa de la Sede Alcoi (incendio, inundación, robo):

- Adquirir o provisionar nuevo hardware (o utilizar infraestructura temporal en la nube).
- Descargar las copias desde AWS S3 Glacier al nuevo emplazamiento.
- Restaurar siguiendo estrictamente el orden de prioridad: NAS01 → DC01 → DC02 → DAD01 → resto.
- Reconstruir la configuración de red (DHCP, DNS, firewall, VLANs).
- Verificar la integridad de Active Directory y forzar la replicación entre DCs.
- Comunicar el estado a la dirección y a los departamentos afectados según el plan de comunicación de crisis.

### 12.3 Contactos de emergencia

Toda restauración debe ser comunicada inmediatamente a:

- Administrador de sistemas principal (Administrador de backup).
- Responsable de seguridad de la información / DPO.
- Director de TI (para incidentes de criticidad ALTA o CRÍTICA).
- Proveedor de soporte de hardware (si aplica sustitución física).

> *Los datos de contacto específicos se mantienen en el documento «Plan de Continuidad de Negocio» de la Sede Alcoi, accesible desde el repositorio documental del departamento y en copia impresa custodiada por el Director de TI.*

---

*Fin del documento — Política de Copias de Seguridad v1.0 — Sede Alcoi*
