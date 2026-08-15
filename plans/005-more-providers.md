# Plan 005: Añadir Cursor, Copilot y OpenRouter sin romper la arquitectura

> **Instrucciones para el ejecutor**: añadir un proveedor por vez, detrás de feature flag, con fixture y kill switch. No promoverlo a estable hasta que su error quede aislado y el snapshot no contenga secretos.

## Estado

- **Prioridad**: P1
- **Esfuerzo**: L (7–12 días)
- **Riesgo**: HIGH
- **Depende de**: 002, 003, 004
- **Categoría**: direction
- **Planificado**: sin commit base, 2026-08-15

## Objetivo

Ampliar el MVP a cinco fuentes sin introducir lógica específica en CloudKit o SwiftUI. Cursor y Copilot se recogen en el Mac por depender de estado local o endpoints de cliente. OpenRouter empieza también en el Mac; una conexión directa iOS con clave limitada se evalúa después, no forma parte del MVP.

## Matriz de soporte

| Provider | Origen en v1 | Métricas | Riesgo |
|---|---|---|---|
| Cursor | sesión de Cursor en Mac + endpoints dashboard/export | plan, uso ciclo, requests, auto/API, extra usage, gasto histórico | endpoint/esquema no público y token local |
| Copilot | token existente de Copilot/gh en Mac | AI credits, extra usage, chat/completions, reset; org billing solo para admin | endpoint `copilot_internal`; permisos variables |
| OpenRouter | management key guardada en Keychain del companion | créditos comprados/usados, balance y gasto por período | API oficial; una management key sigue siendo sensible |

No denominar “API oficial” a un endpoint interno aunque sea estable en upstream.

## Pasos por proveedor

### Cursor

Adaptar desde OpenUsage el auth store local, cliente y mapper. Aislar lectura de SQLite/Keychain detrás de protocolos. Tratar export CSV como opcional: una exportación rota no debe borrar las cuotas actuales. Validar límites de tamaño y esquema antes de parsear.

**Verificar**: fixtures cubren cuenta individual, enterprise, fallback REST, CSV tardío, fila malformada, token refresh, 401 y respuesta parcial.

### Copilot

Buscar tokens en ubicaciones conocidas sin copiarlos a config propia. Mapear porcentaje remaining a used una sola vez. Separar métricas personales de uso de organización; etiquetar `Org` y ocultarlas si faltan permisos.

**Verificar**: fixtures cubren Free, Pro, Business/Enterprise, org admin, miembro sin billing, bucket sin entitlement y reset ausente.

### OpenRouter

Permitir introducir una management key en la UI del Mac y guardarla en Keychain, no en fichero plano ni CloudKit. Consumir únicamente endpoints oficiales necesarios, con allowlist y `Retry-After`. No mostrar la clave después de guardarla; ofrecer reemplazar/revocar.

**Verificar**: tests cubren credits, key limit diario/semanal/mensual, balance cero, 401/403/429 y respuesta parcial.

### Registro genérico

Crear `ProviderDescriptor` con ID, nombre, color propio de la app, capacidades, frescura, links permitidos y factory del collector. El iOS dashboard recibe snapshots y nunca enlaza el paquete collectors.

**Verificar**: añadir un provider fake mediante un solo descriptor y demostrar que aparece en companion, sync y dashboard sin editar vistas.

## Gates para marcar estable

- 7 días de dogfooding sin fuga de credenciales ni crash.
- ≥95% de refrescos exitosos en cuentas de prueba válidas, excluyendo offline/429.
- Kill switch funciona y conserva último dato bueno.
- Fixtures y docs identifican si el endpoint es oficial, interno o local.
- La desactivación borra la clave propia y deja de publicar nuevos snapshots.

## Comandos

```sh
swift test --package-path Packages/AILimitsCollectors
xcodebuild -scheme AILimits-macOS -destination 'platform=macOS' test
xcodebuild -scheme AILimits-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Criterios de terminado

- [ ] Los tres providers pasan sus gates y fallan independientemente.
- [ ] Ningún secreto llega al contrato compartido o CloudKit.
- [ ] No se ha añadido lógica específica de provider a vistas iOS.
- [ ] La UI distingue uso personal, organización y plataforma API.
- [ ] Hay documentación de fuente, permisos y troubleshooting para cada uno.
- [ ] Licencias/procedencia se actualizaron por cada adaptación.

## Condiciones STOP

- Un endpoint requiere password, bypass de MFA o captura de tráfico.
- Hay que sincronizar una management/admin key al iPhone para completar el MVP.
- El provider exige permisos más amplios que los que su métrica justifica.
- No existe forma de distinguir una métrica personal de una organizativa.
- Un fixture real no puede sanearse con confianza: recrearlo sintéticamente.

## Notas de mantenimiento

Mantener una página de compatibilidad con `stable/beta/broken` y fecha del último fetch exitoso por versión. No medir éxito solo por que el HTTP devuelva 200: validar semántica del snapshot y detectar campos ausentes.

