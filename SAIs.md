# Configuración de apagado de maquinas en el SAI 

## Leyenda que vms contienen cada servidor físico

### Servidor fisico 1 (SRV-F01)

SRV-DC01
SRV-DAD01

### Servidor fisico 2 (SRV-F02) 

SRV-DC02
SRV-MON01
SRV-APP01

### Servidor fisico 3 (SRV-F03) 

SRV-NAS01
SRV-WEB-DMZ


## Orden de apagado

**1 es el primero en apagarse**

1. SRV-F02
1. SRV-F03
1. SRV-F01

