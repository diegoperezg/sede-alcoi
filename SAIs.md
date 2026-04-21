SAI (UPS) — Configuració d'apagada de màquines
Projecte Integrador ASIX · CPD / Planta 1 · Edifici 1
1. Equips connectats al SAI
El SAI protegeix els equips crítics del CPD ubicats al Rack RP1-E1 de la Planta 1 de l'Edifici 1. Els equips connectats son els següents:

Equip
Tipus
Funció
Cisco Catalyst 4948 (SW EDIF.2)
Switch L3
Distribució de campus, inter-VLAN, uplinks als dos edificis
SRV-F01 — Servidor físic 1
Servidor
Allotja SRV-DC01 i SRV-DAD01
SRV-F02 — Servidor físic 2
Servidor
Allotja SRV-DC02, SRV-MON01 i SRV-APP01
SRV-F03 — Servidor físic 3
Servidor
Allotja SRV-NAS01 i SRV-WEB-DMZ
D-Link DES-3526 + SAN/NAS Storage
Switch SAN + Emmagatzematge
Interconnexió i emmagatzematge centralitzat del CPD

2. Correspondència de VMs per servidor físic
Cada servidor físic allotja les següents màquines virtuals (VMs):

Servidor físic
Màquines virtuals (VMs)
Rol de les VMs
SRV-F01 (Servidor físic 1)
SRV-DC01
SRV-DAD01
SRV-DC01: Controlador de domini primari (Active Directory)
SRV-DAD01: Servidor de dades principal
SRV-F02 (Servidor físic 2)
SRV-DC02
SRV-MON01
SRV-APP01
SRV-DC02: Controlador de domini secundari (rèplica)
SRV-MON01: Monitoratge de la infraestructura
SRV-APP01: Servidor d'aplicacions
SRV-F03 (Servidor físic 3)
SRV-NAS01
SRV-WEB-DMZ
SRV-NAS01: Servidor NAS virtual (emmagatzematge en xarxa)
SRV-WEB-DMZ: Servidor web en zona desmilitaritzada (DMZ)

3. Funcionament del SAI en cas de tall elèctric
3.1 Commutació immediata a bateria
En el moment en que el SAI detecta la pèrdua de subministrament elèctric, commuta automàticament a bateria en menys de 10 ms (mode online doble conversió). Els equips connectats no experimenten cap interrupció de servei en aquest primer instant.

3.2 Notificació als servidors i inici de l'apagada
Si el tall es perllonga més del llindar configurat (per exemple, 2 minuts), el SAI envia una senyal d'avís als servidors a través del protocol NUT (Network UPS Tools) via USB o SNMP. Cada servidor físic rep l'ordre d'apagar les seves màquines virtuals de manera ordenada i, finalment, aturar-se ell mateix abans que la bateria s'esgoti.

4. Ordre d'apagada dels servidors físics
L'ordre d'apagada s'ha dissenyat per preservar els serveis crítics (directori actiu i emmagatzematge) el màxim temps possible, minimitzant el risc de corrupció de dades:

Ordre
Servidor físic
VMs que conté
Justificació
1r (primer)
SRV-F02
SRV-DC02
SRV-MON01
SRV-APP01
SRV-DC02 és el controlador de domini de rèplica, no el primari. El seu apagat no interromp l'autenticació mentre SRV-F01 segueixi actiu. SRV-MON01 i SRV-APP01 no son crítics per a la persistència de dades.
2n
SRV-F03
SRV-NAS01
SRV-WEB-DMZ
S'apaga després de SRV-F02 per garantir que totes les operacions d'escriptura pendents als volums del NAS hagin finalitzat. SRV-NAS01 fa el desmuntatge correcte dels volums compartits abans d'aturar-se.
3r (últim)
SRV-F01
SRV-DC01
SRV-DAD01
Es manté actiu fins al final perquè conté el controlador de domini primari (SRV-DC01). Tots els altres servidors el necessiten per autenticar-se i accedir als recursos durant el procés d'apagada. S'apaga el darrer, just abans que el SAI talli l'alimentació.





5. Ordre d'arrencada en la recuperació
Quan el subministrament elèctric es restableix, els equips s'encenen en ordre invers per garantir que cada servei estigui disponible abans que el servidor que en depèn s'iniciï:

    1. Cisco Catalyst 4948 — La xarxa ha d'estar operativa abans que cap servidor intenti comunicar-se.
    2. SRV-F01 (SRV-DC01 + SRV-DAD01) — El controlador de domini primari ha d'estar disponible abans que els altres servidors intentin autenticar-se.
    3. SRV-F03 (SRV-NAS01 + SRV-WEB-DMZ) — El NAS munta els volums i els posa a disposició dels servidors d'aplicacions.
    4. SRV-F02 (SRV-DC02 + SRV-MON01 + SRV-APP01) — Finalment s'inicien els serveis secundaris, el monitoratge i les aplicacions.
