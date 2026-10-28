# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Parrot Status**: app de la barra de menús de macOS para los cascos Parrot Zik (1 y 2): batería, cancelación de ruido, conexión automática, modos Lou Reed y Concert Hall, y avisos de batería baja. Es un fork de [vincent-le-normand/Parrot-Status](https://github.com/vincent-le-normand/Parrot-Status) (2014), puesto al día para el macOS actual en la 1.0.0. El código, el README y el CHANGELOG están en inglés; los commits y estas notas, en español.

## Comandos

```bash
xcodebuild -project "Parrot Status.xcodeproj" -scheme "Parrot Status" -configuration Release -derivedDataPath build build
cp -R "build/Build/Products/Release/Parrot Status.app" /Applications/
open "/Applications/Parrot Status.app"
```

`build/` está en `.gitignore`. No hay tests útiles (`Parrot StatusTests` es la plantilla vacía de Xcode): la prueba es instalarla y usarla con los cascos (skill `/build`).

## Arquitectura

- **Todo está en `Parrot Status/AppDelegate.m`** (Objective-C, ARC). `MainMenu.xib` solo aporta el menú principal y la ventana de niveles de aviso de batería (`advancedBatteryWindow`, con un `NSTokenField`).
- **Bluetooth:** `IOBluetoothDevice registerForConnectNotifications` → busca el servicio SDP con el UUID del Zik 1 (`0ef0f502-…`) o del Zik 2 (`8b6814d3-…`) → abre el canal RFCOMM → envía `{0x00,0x03,0x00}` y espera `{0x00,0x03,0x02}`.
- **Protocolo:** peticiones `GET /api/...` y `SET /api/...?arg=` con cabecera de 3 bytes (longitud + `0x80`); las respuestas son XML (`<answer path="...">`) a partir del byte 7. Las notificaciones (`<notify path="...">`) se responden pidiendo ese `path` con `GET`. El Zik 2 usa atributos distintos (`percent` en vez de `level`, `sip6` en vez de `version`).
- **Opciones según el modelo:** `supportedPaths` guarda las rutas `GET` que los cascos han contestado sin `error="true"`; las opciones añadidas en la 1.1.0 (llamadas, ecualizador, sala y ángulo, pausa al quitarlos, apagado automático) solo salen en el menú si su ruta está ahí. Valores que acepta el Zik 1 (firmware 1.10): preajustes 0–6, sala `silent|living|jazz|concert`, ángulo 30–180 de 30 en 30, apagado `0|5|10|15|30|60`.
- **Diagnóstico:** `open -a "Parrot Status" --args -ProbeAPI YES [-ProbeRequests '("GET …", "SET …")']` pregunta a los cascos (una petición cada 0,5 s) y guarda paquetes y respuestas en `~/Library/Logs/Parrot Status/probe.log`. El log unificado no sirve: macOS oculta los valores como `<private>`. En `zsh` usa `/usr/bin/log`, porque `log` es un comando interno. Sirve para comprobar una ruta nueva antes de ponerla en el menú: no te inventes rutas ni valores.
- **Paquetes:** cada mensaje empieza por su longitud total (UInt16 big-endian) y un paquete RFCOMM puede traer varios: `rfcommChannelData:` los separa y `handleMessage:` trata cada uno.
- **Ajustes** en `NSUserDefaults` (`registerDefaults` en `+initialize`).
- **Sistema:** inicio de sesión con `SMAppService` (activado la primera vez, opción "Open at login" en el menú), avisos con `UserNotifications`, la tecla Opción cambia una opción del menú por otra con `NSMenuItem.alternate`.

## Requisitos de macOS (no los quites)

- `MACOSX_DEPLOYMENT_TARGET = 13.0` (por `SMAppService`).
- `NSBluetoothAlwaysUsageDescription` en `Info.plist` y `com.apple.security.device.bluetooth` en `Parrot Status.entitlements`, con hardened runtime: sin ellos macOS no deja usar el Bluetooth.
- Firma ad hoc (`CODE_SIGN_IDENTITY = "-"`): no hay cuenta de desarrollador. Si cambia el binario, macOS puede volver a pedir el permiso de Bluetooth.
- `PRODUCT_BUNDLE_IDENTIFIER = org.killerdemouches.Parrot-Status` (el original): cambiarlo pierde los ajustes y los permisos ya concedidos.
- No hay Sparkle ni actualizaciones automáticas: se quitaron en la 1.0.0.

## Git y versiones

- **Todo cambio va en una rama** (`feat/…`, `fix/…`, `docs/…`), nunca directamente en `main`. Antes de mezclar con `main` se revisan README, `CHANGELOG.md` y la versión; **si hay dudas, se pregunta**. Proceso completo: skill `/release`.
- Identidad personal: `Raul Maroto <raulmaroto@gmail.com>`, configurada en el repo (`git config user.email`). Compruébala antes de commitear: la global es la del trabajo.
- **Versión** en `Parrot Status/Info.plist`: `CFBundleShortVersionString` (X.Y.Z) y `CFBundleVersion` (build, +1 en cada versión, nunca se reinicia). Minor para funcionalidad nueva, patch para correcciones. Las etiquetas siguen el formato del repo, sin `v` (`0.9.6`, `1.0.0`). Cambios solo de documentación interna (`CLAUDE.md`, `.claude/`) no llevan versión.
- **Remotos:** `origin` es el fork personal (`git@github-personal:raulito81/Parrot-Status.git`); `upstream` es el original de `vincent-le-normand`, abandonado: no se sube nada ahí.

## Skills

- `/check`: compila en Release sin avisos y comprueba el `.app` (arquitectura, `Info.plist`, firma y permisos).
- `/build`: compila, instala en `/Applications` y abre la app para probarla con los cascos.
- `/release`: cerrar una versión y mezclar con `main`.
