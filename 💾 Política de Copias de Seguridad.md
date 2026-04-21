# 💾 Política de Copias de Seguridad

## 1. Introducción

La presente política establece los procedimientos para la realización de copias de seguridad dentro de la infraestructura informática de la empresa, con el fin de garantizar la **disponibilidad**, **integridad** y **confidencialidad** de la información ante posibles fallos, errores humanos o ataques externos.

Esta política se aplica a todos los sistemas críticos de la organización, incluyendo servidores, datos de usuarios y servicios corporativos.

## 2. Objetivos

*   Proteger los datos frente a pérdidas o corrupción.
*   Garantizar la continuidad del negocio.
*   Permitir la recuperación rápida de sistemas.
*   Minimizar el tiempo de inactividad (**RTO**).
*   Limitar la pérdida de información (**RPO**).

## 3. RTO y RPO

*   **RTO (Recovery Time Objective)**: máximo 4 horas.
*   **RPO (Recovery Point Objective)**: máximo 24 horas.

Esto implica que:

*   Los sistemas deberán restaurarse en un máximo de 4 horas.
*   Se podrá perder como máximo la información generada en las últimas 24 horas.

## 4. Tipos de Copias

| Tipo de Copia | Descripción | Frecuencia | Base para Restauración |
| :------------ | :---------- | :--------- | :--------------------- |
| **Copia Completa (Full)** | Incluye todos los datos del sistema. | Semanal | Sí |
| **Copia Incremental** | Copia únicamente los cambios desde la última copia. | Diaria | No (requiere copia completa previa) |
| **Copia Diferencial (Opcional)** | Copia los cambios desde la última copia completa. | Variable | Sí (requiere copia completa previa) |

## 5. Planificación de Copias

| Tipo de Copia | Frecuencia | Hora | Contenido |
| :------------ | :--------- | :--- | :-------- |
| Incremental | Diaria | 23:00 | Datos de usuarios y documentos |
| Completa | Semanal (domingo) | 02:00 | Servidores completos |
| Mensual | Primer día del mes | 03:00 | Copia histórica |

## 6. Ubicación de las Copias

### 🖥️ Almacenamiento Local

*   **Cabina de discos (iSCSI / NAS)**: Permite restauraciones rápidas.

### 💽 Almacenamiento en Disco Externo

*   Uso de discos duros externos dedicados exclusivamente a copias de seguridad.
*   Conexión no permanente para evitar infecciones por malware o ransomware.
*   Almacenamiento en ubicación segura y separada físicamente.
*   Utilizado principalmente para copias semanales o mensuales.

### ☁️ Almacenamiento en la Nube

*   Uso de servicios cloud para copias externas.
*   Proporciona redundancia geográfica.
*   Acceso seguro mediante cifrado y autenticación.
*   Permite recuperación ante desastres graves.

### 🌍 Almacenamiento Remoto (Servidor Externo)

*   **Servidor remoto**: `magneto.cipfpbatoi.lan`.
*   Transferencia segura mediante SSH.
*   Uso de herramientas como `rsync` o `scp`.
*   Se crea un usuario específico por sede.

## 7. Seguridad de las Copias

*   Cifrado de las copias de seguridad.
*   Acceso restringido únicamente a administradores.
*   Uso de cuentas específicas para backups.
*   Registro de accesos y operaciones (logs).

## 8. Control de Acceso

El acceso a las copias de seguridad estará limitado a:

*   Administradores del sistema.
*   Usuarios específicos de backup.

No se permitirá el acceso a usuarios no autorizados ni la manipulación manual de las copias.

## 9. Política de Retención

| Tipo de Copia | Retención |
| :------------ | :-------- |
| Diarias | 7 días |
| Semanales | 1 mes |
| Mensuales | 6 meses |

**Opcionalmente**:

*   Copias anuales: hasta 1 año.

## 10. Automatización

Las copias se realizarán de forma automática mediante:

*   **Sistemas Linux**: uso de `cron` y herramientas como `rsync`.
*   **Sistemas Windows**: programador de tareas o scripts en PowerShell.

## 11. Pruebas de Restauración

Se realizarán pruebas periódicas para garantizar la fiabilidad de las copias:

*   **Frecuencia**: mensual.
*   **Tipos**:
    *   Restauración de archivos individuales.
    *   Restauración completa del sistema.

Los resultados serán documentados.

## 12. Procedimiento de Recuperación

En caso de pérdida de datos:

1.  Identificar el tipo de incidencia.
2.  Seleccionar la copia más reciente válida.
3.  Restaurar desde almacenamiento local o remoto.
4.  Verificar la integridad de los datos.
5.  Documentar la incidencia.

## 13. Copias Remotas

*   Transferencia diaria al servidor externo mediante SSH.
*   Compresión de datos para optimizar espacio.
*   Separación de credenciales por sede.
*   Protección frente a fallos locales.

## 14. Gestión de Incidencias

Se considerarán incidencias:

*   Fallos en la ejecución de copias.
*   Copias corruptas.
*   Problemas de almacenamiento.

**Acciones**:

*   Reintento automático.
*   Notificación al administrador.
*   Registro en logs.

## 15. Monitorización

El sistema de backups será supervisado mediante:

*   Registros automáticos.
*   Alertas en caso de error.
*   Integración con herramientas de monitorización como Zabbix.

## 16. Documentación

Se mantendrá registro de:

*   Copias realizadas.
*   Fallos detectados.
*   Restauraciones realizadas.
*   Cambios en la política.

## 17. Mejora Continua

Se evaluará periódicamente la política para incorporar mejoras como:

*   Copias inmutables contra ransomware.
*   Integración con servicios cloud avanzados.
*   Versionado de archivos.
*   Sistemas de backup continuo.
