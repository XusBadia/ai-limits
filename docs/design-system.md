# AI Limits design system

## Product layout

```text
┌──────────────────────────────────────┐
│ AI Limits                Updated 2m  │
│ Your AI capacity, before it runs out │
├──────────────────────────────────────┤
│ CLAUDE · MAX                         │
│ Session                  72% used    │
│ ██████████████░░░░░░     resets 55m  │
│ Weekly                   41% used    │
│ ████████░░░░░░░░░░░░     resets Fri │
├──────────────────────────────────────┤
│ CODEX · PRO                          │
│ ...                                  │
└──────────────────────────────────────┘
```

## Visual direction

Quiet, high-contrast and data-first. Warm paper background in light mode, near-black ink in dark mode, rounded cards, hairline borders and one provider accent per card. No generic SaaS gradient and no traffic-light color without a text label.

## Tokens

- Spacing: 4, 8, 12, 16, 24, 32, 48.
- Radius: 12 controls, 20 cards, 28 large surfaces.
- Type: system rounded display, system body, monospaced numerals.
- Ink: `#11110F`; paper: `#F5F3ED`; muted: `#6F6E68`.
- Codex: `#127C78`; Claude: `#C8663D`; Cursor: `#6E5BC8`; Copilot: `#3478C9`; OpenRouter: `#8257D9`.
- Motion: 180 ms opacity/scale for local state changes; disabled under Reduce Motion.

## Required states

Every surface supports loading, first-use empty, provider auth error, rate limit error, offline cache and stale data. Touch targets are at least 44 points. Progress always has a numeric accessible label.

