# MageTrinketTracker

**Versión 2.5.0 | World of Warcraft 3.3.5a**

MageTrinketTracker es un addon para facilitar el seguimiento de los abalorios de los magos del grupo o banda y ayudar a coordinar el uso de **Infusión de poder (PI)**.

## Características

- Muestra los dos abalorios equipados por cada mago detectado.
- Indica cuándo se activan determinados efectos y estima sus tiempos de reutilización internos.
- Notifica las activaciones reconocidas en el chat local, sin enviar mensajes a la banda.
- Incorpora un botón de **PI** junto a cada mago para lanzar el hechizo directamente, cuando esté disponible y se cumplan sus condiciones de uso.
- Señala en rojo el botón de PI cuando no está disponible.
- Permite mostrar, ocultar y bloquear la ventana; recuerda su estado de visibilidad al volver a entrar.

**Nota:** El seguimiento está limitado a los abalorios incluidos en el código. Los tiempos de reutilización internos son estimaciones.

## Desarrollo

Desarrollado en **Lua** mediante la API de World of Warcraft 3.3.5a. Utiliza inspección de equipo, eventos de combate y una interfaz compacta con botones seguros para lanzar hechizos.

## Instalación desde GitHub

1. Descarga el ZIP del repositorio y descomprímelo.
2. Si la carpeta extraída tiene un sufijo como `-main`, `-2.5.0` o similar, elimínalo para que se llame **`MageTrinketTracker`**.
3. Comprueba que `MageTrinketTracker.lua` y `MageTrinketTracker.toc` estén directamente dentro de esa carpeta, sin carpetas intermedias.
4. Copia `MageTrinketTracker` a `World of Warcraft/Interface/AddOns/`.
5. Activa el addon desde el menú **Complementos** del juego.

## Comandos

| Comando | Acción |
|---|---|
| `/mtt` | Mostrar u ocultar la ventana |
| `/mtt show` | Mostrar |
| `/mtt hide` | Ocultar |
| `/mtt lock` | Bloquear o desbloquear la ventana |
| `/mtt scan` | Solicitar una nueva inspección |
| `/mtt reset` | Reiniciar los datos de seguimiento |

---

*Proyecto independiente, no afiliado a Blizzard Entertainment. World of Warcraft es una marca de Blizzard Entertainment.*
