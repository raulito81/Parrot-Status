---
name: check
description: Compila Parrot Status en Release y comprueba que no hay errores ni avisos y que el .app sale bien (arquitectura, Info.plist, versión, firma, hardened runtime y permiso de Bluetooth). Úsala antes de mezclar una rama, al cerrar una versión o cuando el usuario pida comprobar que compila.
---

# Comprobar Parrot Status

## 1. Compilar

```bash
xcodebuild -project "Parrot Status.xcodeproj" -scheme "Parrot Status" -configuration Release -derivedDataPath build build 2>&1 | grep -E '^/.*(error|warning):|BUILD' | sort -u
```

- Tiene que acabar en `** BUILD SUCCEEDED **` y **sin ningún `warning:`**. Si aparece alguno nuevo, corrígelo (APIs obsoletas, conversiones…) o enséñalo al usuario si no está claro cómo.
- Si falla, enseña el error concreto y para.

## 2. Comprobar el .app

Con `APP="build/Build/Products/Release/Parrot Status.app"`:

| Qué | Comando | Esperado |
|---|---|---|
| Arquitectura | `lipo -archs "$APP/Contents/MacOS/Parrot Status"` | `arm64` (o `arm64 x86_64`) |
| Versión | `plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist"` y `CFBundleVersion` | la de `Parrot Status/Info.plist` |
| Identificador | `plutil -extract CFBundleIdentifier raw …` | `org.killerdemouches.Parrot-Status` |
| Sistema mínimo | `plutil -extract LSMinimumSystemVersion raw …` | `13.0` |
| Texto de Bluetooth | `plutil -extract NSBluetoothAlwaysUsageDescription raw …` | no vacío |
| Firma | `codesign --verify --strict "$APP" && codesign -dv "$APP" 2>&1 \| grep flags` | sin error, `flags=…(adhoc,runtime)` |
| Permiso de Bluetooth | `codesign -d --entitlements - "$APP" 2>&1 \| grep bluetooth` | `com.apple.security.device.bluetooth` |

Si falta el texto o el permiso de Bluetooth, la app no podrá hablar con los cascos: es un fallo, no un aviso.

## 3. Revisar el código cambiado

- `git diff main...HEAD -- "Parrot Status"` y los cambios sin commit.
- Que no vuelvan a aparecer `NSAssert` en el camino del Bluetooth (cierran la app en Debug): los errores se registran con `NSLog`.
- Si se añade una opción al menú que se guarda, que tenga su valor por defecto en `registerDefaults` (`+initialize`).

## 4. Resumen

Di qué se ha comprobado y el resultado de cada punto. Recuerda que esto no prueba la conexión con los cascos: para eso, `/build`.
