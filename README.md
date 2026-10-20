# Fight Game Test — Prototipo de pelea 2D (Godot 4.x)

Prototipo jugable de un juego de peleas 2D local, hecho **solo con formas
geométricas y pixel art generado en código** (sin archivos de imagen ni audio).
El código es modular y sirve como base para seguir ampliando.

## Cómo ejecutar

Abre el proyecto en Godot 4.x y pulsa **F5** (la escena principal ya está
configurada como `scenes/main.tscn`). También puedes lanzarlo en ventana con
el editor. En pantalla verás el aviso de control a los pies.

Al terminar el combate, **ENTER** reinicia el match. **ESC** abre el menú de
pausa (combos disponibles + controles + continuar).

## Controles

| Acción            | Jugador 1        | Jugador 2 (opcional) |
|-------------------|------------------|----------------------|
| Moverse           | `A` / `D`        | `←` / `→`            |
| Saltar (x2)       | `W`              | `↑`                  |
| Agacharse         | `S`              | `↓`                  |
| Dash              | `Shift`          | `U`                  |
| Ataque ligero     | `J`              | `I`                  |
| Ataque medio      | `K`              | `O`                  |
| Ataque pesado     | `L`              | `P`                  |
| Especial          | `Ñ` (tecla `;`)  | `[`                  |
| Bloquear          | dirección opuesta al rival | dirección opuesta |
| Pausa             | `ESC`            | `ESC`                |

> El **especial** se dispara con la tecla física situada a la derecha de la `L`:
> en teclados españoles es `Ñ` y en teclados US es `;`.

El Jugador 2 está controlado por IA por defecto. Para que lo maneje una persona,
en `scenes/main.tscn` selecciona `Fighters/Player2` y desmarca **is_ai**.

## Combate

- **4 ataques** con identidad propia:
  - **Ligero (`J`)** — muy rápido, poco daño, gran ventana para encadenar.
  - **Medio (`K`)** — mejor alcance; agachado (`S` + `K`) se convierte en *Patada baja*.
  - **Pesado (`L`)** — lento y castigable; hacia delante (`→` + `L`) se convierte
    en *Embestida* (gana impulso hacia el rival).
  - **Especial (`Ñ`)** — finisher lanzadera con **invulnerabilidad breve** al inicio.
- **Ataques aéreos**: los mismos botones en el aire (`J`/`K`/`L`/`Ñ`). Máximo de
  3 acciones aéreas por tiempo en el aire.
- **Doble salto**: `W` en el aire.
- **Bloqueo direccional** en tierra **y en el aire**: mantén la dirección opuesta
  al rival; reduce el daño al 15 % y aplica empuje.

### Combos y encadenado

Encadenar requiere **confirmar el golpe** (whiff = sin cancelación), hasta un tope
de golpes por combo. Las secuencias nombradas dan un pequeño bonus de daño al
finisher. Se muestran en el menú de pausa:

| Combo               | Secuencia                        |
|---------------------|----------------------------------|
| Ráfaga rápida       | Ligero → Ligero → Medio          |
| Barrido ascendente  | Ligero → Medio → Pesado          |
| Cadena completa     | Ligero → Medio → Pesado → Especial |
| Golpe demoledor     | Medio → Pesado                   |
| Patada baja         | Abajo + Medio                    |
| Embestida           | Adelante + Pesado                |
| Final ascendente    | Abajo + Medio → Especial         |
| Ráfaga aérea        | (aire) Ligero → Ligero → Medio   |
| Combo aéreo         | (aire) Ligero → Medio → Pesado   |
| Aéreo extendido     | (aire) Ligero → Medio → Especial |

### Anti-loops

Para evitar infinitos el sistema aplica **escalado de daño** por número de golpes
(`1.0, 0.85, 0.72, 0.60, 0.50, 0.42, 0.35, 0.30`), **decaimiento del hitstun**,
**crecimiento del knockback**, un **tope duro de 8 golpes** (la víctima escapa con
un empuje fuerte e invulnerabilidad breve) y un **timeout de combo** (0.55 s).

## Jugosidad (impacto, no daño)

- **Hitstop** por frames: ligero 2, medio 3, pesado 5, finisher 6, bloqueo 1–3.
- **Chispas** de impacto cuyo color y tamaño dependen del tipo de golpe.
- **Screen shake** y destello de pantalla breves en golpes fuertes/especial.
- **Pixel art** con poses distintas por ataque y un arco de color (telegraph)
  durante los frames activos.

## Jerarquía de la escena principal (`scenes/main.tscn`)

```
Main (Node2D)                     -> scripts/game_manager.gd
├─ Background (ColorRect)
├─ BackgroundAccent (ColorRect)
├─ Stage (Node2D)
│  ├─ Floor (StaticBody2D + CollisionShape2D + Visual)
│  ├─ WallLeft / WallRight (StaticBody2D)
│  └─ PlatformLeft / PlatformRight (StaticBody2D, one-way)
├─ Fighters (Node2D)
│  ├─ Player1 (fighter.tscn)
│  └─ Player2 (fighter.tscn)
├─ Effects (Node2D)               -> chispas de impacto generadas en runtime
├─ Camera2D                       -> screen shake
├─ HUD (hud.tscn, CanvasLayer)    -> scripts/hud.gd
└─ PauseMenu (pause_menu.tscn)    -> scripts/pause_menu.gd
```

## Jerarquía del combatiente (`scenes/fighter.tscn`)

```
Fighter (CharacterBody2D)         -> scripts/fighter.gd
├─ Body (ColorRect)               -> alternativa geométrica (oculta si use_pixel_art)
├─ Sprite (Sprite2D)              -> pixel art generado en código
├─ Slash (ColorRect)              -> telegraph de ataque en frames activos
├─ BodyCollision (CollisionShape2D)
├─ Hurtbox (Area2D)               -> scripts/hurtbox.gd
│  └─ CollisionShape2D
└─ Hitbox (Area2D)                -> scripts/hitbox.gd
   └─ CollisionShape2D
```

## Capas de física

| Capa | Uso         |
|------|-------------|
| 1    | Mundo       |
| 2    | Combatiente |
| 3    | Hurtbox     |
| 4    | Hitbox      |

## Archivos

- `scripts/move_data.gd` — `Resource` con los datos de un movimiento.
- `scripts/move_library.gd` — biblioteca de movimientos (tierra y aire).
- `scripts/combo_system.gd` — buffer de entradas, escalado anti-loop y golpes.
- `scripts/combo_recipes.gd` — recetas de combos por secuencia de botones.
- `scripts/pixel_art.gd` — generador de pixel art en runtime (Image → textura).
- `scripts/fighter.gd` — movimiento, estados, ataques, cadenas, daño y bloqueo.
- `scripts/ai_brain.gd` — IA básica que devuelve una "intención" de input.
- `scripts/hitbox.gd` / `scripts/hurtbox.gd` — marcadores de área de combate.
- `scripts/game_manager.gd` — rondas, HUD, hitstop, feedback y pausa.
- `scripts/hud.gd` — barras de vida, pips, temporizador, combos y mensajes.
- `scripts/pause_menu.gd` — menú de pausa con combos y controles.

## Mecánicas implementadas

- Movimiento fluido con aceleración, **doble salto**, agacharse, dash y juggle.
- Ataques por fases (startup / active / recovery) con hitbox y knockback.
- **Encadenado de golpes** con ventana de ventaja y reglas por tipo.
- **Combos nombrados** con bonus y contador en el HUD.
- Bloqueo direccional (tierra y aire): reduce el daño al 15 %.
- Vida de 100 puntos, K.O. y rondas al mejor de 3 con temporizador.
- Hitstop, chispas, screen shake y flash para dar "jugosidad" sin assets.
- Pixel art generado por código con poses distintas por ataque.
- Menú de pausa (`ESC`) con continuar, lista de combos y controles.
