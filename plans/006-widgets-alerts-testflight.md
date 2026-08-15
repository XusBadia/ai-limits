# Plan 006: Añadir widgets, alertas y preparar TestFlight

> **Instrucciones para el ejecutor**: los widgets leen el App Group y usan timelines; no hacen polling agresivo ni llaman a providers. Las notificaciones deben derivarse de snapshots nuevos y ser idempotentes.

## Estado

- **Prioridad**: P1
- **Esfuerzo**: L (5–8 días)
- **Riesgo**: MED
- **Depende de**: 004, 005
- **Categoría**: direction / tests / docs
- **Planificado**: sin commit base, 2026-08-15

## Objetivo

Completar una beta distribuible con widgets, alertas útiles, privacidad y observabilidad segura. La app debe superar uso real con Mac dormido, iCloud lento, endpoints rotos y presupuestos de actualización de WidgetKit.

## Widgets v1

- **Compacto**: proveedor elegido, porcentaje restante más urgente y reset.
- **Mediano**: sesión + semanal o dos proveedores.
- **Lista**: tres proveedores ordenados por urgencia.

WidgetKit lee el último snapshot desde el App Group. Genera entradas futuras solo para textos previsibles de countdown/reset y pide una nueva timeline con intervalos conservadores. El porcentaje no cambia sin snapshot nuevo.

## Alertas v1

- Umbral configurable de consumo (por defecto 80% y 95%).
- Riesgo de agotar antes del reset cuando el pace sea calculable.
- “El collector lleva demasiado tiempo sin actualizar” como alerta opcional, no repetitiva.
- Reset ocurrido: limpiar deduplicación de la ventana anterior.

La clave idempotente debe incluir provider, account opaca, kind de ventana, `resetAt` y umbral. No enviar una alerta por cada refresh.

## Pasos

### 1. Implementar snapshot de App Group para widgets

Escribir un payload reducido y versionado después de actualizar el repositorio local. Hacer escritura atómica y limitar tamaño. El widget muestra un fallback claro si no hay datos o son antiguos.

**Verificar**: tests cubren no snapshot, corrupción, schema futuro, stale, múltiples providers y límite de tamaño.

### 2. Construir timelines eficientes

Calcular entradas de countdown sin red y solicitar reload solo cuando cambie el payload visible. No asumir periodicidad exacta: WidgetKit administra un presupuesto diario.

**Verificar**: para 24 horas, el timeline no genera entradas más frecuentes de lo necesario; tests prueban reset, cambio de día, DST y widget no visible.

### 3. Añadir motor de alertas

Implementar evaluador puro + store de deduplicación. Pedir permiso de notificaciones después de que el usuario active una regla, no durante la primera apertura. No incluir email ni gasto detallado en la pantalla bloqueada por defecto.

**Verificar**: tests demuestran exactamente una alerta por umbral/ventana, rearme después de reset y ninguna alerta con snapshot stale.

### 4. Privacidad y control del usuario

Añadir política de privacidad, App Privacy manifest, exportación JSON, eliminación de CloudKit, borrado de claves locales, opt-out de analytics y explicación de cada fuente. Si se añade crash reporting, enviar solo stack y categorías, sin snapshots ni identidad.

**Verificar**: export contiene métricas permitidas; delete elimina records y cachés; un escaneo de logs no encuentra secretos ni emails.

### 5. Beta y release gates

Crear test matrix: iOS mínimo soportado/actual, Mac mínimo/actual, Intel si se distribuye universal, iCloud on/off, cuenta nueva/existente, modo offline, Mac dormido, 5 providers y proveedor roto. Distribuir primero companion firmado/notarizado y app iOS por TestFlight.

**Verificar**: checklist firmado por al menos 5 testers durante 7 días; cero crash blocker; métricas de éxito definidas abajo.

## Métricas de beta

- Tiempo onboarding -> primer snapshot.
- Porcentaje de usuarios con collector visto en 10 minutos.
- Edad mediana/p95 de snapshots cuando se abre iOS.
- Éxito de refresh por provider usando solo categorías sin PII.
- Ratio de alertas duplicadas (objetivo 0).

## Comandos de release

Definir en CI una vez existan schemes reales:

```sh
swift test --package-path Packages/AILimitsCore
swift test --package-path Packages/AILimitsCollectors
swift test --package-path Packages/AILimitsSync
xcodebuild -scheme AILimits-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -scheme AILimits-macOS -destination 'platform=macOS' test
xcodebuild -scheme AILimitsWidgets -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Criterios de terminado

- [ ] Widgets muestran caché correcta y explican stale/no data.
- [ ] Alertas son configurables, idempotentes y respetan permisos.
- [ ] Export/delete funciona para datos locales y CloudKit.
- [ ] Privacy manifest y App Store privacy answers coinciden con el binario real.
- [ ] Companion firmado/notarizado y build TestFlight pasan revisión interna.
- [ ] La beta de 7 días cumple los gates o documenta blockers antes de App Store.

## Condiciones STOP

- El widget necesita polling de cinco minutos o acceso directo a credenciales.
- Una notificación puede mostrar PII en lock screen sin opt-in explícito.
- La declaración de privacidad no puede reconciliarse con analytics/crash SDKs incluidos.
- App Review o términos de un proveedor cuestionan un endpoint interno: desactivar ese provider y revisar antes de enviar.

## Notas de mantenimiento

La distribución macOS y la app iOS tienen ciclos distintos; el esquema compartido debe permitir que versiones N y N-1 convivan. Mantener feature flags por provider para poder responder a cambios de autenticación sin bloquear toda la app.

