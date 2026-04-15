# Diseño del CPD y organización de las sedes

## Grupo 

**Victor Tamajon, Diego Perez, Pablo Vaño, Aitor Brotons, Pedro Fernández** 

---

## Distribución del RACK 

Breve descripcion del objetivo del proyecto y sus requisitos.

| Unidades | Conectado  |
|-------|-------|
| 0-7 | Libre |
| 8-13 | Servidores |
|   14-16 |   Libre |
|    17 |   Switch D-Link (NO configurable) |
|   18-21 |   Libre |
|   22 |   Patch panel edificio 1 |
|   23-26 |   Libre |
|   27 |   Switch Cisco |
|   28-29 |   Libre |
|   30 |   Patch Panel Edificio 2 |
|   31-32 |   Libre |
|   33 |   Switch TP-Link (16 puertos) |
|   34-42 |   Libre |

---

## Conexión de puertos 

## TP-Link 8 puertos

| Puerto | Conectado |
|-------|-------|
| 1 | Mikrotik | 
| 2 | Switch Cisco | 
| 3 | Switch TP-Link 16 puertos | 
| 4 | Vacio | 
| 5 | Vacio | 
| 6 | Vacio | 
| 7 | Vacio | 
| 8 | Vacio |

---

### Switch Cisco 48 puertos  

| Puerto | Conectado |
|-------|-------|
| 1 | Recepción |
| 2 | Gerencia y administración |
| 3-16 | Vacio |
| 17 | SRV-DC01 (f1) |
| 18 | SRV-APP01 |
| 29 | SRV-MON01 |
| 20 | SRV-DAD01 (f1) |
| 21 | SRV-NAS01 |
| 22 | SRV-WEB-DMZ |
| 23-32 | Vacio |
| 33 | Informática |
| 34-47 | Vacio |
| 48 | TP-Link 8 puertos |

---

### D-Link (SAN) 

| Puerto | Conectado |
|-------|-------|
| 1 | SRV-DC01 (f2) | 
| 2 | SRV-DAD01 (f2) |
| 3-16 | Vacio |

---

### Switch TP-Link 16 puertos 

| Puerto | Conectado |
|-------|-------|
| 1 | Vigilancia | 
| 2 | Comercial |
| 3 | Producción |
| 4 | Almacenamiento |
| 5-15 | Vacios |
| 16 | TP-Link 8 puertos |

---

## Patch Panels

### Patch Panel 1 (24 puertos máx.)

**Uso: VMs + Departamento de Informática + Administración**

| Puerto	| Conectado |
|-------|-------|
| 1	| VM - SRV-DC01 |
| 1	| VM - SRV-DC02 |
| 3	| VM - SRV-APP01 |
| 4	| VM - SRV-DAD01 |
| 5	| VM - SRV-NAS01 |
| 6	| VM - SRV-WEB |
| 7	| Informática |
| 8	| Gerencia y administración |
| 9	| Recepción |
| 10-24	| Reserva |

### Patch Panel 2 (24 puertos máx.)

**Uso: Departamentos conectados al TP-Link 16 puertos**

| Puerto	| Conectado |
|-------|-------|
| 1	| Vigilancia |
| 2	| Comercial |
| 3	| Producción |
| 4	| Almacenamiento |
| 5-24	| Reserva |

#### Notas de organización

El Patch Panel 1 concentra servicios críticos (VMs + IT + Administración) y enlaza con el Switch Cisco.
El Patch Panel 2 agrupa los departamentos distribuidos y conecta con el TP-Link 16 puertos.
Se dejan puertos libres en ambos patch panel para escalabilidad futura.