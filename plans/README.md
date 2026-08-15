# Planes de implementación: AI Limits para iOS

Generados el 2026-08-15. El repositorio estaba vacío, sin proyecto ni historial Git, al preparar estos planes. Ejecútalos en orden; cada entrega debe quedar verificable antes de empezar la siguiente.

## Decisión de producto

La primera versión será un sistema Apple de dos aplicaciones:

1. **Companion para macOS**: obtiene cuotas, consumos y fechas de reinicio desde las credenciales y logs que ya existen en el Mac.
2. **App para iPhone**: recibe únicamente métricas normalizadas mediante la base privada de CloudKit del usuario, las almacena localmente y las presenta en dashboard, detalle, widgets y notificaciones.

Las credenciales, cookies, tokens OAuth, claves API, logs y respuestas crudas de los proveedores **no salen del Mac**. La app iOS no afirmará que un dato es en tiempo real: siempre mostrará `updatedAt`, el dispositivo de origen y un estado `fresh/stale/offline`.

## Por qué hace falta el companion

OpenUsage y CodexBar son aplicaciones macOS. Su ventaja proviene de leer `~/.codex`, `~/.claude`, bases SQLite de Cursor, el llavero, cookies del navegador y logs locales. iOS no puede acceder a esos datos. Además, las APIs oficiales de OpenAI y Anthropic informan del consumo de sus plataformas API mediante claves administrativas; no equivalen a las cuotas personales de ChatGPT Codex o Claude Code.

## Código abierto que se puede aprovechar

| Proyecto | Licencia | Reutilización recomendada | No reutilizar directamente |
|---|---|---|---|
| `robinebers/openusage` | MIT; marca y logo excluidos | Modelos normalizados, patrón `auth store -> client -> mapper -> snapshot`, clientes/mappers de Codex y Claude, lógica de caché/frescura, ideas de sincronización iCloud | Nombre, logo, visual identity, AppKit, Sparkle, UI del menú, acciones irreversibles como reclamar resets |
| `steipete/CodexBar` | MIT | Contrato `dashboard/v1`, patrón descriptor/estrategia, fixtures y casos límite, algoritmo de pace, referencia para proveedores adicionales | Fork completo, UI macOS, importadores de cookies, QuickJS y helpers de procesos salvo que un proveedor concreto los necesite |
| `janekbaraniewski/openusage` | MIT, Go | Referencia para informes y proveedores de CLI; posible adaptador opcional futuro | Integrarlo en el binario iOS o usarlo como base principal de una app Swift |

Si se copia código sustancial, conservar el copyright y la licencia MIT correspondiente en `ThirdPartyNotices/`. Diseñar nombre, icono y UI propios; no usar la marca ni el logo de OpenUsage.

## Contrato de datos de v1

El módulo compartido debe representar:

- `SnapshotEnvelope`: versión de esquema, generación, dispositivo y versión del collector.
- `ProviderSnapshot`: proveedor, cuenta opaca, plan opcional, fuente, frescura, error tipado y métricas.
- `UsageWindow`: sesión/semanal/mensual/específica, usado, límite, unidad, porcentaje y `resetAt`.
- `BalanceMetric`: créditos, dólares, requests u otra unidad.
- `SpendMetric`: hoy, ayer y últimos 30 días, con tokens y coste estimado cuando existan.
- `DailyUsagePoint`: fecha, tokens y coste para gráficas.

CloudKit solo recibe este contrato normalizado. Nunca recibe secretos, cabeceras HTTP, cookies, rutas de archivos, prompts, respuestas, logs crudos o cuerpos de API sin filtrar.

## Orden y estado

| Plan | Título | Prioridad | Esfuerzo | Depende de | Estado |
|---|---|---:|---:|---|---|
| 001 | Crear la base multiplataforma y el contrato de datos | P0 | M | — | TODO |
| 002 | Construir el collector macOS con Codex y Claude | P0 | L | 001 | TODO |
| 003 | Sincronizar snapshots por CloudKit privado | P0 | M | 001, 002 | TODO |
| 004 | Construir el dashboard iOS y onboarding | P0 | L | 001, 003 | TODO |
| 005 | Añadir Cursor, Copilot y OpenRouter | P1 | L | 002, 003, 004 | TODO |
| 006 | Añadir widgets, alertas y preparar TestFlight | P1 | L | 004, 005 | TODO |

Estimación orientativa para una persona: **6–9 semanas** para un MVP con Codex, Claude, Cursor, Copilot, OpenRouter, app iOS, companion, widgets y TestFlight. Una vertical usable solo con Codex + Claude puede estar en **3–4 semanas**. La incertidumbre principal no es SwiftUI: son los endpoints no públicos y los cambios de autenticación de cada proveedor.

## Dependencias

- 001 fija el esquema y los protocolos que consumen todos los planes.
- 002 demuestra que el Mac puede producir datos reales sin sincronizar secretos.
- 003 completa la vertical Mac -> CloudKit -> caché iOS antes de construir una UI amplia.
- 004 debe funcionar con fixtures y con datos CloudKit reales antes de ampliar proveedores.
- 005 usa la misma interfaz de collector; no debe añadir ramas de proveedor a la UI.
- 006 se apoya en el caché compartido de 004 para cumplir los límites de WidgetKit.

## Alternativas consideradas y rechazadas

- **Solo iOS**: no permite leer credenciales y logs del Mac, y perdería precisamente las cuotas de suscripción más valiosas. Sí puede añadirse después para proveedores con API oficial y clave limitada.
- **Servidor propio desde el día uno**: facilitaría Android/web y push, pero crea cuentas, costes operativos y una superficie de seguridad innecesaria para datos sensibles. CloudKit privado resuelve el MVP sin custodiar datos de otros usuarios.
- **Conexión LAN directa al Mac**: no funciona fuera de casa, pide permiso de red local y deja el problema del Mac dormido. Puede existir como herramienta de desarrollo, no como transporte principal.
- **Fork completo de CodexBar**: aporta muchos proveedores, pero también una superficie macOS enorme y dependencias incompatibles con iOS. Es mejor portar/adaptar por proveedor.
- **Copiar el iCloud Drive actual de OpenUsage sin cambios**: sincroniza historia de gasto entre Macs, pero no cuotas, planes ni errores. V1 necesita snapshots completos y suscripciones de cambios; CloudKit records es un contrato más apropiado.

## Límites conocidos que deben verse en el producto

- Si el Mac está dormido o apagado, el iPhone muestra el último snapshot y lo marca como antiguo.
- CloudKit, tareas en background y widgets son oportunistas; no garantizan refresco cada cinco minutos.
- Los endpoints privados pueden romperse. Cada proveedor debe fallar aisladamente y conservar el último dato bueno con su antigüedad.
- “OpenAI API usage” y “Codex subscription quota” son fuentes distintas y nunca deben mezclarse bajo una cifra sin etiqueta.

