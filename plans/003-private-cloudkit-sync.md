# Plan 003: Sincronizar snapshots mediante CloudKit privado

> **Instrucciones para el ejecutor**: CloudKit transporta métricas normalizadas, nunca credenciales. Implementa primero una capa `SnapshotSyncing` con fake store; después el adaptador real. No uses la base pública ni compartida.

## Estado

- **Prioridad**: P0
- **Esfuerzo**: M (4–6 días)
- **Riesgo**: MED
- **Depende de**: 001, 002
- **Categoría**: direction / security
- **Planificado**: sin commit base, 2026-08-15

## Objetivo

Un snapshot producido en el Mac debe aparecer en un iPhone del mismo usuario de iCloud, sin cuenta propia ni backend, con conflictos y desconexiones bien definidos. El transporte usa un custom zone dentro de `privateCloudDatabase` y mantiene un caché local para arranque instantáneo y widgets.

## Modelo CloudKit v1

- Zone: `AILimitsPrivateV1`.
- `CollectorDevice`: ID aleatorio, nombre opcional elegido por el usuario, versión, `lastSeenAt`.
- `CurrentProviderSnapshot`: record ID determinista `<deviceID>:<providerID>:<accountID>`, payload normalizado, `updatedAt`, `schemaVersion`, checksum.
- `DailyAggregate`: ID `<deviceID>:<providerID>:<accountID>:<yyyy-mm-dd>`, tokens/coste normalizados; retención v1 de 90 días.

No guardar email real por defecto. `accountID` debe ser un identificador opaco estable generado en el Mac. Si se ofrece una etiqueta de cuenta, será opt-in y se almacenará en un campo cifrado de CloudKit o dentro de payload cifrado por el cliente.

## Pasos

### 1. Implementar repositorio local compartido

Crear `Packages/AILimitsSync` con un `FileSnapshotStore` actor que escriba JSON de forma atómica en el App Group. Tanto iOS como WidgetKit leen esa copia; CloudKit nunca se consulta desde una vista.

**Verificar**: tests cubren primera carga, reemplazo atómico, archivo truncado, checksum incorrecto, migración y lectura concurrente.

### 2. Implementar CloudKit detrás del protocolo

Crear `CloudKitSnapshotSync` usando `CKSyncEngine` o el API moderno equivalente disponible en el deployment target. Mantener tokens de cambio por zone, reintentos con backoff, soporte offline y merge por `updatedAt` con desempate determinista por checksum.

**Verificar**: una implementación fake reproduce alta, modificación, borrado, conflicto y error `notAuthenticated`; todos los tests pasan sin iCloud real.

### 3. Publicar desde el Mac

Después de cada refresh batch, comparar checksum con lo publicado y subir solo cambios o un heartbeat cada 15 minutos. Borrar records cuando el usuario desactive sync o elimine un dispositivo desde Settings. No despertar el Mac desde el iPhone en v1.

**Verificar**: 20 refreshes con métricas idénticas generan una sola escritura de datos y los heartbeats esperados, no 20 uploads completos.

### 4. Consumir desde iOS

Al abrir la app: pintar caché, consultar cambios y actualizar caché. Registrar una suscripción silenciosa de CloudKit como acelerador, sin depender de que siempre llegue. Añadir `BGAppRefreshTask` como fallback oportunista.

**Verificar**: con push y background desactivados, abrir la app sigue descargando el snapshot correcto; con red cortada se conserva caché y cambia a `offline/stale`.

### 5. Validar una vertical en dispositivos reales

Usar un container de desarrollo con Mac e iPhone físicos firmados por el mismo Team. Probar mismo Apple ID, Apple IDs distintos, iCloud desactivado, red interrumpida, Mac dormido y reinstalación de iOS.

**Verificar**: una modificación de fixture en Mac llega al iPhone y nunca aparece en la cuenta iCloud de otro tester.

## Comandos

```sh
swift test --package-path Packages/AILimitsSync
xcodebuild -scheme AILimits-macOS -destination 'platform=macOS' test
xcodebuild -scheme AILimits-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Todos deben terminar con éxito. La validación CloudKit real requiere dispositivos firmados y se documentará como checklist manual reproducible.

## Criterios de terminado

- [ ] El Mac publica solo datos incluidos en el esquema permitido.
- [ ] El iPhone arranca desde caché y converge con CloudKit.
- [ ] La base usada es privada; no hay records públicos.
- [ ] iCloud desactivado produce una explicación accionable, no pérdida de datos local.
- [ ] Los conflictos tienen resultado determinista y están testeados.
- [ ] Existe exportación y borrado de todos los records del usuario.
- [ ] El sync no contiene secretos, respuestas crudas ni rutas locales.

## Condiciones STOP

- Los targets no pueden firmar el mismo iCloud container.
- Una necesidad de UX obliga a guardar token, cookie o refresh token en CloudKit.
- El diseño depende de entrega inmediata de push/background.
- El merge puede hacer retroceder silenciosamente a un snapshot más antiguo.

## Notas de mantenimiento

La base privada pertenece al usuario y cuenta contra su cuota. Mantener payloads pequeños, borrar devices inactivos y ofrecer export/delete. Si más adelante se necesita Android o compartir con familia/equipo, eso requiere una decisión de producto separada sobre backend o shared database.

