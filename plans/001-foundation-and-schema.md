# Plan 001: Crear la base multiplataforma y congelar el esquema v1

> **Instrucciones para el ejecutor**: sigue cada paso y confirma sus verificaciones. Este repositorio no tenía Git ni archivos al redactar el plan. Si ahora contiene código no creado por este plan, detente y reconcilia la estructura con el responsable antes de sobrescribir nada.

## Estado

- **Prioridad**: P0
- **Esfuerzo**: M (2–3 días)
- **Riesgo**: MED
- **Depende de**: ninguno
- **Categoría**: direction / dx
- **Planificado**: sin commit base; repositorio vacío, 2026-08-15

## Objetivo

Crear un workspace reproducible para iOS y macOS y un paquete Swift puro que defina el contrato de snapshots. Ningún tipo del core puede importar AppKit, UIKit, CloudKit, Security o WidgetKit. Ese aislamiento permite probar modelos, migraciones y reglas de frescura con `swift test` sin arrancar una app.

## Precondiciones

- Instalar Xcode completo y seleccionarlo con `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. Al redactar el plan solo estaban activas las Command Line Tools y `xcodebuild` no funcionaba.
- Tener un Apple Developer Team para firmar macOS, iOS, App Groups e iCloud.
- Elegir antes de generar el proyecto: nombre comercial, reverse-DNS propio, Team ID, bundle IDs e iCloud container. No publicar con identificadores de los proyectos upstream.

## Estructura a crear

```text
project.yml
Config/
  Shared.xcconfig
  Debug.xcconfig
  Release.xcconfig
  AILimits.entitlements
  AILimitsMac.entitlements
  AILimitsWidgets.entitlements
Apps/
  iOS/
  macOS/
  Widgets/
Packages/
  AILimitsCore/
    Package.swift
    Sources/AILimitsCore/
    Tests/AILimitsCoreTests/
ThirdPartyNotices/
```

Usar XcodeGen y mantener `project.yml` como fuente de verdad. No versionar un `.xcodeproj` generado salvo que el equipo decida explícitamente abandonar XcodeGen.

## Tipos y protocolos obligatorios

En `Packages/AILimitsCore/Sources/AILimitsCore/Models/`:

- `SnapshotEnvelope`: `schemaVersion`, `generatedAt`, `collectorDeviceID`, `collectorVersion`, `[ProviderSnapshot]`.
- `ProviderSnapshot`: `id`, `accountID` opaco, `displayName`, `plan`, `source`, `windows`, `balances`, `spend`, `history`, `updatedAt`, `error`.
- `UsageWindow`: `kind`, `label`, `used`, `limit`, `unit`, `resetsAt`, `periodSeconds`. El porcentaje se calcula, no se persiste dos veces.
- `ProviderError`: categoría estable (`authRequired`, `permissionDenied`, `rateLimited`, `network`, `parse`, `unsupported`, `unknown`), mensaje seguro y `lastSuccessfulAt`.
- `Freshness`: función pura que devuelve `fresh`, `aging` o `stale` usando `updatedAt` y un TTL explícito.

En `Protocols/`:

- `UsageCollecting`: `providerID`, `availability()` y `collect() async -> ProviderSnapshot`.
- `SnapshotStore`: leer último snapshot y escribir de forma atómica.
- `SnapshotSyncing`: subir, descargar y observar cambios sin conocer CloudKit.
- `Clock` inyectable para tests de resets, pace y frescura.

Todos los tipos de dominio deben ser `Codable`, `Hashable` y `Sendable`. Usar Swift 6 strict concurrency.

## Pasos

### 1. Inicializar repositorio y herramientas

Inicializar Git, añadir `.gitignore`, `.editorconfig`, `README.md` y `AGENTS.md`. Declarar en `AGENTS.md` los comandos exactos de build/test, la regla de no sincronizar secretos y la obligación de añadir fixtures sanitizados para cada parser.

**Verificar**: `git status --short` solo lista los archivos nuevos esperados; `xcodebuild -version` y `swift --version` terminan con código 0.

### 2. Crear el paquete core

Crear el paquete Swift con los modelos y protocolos anteriores. Añadir decodificación tolerante a campos futuros, pero rechazar `schemaVersion` mayor que la soportada con un error tipado.

**Verificar**: `swift test --package-path Packages/AILimitsCore` termina con código 0.

### 3. Añadir fixtures y tests de contrato

Crear fixtures JSON para: snapshot completo, proveedor parcial, error con último dato bueno, fecha de reset ausente y esquema futuro. Probar round-trip Codable, división por cero, valores negativos rechazados, fechas ISO-8601 y transición de frescura con reloj fijo.

**Verificar**: `swift test --package-path Packages/AILimitsCore --filter AILimitsCoreTests` pasa todos los tests y no realiza red.

### 4. Generar los hosts mínimos

Crear shells compilables para la app iOS, el companion macOS y WidgetKit. En esta fase solo deben mostrar una vista “Foundation ready” alimentada por un fixture compartido. Configurar un App Group común y el mismo CloudKit container en los dos hosts, aunque CloudKit se implemente en 003.

**Verificar**:

```sh
xcodegen generate
xcodebuild -scheme AILimits-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme AILimits-macOS -destination 'platform=macOS' build
```

Ambos comandos terminan con `** BUILD SUCCEEDED **`.

## Pruebas requeridas

- Al menos 10 tests unitarios del core.
- Ningún test usa la fecha real, red o iCloud.
- `rg 'import (AppKit|UIKit|CloudKit|Security|WidgetKit)' Packages/AILimitsCore` no devuelve coincidencias.
- `rg -i '(access.?token|refresh.?token|cookie|authorization)' Packages/AILimitsCore/Tests/Fixtures` no encuentra valores sensibles reales.

## Criterios de terminado

- [ ] `swift test --package-path Packages/AILimitsCore` pasa.
- [ ] Los hosts iOS y macOS compilan con Xcode.
- [ ] El esquema v1 y su política de migración están documentados en `docs/snapshot-schema-v1.md`.
- [ ] No existen dependencias de plataforma dentro de `AILimitsCore`.
- [ ] Bundle IDs, App Group e iCloud container pertenecen al usuario, no a upstream.
- [ ] Estado de este plan actualizado en `plans/README.md`.

## Condiciones STOP

- No hay Team ID o no se ha decidido el reverse-DNS/bundle ID.
- El iPhone de prueba y el Mac no pueden firmarse con un mismo container de iCloud.
- XcodeGen no puede generar ambos targets sin editar manualmente el proyecto generado.
- Se propone añadir credenciales o respuestas crudas al contrato core.

## Notas de mantenimiento

El esquema es la frontera de compatibilidad. Los collectors pueden cambiar con frecuencia; la app iOS no. Toda ampliación debe ser aditiva dentro de v1 o introducir un migrador y una nueva versión explícita.

