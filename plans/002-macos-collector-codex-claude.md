# Plan 002: Construir el collector macOS con Codex y Claude

> **Instrucciones para el ejecutor**: implementa una vertical de solo lectura. No copies branding ni acciones mutables de upstream. Antes de copiar código, registra procedencia, commit de origen y licencia. Nunca incluyas tokens ni cuerpos de respuesta reales en fixtures, logs o commits.

## Estado

- **Prioridad**: P0
- **Esfuerzo**: L (7–10 días)
- **Riesgo**: HIGH; autenticación y endpoints no públicos cambian fuera de nuestro control
- **Depende de**: `plans/001-foundation-and-schema.md`
- **Categoría**: direction / security
- **Planificado**: sin commit base, 2026-08-15

## Objetivo

El companion macOS detecta sesiones locales de Codex y Claude, obtiene las ventanas de cuota y fechas de reset, calcula gasto/tokens locales cuando haya logs y publica `ProviderSnapshot` válidos en el almacén local. Debe seguir funcionando si un proveedor falla y nunca mostrar prompts de llavero durante refrescos automáticos.

## Fuentes upstream

Revisar y fijar a un commit concreto antes de portar:

- `https://github.com/robinebers/openusage`: `ProviderRuntime`, `ProviderSnapshot`, `Providers/Codex`, `Providers/Claude`, escáneres JSONL y tests.
- `https://github.com/steipete/CodexBar`: `CodexBarCore`, `docs/codex.md`, `docs/claude.md`, fixtures, pace y clasificación de errores.

Preferir la implementación más pequeña de OpenUsage. Usar CodexBar para casos límite y compatibilidad, no para mezclar dos modelos de dominio. Toda pieza copiada debe transformarse para producir el contrato propio de 001.

## Archivos y módulos

```text
Packages/AILimitsCollectors/
  Package.swift
  Sources/AILimitsCollectors/
    CollectorCoordinator.swift
    Auth/KeychainClient.swift
    HTTP/ProviderHTTPClient.swift
    Storage/AtomicSnapshotStore.swift
    Providers/Codex/
    Providers/Claude/
  Tests/AILimitsCollectorsTests/
Apps/macOS/
  AILimitsMacApp.swift
  CollectorStatusView.swift
  Settings/ProviderSettingsView.swift
ThirdPartyNotices/
  OpenUsage-MIT.txt
  CodexBar-MIT.txt             # solo si se copia código sustancial
  PROVENANCE.md
```

## Reglas de seguridad

- Credenciales solo en el Mac y solo durante la petición necesaria.
- Nunca persistir access/refresh tokens en `UserDefaults`, CloudKit, App Group o snapshots.
- El wrapper HTTP debe permitir únicamente hosts declarados por cada provider.
- Redactar `Authorization`, cookies, emails, rutas de home y cuerpos de respuesta en logging.
- Los refrescos automáticos son prompt-free. Si el llavero requiere interacción, devolver `authRequired` y pedir un refresco manual desde la UI.
- V1 es estrictamente de lectura. No portar “claim reset credit”, escritura de settings de CLIs ni cambio de cuenta.

## Pasos

### 1. Crear infraestructura del collector

Implementar `CollectorCoordinator` como actor. Debe ejecutar proveedores en paralelo con timeout individual, limitar una ejecución simultánea por proveedor, conservar el último snapshot bueno y emitir un error tipado cuando el nuevo fetch falle. Guardar snapshots mediante escritura atómica.

**Verificar**: tests con collectors fake demuestran aislamiento de errores, timeout, cancelación, coalescing y conservación del último dato bueno.

### 2. Portar Codex

Detectar el login de Codex en las ubicaciones estándar sin copiar el secreto al snapshot. Portar el cliente de uso y mapper para sesión, semanal, créditos, plan y resets. Añadir después el escáner local de sesiones para hoy/ayer/30 días; marcar el coste como estimado cuando use tarifas públicas.

Separar explícitamente:

- `codex-subscription`: cuotas de ChatGPT/Codex obtenidas con la sesión local.
- `openai-api`: uso/coste de la plataforma API, que no forma parte de este plan.

**Verificar**: fixtures sanitizados cubren respuesta completa, ausencia de ventana semanal, 401, 429, cambio de esquema, créditos sin expiración y timestamps con zona horaria.

### 3. Portar Claude

Leer primero las credenciales de Claude Code disponibles en macOS. Refrescar tokens solo según el comportamiento comprobado de upstream y nunca sobrescribir una credencial que haya cambiado desde que empezó el refresh. Mapear sesión, semanal, límites por modelo, extra usage y plan. Añadir escaneo local de logs para gasto/tokens como fase separada del fetch de cuota.

**Verificar**: fixtures cubren token válido, token inference-only sin scope de uso, token expirado, fallback entre fuentes, throttling, respuesta parcial y “not started”.

### 4. Construir la UI mínima del companion

Mostrar estado por proveedor, última actualización, fuente, botón de refresh manual, toggle y diagnóstico seguro. Añadir launch-at-login usando `SMAppService`. No construir aún una réplica del dashboard iOS ni copiar el popover visual de upstream.

**Verificar**: al relanzar, las preferencias se conservan; un refresh automático nunca abre un diálogo de llavero; el refresh manual puede explicar el permiso requerido.

### 5. Atribución y auditoría de secretos

Registrar por archivo si es original, adaptado de OpenUsage o adaptado de CodexBar. Copiar avisos MIT completos cuando corresponda. Ejecutar un escaneo de secretos y revisar que los fixtures solo contienen valores obviamente ficticios.

**Verificar**:

```sh
swift test --package-path Packages/AILimitsCollectors
rg -n --hidden '(sk-[A-Za-z0-9_-]{16,}|Bearer [A-Za-z0-9._-]{16,}|sessionKey=)' --glob '!plans/**' .
```

El primer comando pasa; el segundo no devuelve secretos reales.

## Pruebas requeridas

- HTTP completamente simulado en unit tests; cero llamadas reales en CI.
- Tests de concurrencia con Swift 6 strict concurrency.
- Tests de redacción de logs para cada tipo de secreto.
- Test de escritura atómica interrumpida: el lector conserva el snapshot anterior válido.
- Prueba manual en una cuenta real de Codex y otra de Claude, capturando solo métricas finales y nunca credenciales.

## Criterios de terminado

- [ ] Codex y Claude generan `ProviderSnapshot` con cuotas y reset cuando las cuentas lo exponen.
- [ ] La caída de un proveedor no afecta al otro.
- [ ] El último valor bueno se conserva y aparece marcado como antiguo/error.
- [ ] Ningún secreto está en snapshots, logs, fixtures o `UserDefaults`.
- [ ] `swift test --package-path Packages/AILimitsCollectors` pasa.
- [ ] Atribución MIT y procedencia están completas.
- [ ] El companion firmado puede arrancar al iniciar sesión.

## Condiciones STOP

- El código upstream elegido no tiene licencia MIT en el commit fijado.
- Obtener una cuota exige enviar credenciales a un dominio no documentado en el provider.
- El collector necesita desactivar ATS/TLS o aceptar certificados inválidos.
- Un cambio exige portar una acción mutable o escribir en la configuración del proveedor.
- No puede demostrarse con tests que un token queda fuera del snapshot y del log.

## Notas de mantenimiento

Los endpoints de suscripción son el área más frágil. Mantener fixtures por versión, telemetría solo por categorías de error y un kill switch local/remoto por proveedor. La UI debe seguir útil con datos en caché si uno desaparece temporalmente.

