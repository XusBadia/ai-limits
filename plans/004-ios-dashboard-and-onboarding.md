# Plan 004: Construir el dashboard iOS y su onboarding

> **Instrucciones para el ejecutor**: toda pantalla debe funcionar con fixtures y con el repositorio local; ninguna vista llama directamente a CloudKit o a un proveedor. La antigüedad de los datos es parte del producto y nunca debe ocultarse.

## Estado

- **Prioridad**: P0
- **Esfuerzo**: L (7–10 días)
- **Riesgo**: MED
- **Depende de**: 001, 003
- **Categoría**: direction
- **Planificado**: sin commit base, 2026-08-15

## Objetivo

Entregar una app iOS útil con Codex y Claude: onboarding del companion, resumen priorizado, detalle por proveedor, historial y diagnóstico de sincronización. Debe ser accesible, localizarse inicialmente en español e inglés y representar correctamente datos parciales, antiguos o ausentes.

## Flujo de usuario

1. La primera apertura explica que el iPhone muestra métricas recogidas en un Mac y que no recibe credenciales.
2. Si no hay collector, ofrece enlace/QR de instalación e instrucciones para iniciar el companion con el mismo iCloud.
3. Cuando aparece `CollectorDevice`, enseña la lista de proveedores detectados y permite elegir cuáles mostrar.
4. La home ordena primero el límite más urgente: menor porcentaje restante ajustado por tiempo hasta reset.
5. Pull-to-refresh descarga CloudKit; no promete despertar ni refrescar el Mac.

## Pantallas v1

- **Onboarding**: privacidad, instalación del companion, iCloud, espera/diagnóstico.
- **Dashboard**: tarjeta resumen por proveedor con sesión, semanal, reset y frescura.
- **Detalle**: todas las ventanas, pace, balances, gasto, gráfica diaria, fuente y última actualización.
- **Dispositivos**: collectors conocidos, última conexión, renombrar/eliminar.
- **Ajustes**: orden, métricas visibles, unidades, umbrales, privacidad y export/delete.

## Pasos

### 1. Crear el store de presentación

Implementar `DashboardStore` en `@MainActor` que observe `SnapshotStore`, produzca view models inmutables y calcule orden/urgencia mediante funciones puras del core. No usar strings renderizados como fuente de lógica.

**Verificar**: tests prueban orden con session vs weekly, empate, dato sin reset, proveedor en error, snapshot stale y múltiples devices.

### 2. Implementar onboarding completo

Modelar estados explícitos: `needsICloud`, `needsCompanion`, `waitingForFirstSnapshot`, `ready`, `syncError`. Permitir entrar en modo demo con fixtures y volver a onboarding desde Settings.

**Verificar**: UI tests recorren cada estado con launch arguments; ningún estado deja una pantalla vacía o un spinner infinito.

### 3. Construir dashboard y detalle

Usar SwiftUI nativo, Dynamic Type, VoiceOver, contraste suficiente y Reduce Motion. Las barras deben tener etiqueta textual, no comunicar solo por color. Mostrar `Actualizado hace…` en home y timestamp absoluto/fuente en detalle. Cuando un dato esté viejo, conservarlo visualmente pero añadir estado `Desactualizado`.

**Verificar**: snapshot tests en light/dark, texto XXL, español/inglés, cero datos, datos parciales, error y stale.

### 4. Añadir gráficas y pace

Usar Swift Charts. Pace compara consumo transcurrido y cuota usada, sin predecir cuando faltan duración o inicio fiables. Las proyecciones deben etiquetarse como estimaciones.

**Verificar**: tests con reloj fijo cubren antes/después del reset, ventana todavía no iniciada, 0%, 100%, timezone y DST.

### 5. Integrar refresh y diagnóstico

Pull-to-refresh ejecuta `syncNow()`, actualiza caché y muestra el resultado. Settings debe diferenciar: iCloud sin sesión, sin red, Mac no visto, collector antiguo, provider auth requerida y parser roto.

**Verificar**: UI tests comprueban copy y acción recomendada para cada categoría.

## Copy mínimo obligatorio

- “Actualiza los datos desde iCloud. El Mac recoge los límites de cada proveedor.”
- “El Mac lleva X sin enviar datos. Los valores pueden haber cambiado.”
- “Tus credenciales permanecen en el Mac. Solo se sincronizan porcentajes, saldos, gasto y fechas de reinicio.”
- No usar “en directo” salvo que `updatedAt` esté dentro del umbral fresh.

## Comandos

```sh
swift test --package-path Packages/AILimitsCore
xcodebuild -scheme AILimits-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -scheme AILimits-iOS -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' test
```

## Criterios de terminado

- [ ] Un usuario nuevo entiende por qué necesita el companion y cómo conectarlo.
- [ ] Codex y Claude se muestran con cuotas, resets y frescura correctos.
- [ ] Todos los estados vacíos, parciales, stale y error tienen UI y copy propios.
- [ ] VoiceOver y Dynamic Type XXL son utilizables.
- [ ] La app abre desde caché sin red.
- [ ] Pull-to-refresh no afirma haber refrescado el proveedor si solo leyó CloudKit.
- [ ] Tests unitarios, UI y snapshots pasan.

## Condiciones STOP

- La UI necesita leer tipos o payloads específicos de Codex/Claude en vez del contrato común.
- Se propone esconder `updatedAt` para que el producto parezca más inmediato.
- La navegación no funciona con VoiceOver o tamaño XXL.
- El onboarding exige crear una cuenta propia o introducir un token sin una decisión de producto aprobada.

## Notas de mantenimiento

Cada proveedor futuro debe aparecer mediante descriptores y métricas comunes. Si añadir uno requiere un `switch providerID` dentro de una vista, ampliar el modelo de presentación antes de introducir la rama.

