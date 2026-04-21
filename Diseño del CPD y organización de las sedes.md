# Diseño del CPD y organización de las sedes

**Grup:** Victor Tamajon, Diego Perez, Pablo Vaño, Aitor Brotons, Pedro Fernández

---

## Índex

1. [VLANs que utilitzarem](#1-vlans-que-utilitzarem)
2. [Assignació de ports de cada switch i del Mikrotik](#2-assignació-de-ports-de-cada-switch-i-del-mikrotik)
3. [Assignació dels ports de cada patch panel](#3-assignació-dels-ports-de-cada-patch-panel)
4. [Estructura del rack](#4-estructura-del-rack)

---

## 1. VLANs que utilitzarem

### Justificació del disseny

Es segmenta la xarxa en VLANs per aïllar el tràfic per funció, millorar la seguretat i facilitar l'aplicació de polítiques de firewall des del Mikrotik, que actua com a **router-on-a-stick** gestionant el tràfic inter-VLAN mitjançant subinterfícies 802.1Q.

### Taula de VLANs

| VLAN ID | Nom | Xarxa IP | Porta d'enllaç | Switch / Ports |
|---------|-----|----------|----------------|----------------|
| 10 | Management | 192.168.10.0/24 | 192.168.10.1 | Tots els switches (accés de gestió) |
| 20 | Servidors | 192.168.20.0/24 | 192.168.20.1 | Cisco: ports 17–22 |
| 30 | Administració | 192.168.30.0/24 | 192.168.30.1 | Cisco: ports 1–2 (Recepció, Gerència) |
| 40 | Informàtica | 192.168.40.0/24 | 192.168.40.1 | Cisco: port 33 |
| 50 | Vigilància | 192.168.50.0/24 | 192.168.50.1 | TP-Link 16p: port 1 |
| 60 | Producció/Magatzem | 192.168.60.0/24 | 192.168.60.1 | TP-Link 16p: ports 3–4 |
| 70 | Comercial | 192.168.70.0/24 | 192.168.70.1 | TP-Link 16p: port 2 |
| 80 | DMZ | 192.168.80.0/24 | 192.168.80.1 | Cisco: port 22 (SRV-WEB-DMZ) |
| 90 | SAN | 192.168.90.0/24 | 192.168.90.1 | D-Link: ports 1–2 |

### Ports trunk (802.1Q — totes les VLANs etiquetades)

| Enllaç | Switch origen | Port | Switch destí | Port |
|--------|--------------|------|--------------|------|
| Core → Cisco | TP-Link 8p | 2 | Cisco | 48 |
| Core → TP-Link 16p | TP-Link 8p | 3 | TP-Link 16p | 16 |
| Core → Mikrotik | TP-Link 8p | 1 | Mikrotik | — |

### Notes

- El **D-Link (SAN)** no és gestionable, per tant la VLAN 90 queda físicament aïllada: només els servidors amb doble targeta (SRV-DC01 f2, SRV-DAD01 f2) hi accedeixen.
- La **VLAN 80 (DMZ)** està aïllada de la resta: el Mikrotik només permet tràfic entrant des d'internet al port 80/443 del SRV-WEB-DMZ.
- La **VLAN 10 (Management)** té accés restringit: només des de l'equip d'Informàtica (VLAN 40).

---

## 2. Assignació de ports de cada switch i del Mikrotik

### TP-Link 8 ports (switch core)

| Port | Connectat a | VLAN | Mode |
|------|-------------|------|------|
| 1 | Mikrotik | Trunk (totes) | Trunk |
| 2 | Switch Cisco | Trunk (totes) | Trunk |
| 3 | Switch TP-Link 16p | Trunk (totes) | Trunk |
| 4–8 | Buit | — | — |

### Switch Cisco 48 ports

| Port | Connectat a | VLAN | Mode |
|------|-------------|------|------|
| 1 | Recepció | 30 | Access |
| 2 | Gerència i administració | 30 | Access |
| 3–16 | Buit | — | — |
| 17 | SRV-DC01 (f1) | 20 | Access |
| 18 | SRV-APP01 | 20 | Access |
| 19 | SRV-MON01 | 20 | Access |
| 20 | SRV-DAD01 (f1) | 20 | Access |
| 21 | SRV-NAS01 | 20 | Access |
| 22 | SRV-WEB-DMZ | 80 | Access |
| 23–32 | Buit | — | — |
| 33 | Informàtica | 40 | Access |
| 34–47 | Buit | — | — |
| 48 | TP-Link 8p | Trunk (totes) | Trunk |

### Switch D-Link (SAN — NO gestionable)

| Port | Connectat a |
|------|-------------|
| 1 | SRV-DC01 (f2) |
| 2 | SRV-DAD01 (f2) |
| 3–16 | Buit |

> **Nota:** Aquest switch no suporta VLANs. La segmentació es garanteix per aïllament físic: cap altre equip es connecta a ell.

### Switch TP-Link 16 ports

| Port | Connectat a | VLAN | Mode |
|------|-------------|------|------|
| 1 | Vigilància | 50 | Access |
| 2 | Comercial | 70 | Access |
| 3 | Producció | 60 | Access |
| 4 | Magatzem | 60 | Access |
| 5–15 | Buits | — | — |
| 16 | TP-Link 8p | Trunk (totes) | Trunk |

### Mikrotik

| Subinterfície | VLAN ID | Xarxa | Funció |
|---------------|---------|-------|--------|
| ether1.10 | 10 | 192.168.10.0/24 | Management |
| ether1.20 | 20 | 192.168.20.0/24 | Servidors |
| ether1.30 | 30 | 192.168.30.0/24 | Administració |
| ether1.40 | 40 | 192.168.40.0/24 | Informàtica |
| ether1.50 | 50 | 192.168.50.0/24 | Vigilància |
| ether1.60 | 60 | 192.168.60.0/24 | Producció/Magatzem |
| ether1.70 | 70 | 192.168.70.0/24 | Comercial |
| ether1.80 | 80 | 192.168.80.0/24 | DMZ |
| ether1 (WAN) | — | IP pública / DHCP ISP | Accés a internet |

---

## 3. Assignació dels ports de cada patch panel

### Patch Panel 1 (24 ports màx.)

**Ús:** VMs + Departament d'Informàtica + Administració  
**Enllaç:** Switch Cisco

| Port | Connectat a |
|------|-------------|
| 1 | VM — SRV-DC01 |
| 2 | VM — SRV-DC02 |
| 3 | VM — SRV-APP01 |
| 4 | VM — SRV-DAD01 |
| 5 | VM — SRV-NAS01 |
| 6 | VM — SRV-WEB |
| 7 | Informàtica |
| 8 | Gerència i administració |
| 9 | Recepció |
| 10–24 | Reserva |

### Patch Panel 2 (24 ports màx.)

**Ús:** Departaments connectats al TP-Link 16 ports  
**Enllaç:** Switch TP-Link 16p

| Port | Connectat a |
|------|-------------|
| 1 | Vigilància |
| 2 | Comercial |
| 3 | Producció |
| 4 | Magatzem |
| 5–24 | Reserva |

### Notes d'organització

El Patch Panel 1 concentra els serveis crítics (VMs + IT + Administració) i enllaça amb el Switch Cisco. El Patch Panel 2 agrupa els departaments distribuïts i connecta amb el TP-Link 16 ports. Es deixen ports lliures en tots dos patch panels per a escalabilitat futura.

---

## 4. Estructura del rack

| Unitats | Element |
|---------|---------|
| 0–7 | Lliure |
| 8–13 | Servidors |
| 14–16 | Lliure |
| 17 | Switch D-Link (NO configurable) |
| 18–21 | Lliure |
| 22 | Patch Panel Edifici 1 |
| 23–26 | Lliure |
| 27 | Switch Cisco |
| 28–29 | Lliure |
| 30 | Patch Panel Edifici 2 |
| 31–32 | Lliure |
| 33 | Switch TP-Link (16 ports) |
| 34–42 | Lliure |
