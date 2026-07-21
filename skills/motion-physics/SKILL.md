---
name: motion-physics
description: >
  Use when building any element that moves in response to user input — draggable cards, sliders,
  drawers, bottom sheets, drag handles, lifted or liftable components, swipeable card decks,
  carousels, velocity-aware or cursor-reactive motion, magnetic snap points, and gesture-driven
  UI. These are component-specific interaction patterns, not global defaults.
---

# Motion Physics

These patterns apply to specific interaction-heavy components. Read the relevant section before
implementing any draggable, liftable, velocity-aware, or gesture-driven element. Do not apply
globally — use judgment about which moments warrant the additional complexity.

---

## 1. Grounded shadow: separate the object from its shadow

When an element lifts away from a surface, the shadow should not simply travel with it. Keeping
the shadow pinned to the surface and fading it based on lift distance creates a far stronger
sense of physicality — the element feels like it exists in space rather than floating on a layer.

**The principle:** animate the element and its shadow as independent DOM nodes.

**Correct approach — fade only, shadow stays pinned:**
```js
const card   = document.querySelector(".card");
const shadow = document.querySelector(".card-shadow");

// Card lifts
card.animate(
  [{ transform: "translateY(0)" }, { transform: "translateY(-160px)" }],
  { duration: 900, easing: "cubic-bezier(0.22, 1, 0.36, 1)", fill: "forwards" }
);

// Shadow fades in place — no scaling, no movement
shadow.animate(
  [{ opacity: 0.5 }, { opacity: 0 }],
  { duration: 700, easing: "ease-out", fill: "forwards" }
);
```

**Why not `scaleX`:** horizontal shadow scaling reads as the light source changing shape,
not the object moving away. A pure opacity fade is more physically believable.

**HTML structure:**
```html
<div class="lift-container">
  <div class="card-shadow"></div>  <!-- pinned to surface, z-index below card -->
  <div class="card"></div>
</div>
```

```css
.lift-container { position: relative; }

.card-shadow {
  position: absolute;
  bottom: -8px;
  left: 50%;
  transform: translateX(-50%);
  width: 80%;
  height: 12px;
  background: radial-gradient(ellipse, rgba(0,0,0,0.3) 0%, transparent 70%);
  border-radius: 50%;
  /* Shadow stays put — the card animates, not this */
}
```

**When to use:** notification cards lifting on action, cards being dragged to a new container,
picker wheels, any "pick up and place" interaction. Not for standard hover states.

---

## 2. Physical drag: momentum, resistance, and snap

A timed CSS animation on a drag handle feels dead. Real drag has weight.

### Three things that make drag feel alive

**Velocity tracking** — smooth the cursor's speed over time so a flick has momentum:
```js
let lastX = 0, lastTime = performance.now(), velocity = 0;

element.addEventListener("pointermove", e => {
  const now = performance.now();
  const dt  = now - lastTime;
  const raw = (e.clientX - lastX) / dt;
  velocity  = velocity * 0.8 + raw * 0.2;  // exponential smoothing
  lastX     = e.clientX;
  lastTime  = now;
});
```

**Momentum on release** — keep moving and coast to a stop:
```js
element.addEventListener("pointerup", () => {
  let v = velocity;
  const coast = () => {
    v *= 0.92;  // friction
    position += v;
    applyPosition(position);
    if (Math.abs(v) > 0.1) requestAnimationFrame(coast);
    else snapToNearest();
  };
  requestAnimationFrame(coast);
});
```

**Soft boundaries** — stretch and spring back rather than hard-stopping:
```js
function applyWithResistance(rawValue, min, max) {
  if (rawValue < min) return min - Math.sqrt(min - rawValue) * 4;
  if (rawValue > max) return max + Math.sqrt(rawValue - max) * 4;
  return rawValue;
}
```

### Framer Motion equivalent (React)

```jsx
<motion.div
  drag="x"
  dragConstraints={{ left: 0, right: 300 }}
  dragElastic={0.08}        // resistance approaching boundaries
  dragMomentum={false}      // remove inertial overshoot, keep it controlled
  onDragEnd={(e, info) => {
    const snapTarget = info.offset.x > 150 ? 300 : 0;
    animate(x, snapTarget, { type: "spring", stiffness: 400, damping: 30 });
  }}
/>
```

Key parameters:
- `dragElastic={0.08}` — low value = strong resistance. `0.2`+ starts to feel loose.
- `dragMomentum={false}` — removes built-in inertia so you control the snap yourself.
- Spring on release (`stiffness: 400, damping: 30`) — gives the interaction weight and a decisive settle.

---

## 3. Magnetic snap points

As a handle nears a meaningful value, magnetise it. The two-zone system:

```js
const SNAP_POINTS = [0, 25, 50, 75, 100]; // e.g. percentage values
const PULL_RADIUS   = 6;   // tight — snaps in
const RELEASE_RADIUS = 14; // larger — must commit to break free

let snapped = false;
let snapTarget = null;

function applySnap(value) {
  const nearest = SNAP_POINTS.find(s => Math.abs(value - s) < (snapped ? RELEASE_RADIUS : PULL_RADIUS));

  if (nearest !== undefined) {
    snapped    = true;
    snapTarget = nearest;
    flashLabel(nearest); // micro-feedback on catch
    return nearest;
  }

  snapped    = false;
  snapTarget = null;
  return value;
}

function flashLabel(value) {
  label.animate(
    [{ opacity: 1 }, { opacity: 0.4 }, { opacity: 1 }],
    { duration: 180, easing: "ease-out" }
  );
}
```

The hysteresis (tight pull-in, wider release) is what makes snap feel intentional rather than sticky.
Once caught, you have to mean it to pull away.

---

## 4. Cursor velocity: react to motion, not just position

Fast movement should add rotation, stretch, or blur for a split second. The interface feels
physical because it reacts to *how* the user is moving, not just *where* they are.

```js
let lastX = 0, lastTime = performance.now();

addEventListener("pointermove", e => {
  const now = performance.now();
  const v   = (e.clientX - lastX) / (now - lastTime); // px/ms

  card.style.transform = `
    rotate(${v * 6}deg)
    scaleX(${1 + Math.abs(v) * 0.08})
  `;

  lastX    = e.clientX;
  lastTime = now;
});
```

```css
.card {
  /* Spring back smoothly after velocity settles */
  transition: transform 0.25s cubic-bezier(0.22, 1, 0.36, 1);
}
```

**Calibration:**
- `v * 6` for rotation — tune down if the component is small
- `Math.abs(v) * 0.08` for stretch — anything above 0.12 starts to look broken
- The CSS transition handles the return to rest; don't animate the active state with CSS

**When to use:** cards in a swipeable deck, drag-to-dismiss sheets, image carousels.
Not for buttons or form elements.

---

## 5. Input anticipation: react before the click

Most interfaces wait for a tap. Better interfaces prepare for what the user is about to do.
React to *intent* (proximity + trajectory) before the interaction happens.

**Proximity-based focus ring:**
```js
const box  = document.querySelector(".input");
const ring = document.querySelector(".focus-ring");

addEventListener("pointermove", e => {
  const r  = box.getBoundingClientRect();
  const dx = Math.max(r.left - e.clientX, 0, e.clientX - r.right);
  const dy = Math.max(r.top  - e.clientY, 0, e.clientY - r.bottom);
  const distance = Math.hypot(dx, dy);

  // Quadratic falloff — ring appears gradually, not linearly
  const intent = Math.max(0, 1 - distance / 180) ** 2;
  ring.style.opacity = intent;
});
```

```css
.focus-ring {
  position: absolute;
  inset: -8px;
  border-radius: inherit;
  border: 1.5px solid var(--color-accent);
  opacity: 0;
  pointer-events: none;
  transition: opacity 80ms ease-out;
}
```

**Radius `180`** — the activation distance in pixels. Tune to the component's importance.
Wider = more anticipatory. The quadratic `** 2` creates a natural gradient rather than
a linear on/off.

**When to use:** primary CTAs, search fields, important form inputs, onboarding flows.
Not for every interactive element — this pattern's power comes from restraint.

---

## Choosing the right pattern

| Situation | Pattern |
|-----------|---------|
| Card or panel that physically lifts | Grounded shadow (#1) |
| Slider, drawer, bottom sheet, handle | Physical drag + momentum (#2) |
| Slider with preset values | Snap points (#3) |
| Swipeable card deck, carousel | Cursor velocity (#4) |
| Primary CTA, key form input | Input anticipation (#5) |
| Navigation, toolbar | Proximity scaling (see "UI Polish Principles" §9 in global CLAUDE.md) |

---

## General guidance

- **Test at the extremes.** Snap at the boundary, flick at maximum velocity, drag and release
  mid-boundary. Polish lives at the edges.
- **Tune by feel, not by formula.** Every number above is a starting point. Adjust until it
  feels right, then commit the values as tokens.
- **One physics pattern per component.** Combining velocity + snap + anticipation on the same
  element usually creates noise, not richness.
- **Always honour `prefers-reduced-motion`.** All of the above collapses to instant state changes
  when the user has reduced motion enabled.
