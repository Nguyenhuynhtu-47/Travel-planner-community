# Animation Guidelines

## 1. Overview and Core Philosophy

Motion in Travel Planner must be **purposeful, subtle, and ergonomic**. It serves to guide visual focus, reinforce spatial relationships, provide tangible feedback, and convey system status—never to decorate aimlessly, slow the user down, or obstruct travel planning workflows.

These guidelines establish a standardized decision framework for AI agents and human developers when designing, choosing, and implementing interface motion across **Flutter Mobile** (`frontend/mobile`) and **Flutter Web** (`frontend/web`).

### 1.1 Upstream Reference and Conceptual Adaptation
- **Reference Specification:** [Animate UI Skills Documentation](https://animate-ui.com/docs/skills).
- **Universal Motion Principles Adopted:**
  - **Frequency-of-Use Gating:** The more frequently a user interacts with a component, the less motion it should have. High-frequency actions must be instantaneous or near-instantaneous; expressive motion is reserved strictly for rare, high-impact milestones.
  - **Subtle by Default:** When motion is warranted, subtle, natural damping is the default expectation.
  - **Zero-Motion as a Valid Outcome:** Developers and AI agents are explicitly empowered and expected to decide that **no animation is necessary** when direct state changes provide the cleanest, fastest user experience.
  - **Origin and Direction Anchoring:** Motion must emanate from the user's triggering touch point, click position, or natural spatial hierarchy (e.g., dialogs expanding from trigger bounds, drawers sliding from parent edges).
  - **Physics & Easing First:** Avoid jarring linear transitions. Favor spring-like natural decrescendo curves (ease-out, cubic deceleration) for entrances and snappy exits.
  - **Non-blocking / Interruption Resilience:** Animations must not lock the UI thread or prevent subsequent taps/keystrokes while in flight.

### 1.2 Strict Framework Boundary (Flutter vs. Web/React)
> [!IMPORTANT]
> **PROHIBITION ON REACT ARTIFACTS AND DEPENDENCIES**
> - The Animate UI reference library is designed for React, Next.js, and web JavaScript ecosystems (e.g., Framer Motion, `@animate-ui/react`, `@animate-ui/cli`, `shadcn/ui`, Tailwind animation classes).
> - **Never** attempt to install, copy, import, or run React-based packages, npm dependencies, or CLI tools (`npx skills add imskyleen/animate-ui`, `@animate-ui/cli`) inside this repository.
> - Both `frontend/mobile` and `frontend/web` are built with **Flutter (Dart)**.
> - All animations must be implemented using **Flutter-native APIs and idioms** (implicit animation widgets, explicit `AnimationController`, native physics simulations, and Material/Cupertino route transitions).

---

## 2. Animation Decision Framework

Before writing or modifying any UI code, agents must evaluate animation requests using the following five-step process:

```text
[Step 1: Code Inspection] 
  └── Inspect existing widget tree, active theme, and platform target.
        │
[Step 2: Frequency & Utility Gate]
  ├── High-frequency / Critical path? ──────> [Decision: NO animation / Instant swap]
  └── Meaningful state or spatial change? ──> [Proceed to Step 3]
        │
[Step 3: Motion Level Selection]
  ├── Subtle (Default: 100–200ms)
  ├── Moderate (200–300ms)
  └── Expressive (300–450ms, rare milestones)
        │
[Step 4: Implementation Technique]
  ├── State-driven change ──────────────────> Implicit Animation (AnimatedContainer, etc.)
  ├── Coordinated / Choreographed ──────────> Explicit Animation (AnimationController + dispose)
  └── List / Hierarchy changes ─────────────> AnimatedList / ReorderableListView / RouteBuilder
        │
[Step 5: Verification & Accessibility]
  └── Check prefers-reduced-motion, ticker disposal, 60fps budget, and widget test pump.
```

### 2.1 Step 1: Pre-Implementation Code Inspection
Agents must never assume animation requirements without examining the existing codebase:
1. **Inspect Target Widget & State:** Examine existing widgets in `lib/features/` or `lib/shared/widgets/`. Does the widget already manage animation controllers or ticker mixins?
2. **Review Surrounding Hierarchy:** Check if parent widgets (e.g., `Scaffold`, `CustomScrollView`, `Dialog`) impose layout constraints or conflicting scroll listeners.
3. **Check Platform Targets:** Distinguish Flutter Mobile (touch-driven, gestures, bottom safe areas) from Flutter Web (mouse hover, pointer cursors, multi-column desktop grids).

### 2.2 Step 2: Frequency & Utility Gating (When NOT to Animate)
Every animation introduces cognitive and temporal overhead. Agents must actively identify scenarios where animation should be omitted:

| Interaction Type | Frequency | Policy | Rationale |
|---|---|---|---|
| **Form input typing / validation errors** | High | **No animation** (or instant color swap) | Text entry and error cues must never delay user typing or correction. |
| **Data table sorting / pagination (Web)** | High | **No animation** | Administrative moderation requires fast data scanning; motion slows task velocity. |
| **Tab switching / Bottom navigation** | High | **Instant or subtle fade (< 150ms)** | Navigating between core sections must feel instantaneous. |
| **List filtering / Search query typing** | High | **No layout animation** | Items update directly; jumping cards induce disorientation and visual noise. |
| **Frequent action taps (Save, Like, Check)** | Medium-High | **Subtle micro-scale (< 150ms)** | Provide immediate haptic/visual acknowledgment without blocking follow-up taps. |
| **Modal presentation / Drawer opening** | Medium | **Moderate motion (150–250ms)** | Establishes spatial hierarchy and orientation. |
| **Celebratory milestone (Clone, Publish)** | Low | **Expressive motion (300–400ms)** | High-value emotional payoff for completed user trip planning. |

---

## 3. Motion Levels and Timing Standards

All durations must adhere to the project's base timing tokens to preserve temporal coherence:

```
Fast (100ms) ── Base (150–200ms) ── Moderate (250–300ms) ── Milestone (350–450ms)
```

### 3.1 Level 0: None (Direct State Swap)
- **Duration:** `0ms` (Instant).
- **When to Use:** Data grid row refresh, administrative list pagination, search filter result updates, form validation message display, and whenever reduced motion is requested.

### 3.2 Level 1: Subtle (Default Project Motion)
- **Duration:** `100ms – 200ms`.
- **Curve:** `Curves.easeOutQuad` or `Curves.easeOutCubic`.
- **Characteristics:** Micro-scale adjustments ($\Delta \le 2\%$), soft opacity cross-fades, elevation shadow expansion on hover, icon state swaps.
- **When to Use:**
  - Card hover elevation on Web (`BoxShadow` shift).
  - Button press scale (`0.98` scale down on press, snap back on release).
  - Checkbox / Radio / Switch toggle state change.
  - Tab underline indicator movement.
  - Loading skeleton shimmer sweep.

### 3.3 Level 2: Moderate (Spatial Transitions)
- **Duration:** `200ms – 300ms`.
- **Curve:** `Curves.easeInOutCubic` or `Curves.fastOutSlowIn`.
- **Characteristics:** Height expansion/collapse, vertical slide-ins ($\Delta \le 16–24\text{dp}$), bottom-sheet reveals, drawer transitions.
- **When to Use:**
  - Collapsible itinerary day card accordion.
  - Dialog / modal surface entry and exit.
  - Mobile full-screen search overlay expansion.
  - SnackBar entry and dismissal.

### 3.4 Level 3: Expressive (Celebratory & Milestones)
- **Duration:** `300ms – 450ms` (strictly capped at `500ms`).
- **Curve:** Native Spring physics (`SpringSimulation`) or overshoot curve (`Curves.elasticOut` / `Curves.easeOutBack`).
- **Characteristics:** Multi-phase micro-choreography, spring-damped icon bursts, milestone completion banners.
- **When to Use:**
  - Favorite heart toggle button active burst (scale down to `0.85`, spring overshoot to `1.15`, settle at `1.0`).
  - Successful itinerary reuse/clone completion dialogue.
  - Publishing confirmation checkmark animation.

---

## 4. Flutter Implementation Strategies

Flutter provides two primary paradigms for animation. Agents must choose the simplest approach that meets the requirement:

### 4.1 Implicit Animations (Preferred for Local State Changes)
Use implicit animations when animating properties of a single widget in response to state changes (`setState`, provider updates, or hover states). Flutter automatically interpolates values and handles internal ticker lifecycles.

| Widget | Purpose | Travel Planner Application |
|---|---|---|
| `AnimatedContainer` | Animates padding, margin, color, border, shadow | Itinerary card hover elevation, category chip active fill |
| `AnimatedOpacity` | Smooth fade in / fade out | Image loading placeholders, secondary label appearance |
| `AnimatedScale` | Micro-scale transformations | Button press feedback, active icon tap response |
| `AnimatedCrossFade` | Smooth transition between two widgets | Switching between loading spinner and loaded content |
| `AnimatedSwitcher` | Animates child replacement | Changing button text to localized loading spinner |
| `AnimatedSlide` | Positional offset shifts | Notification banner drop-down, subtle chip enter |

*Example (Card Hover Float on Web):*
```dart
MouseRegion(
  onEnter: (_) => setState(() => _isHovered = true),
  onExit: (_) => setState(() => _isHovered = false),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.0), // rounded.md
      border: Border.all(color: const Color(0xFFDDDDDD)), // hairline
      boxShadow: _isHovered
          ? const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ]
          : const [],
    ),
    child: widget.child,
  ),
);
```

### 4.2 Explicit Animations (For Choreography and Fine Control)
Use explicit animations when coordination across multiple widgets, manual forward/reverse control, or repeated cycles are required.

> [!CAUTION]
> **LIFECYCLE REQUIREMENT FOR CONTROLLERS**
> - Explicit controllers require `SingleTickerProviderStateMixin` (or `TickerProviderStateMixin`).
> - **Every `AnimationController` must be disposed** inside the `State.dispose()` method. Failing to dispose controllers causes ticker leaks, test failures, and memory exhaustion.

```dart
class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.85).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose(); // MANDATORY
    super.dispose();
  }
}
```

### 4.3 List Reordering and Drag Feedback
For lists where users rearrange itinerary days or activities, use Flutter's built-in animated list controls:
- **`ReorderableListView`:** Used for interactive activity and day reordering (as implemented in `ReorderActivitiesDialog`). Provides automatic animated tile displacement, drop elevation shadows, and touch drag handles.
- **`AnimatedList`:** Used when individual items are dynamically inserted or removed from long-scrolling timelines with insertion fade-in.

---

## 5. Travel Planner Feature Mappings

The following table prescribes the standard animation specifications for each major feature area defined in `DESIGN.md`, `docs/Travel_Planner_Function_Specification.md`, and `docs/ai/04-ui-design-system.md`:

| Feature Area | Component | Motion Level | Flutter Implementation | Behavior & Constraints |
|---|---|---|---|---|
| **Explore Feed** | Itinerary Card (`property-card`) | Subtle (Web) / None (Mobile) | `AnimatedContainer` | **Web:** Elevation shadow deepens on hover over 180ms. **Mobile:** Zero hover animation; direct touch ripple via `InkWell`. |
| **Explore Feed** | Favorite Heart Button | Expressive | Explicit `AnimationController` | Scale bounce (`1.0` $\to$ `0.85` $\to$ `1.15` $\to$ `1.0`) over 220ms on save. Fill toggles immediately to Rausch `#FF385C`. Non-blocking. |
| **Global Search** | Web Search Pill & Orb | Subtle | `AnimatedContainer` / `InkResponse` | Hover segment background tints to `surface-soft` (`#F7F7F7`) over 120ms. Search orb press shifts to `primary-active` (`#E00B41`). |
| **Global Search** | Mobile Search Expansion | Moderate | `PageRouteBuilder` or Modal Sheet | Compact 48px search pill expands into full-screen search view with slide-up + fade over 220ms (`Curves.easeOutCubic`). |
| **Itinerary Detail** | Day Card Accordion | Moderate | `AnimatedCrossFade` or `SizeTransition` | Expanding/collapsing day schedule activities animates over 200ms (`Curves.easeInOutCubic`). Header icons rotate 180°. |
| **Itinerary Detail** | Activity Reorder Dialog | Subtle / Native | `ReorderableListView` | Native smooth displacement of items during drag; drag elevation shadow. Settles into final order instantly upon drop. |
| **Itinerary Detail** | Sticky Action Rail / Bottom Bar | Subtle | `AnimatedSlide` | On mobile scroll, bottom action bar slides up from safe area over 180ms if revealed dynamically. |
| **Forms & Dialogs** | Day / Activity Dialogs | Moderate | `Dialog` with `scale` / `fade` transition | Modal appears with subtle scale (`0.96` to `1.0`) and fade (`0.0` to `1.0`) over 180ms. Scrim fades in over 150ms. |
| **System States** | Button Loading Spinner | Subtle | `AnimatedSwitcher` | Label text fades out as 18x18dp white `CircularProgressIndicator` fades in over 150ms, maintaining button dimensions. |
| **System States** | Skeleton Shimmer | Subtle | Custom painter or animated gradient | Continuous subtle gradient shift across placeholder card over 1500ms; stops immediately once network payload arrives. |
| **Admin Web** | Tables, Moderation, Audit | **None** | Direct widget rebuild | Fast, direct updates. No row animations, no page flip motion. Preserves moderation speed. |

---

## 6. Accessibility & Reduced Motion (Mandatory)

Motion must never compromise accessibility, cause nausea, or trigger vestibular discomfort.

### 6.1 Respecting Platform Reduced Motion Settings
Every animated widget must check `MediaQuery.of(context).disableAnimations`:
- In Flutter, `disableAnimations` is automatically populated from the operating system's accessibility settings (Android "Remove animations", iOS "Reduce Motion", Web `prefers-reduced-motion`).
- When `disableAnimations == true`:
  - Durations must be reduced to `Duration.zero` or transitions replaced with an instant opacity cut.
  - Parallax, large spatial translations, and bouncy spring effects are completely disabled.

```dart
final bool disableMotion = MediaQuery.of(context).disableAnimations;
final Duration effectiveDuration = disableMotion 
    ? Duration.zero 
    : const Duration(milliseconds: 200);

AnimatedOpacity(
  duration: effectiveDuration,
  opacity: isVisible ? 1.0 : 0.0,
  child: child,
);
```

### 6.2 Vestibular Safety Rules
- **Maximum Spatial Translation:** Offsets for entrances or transitions must not exceed `24dp`. Full-screen sweeps or flying cards across viewports are prohibited.
- **No Continuous Looping Motion on Content:** Shimmers are permitted only during pending loading states; once content resolves, all continuous motion must stop.
- **Preserve Hit Targets:** Hit testing areas (minimum $48\times 48\text{dp}$) must remain stable during interaction. Never scale an interactive hit box down to an inaccessible size.

---

## 7. Performance & Resource Budgets

Flutter renders at the display refresh rate (60Hz or 120Hz ProMotion). Animations that cause frame drops degrade perceived quality worse than having no animation at all.

### 7.1 Performance Checklist
1. **Animate Transform and Opacity Only:**
   - Prefer `Transform.translate`, `Transform.scale`, and `Opacity` (or their transition equivalents `SlideTransition`, `ScaleTransition`, `FadeTransition`).
   - **Never animate layout-triggering properties** (e.g., animating `width`, `height`, or `margin` on large widget trees without `RepaintBoundary`), as this forces continuous layout calculations across the widget subtree.
2. **Use `const` Constructors:** Ensure static subtrees passed to `AnimatedBuilder` or custom transitions are provided as the pre-built `child` argument to prevent re-instantiation on each tick.
3. **Flutter Web Considerations:**
   - Excessive backdrop filters (`BackdropFilter`), complex box shadows, and multiple simultaneous running tickers cause jank in the HTML/CanvasKit renderers.
   - Keep Flutter Web animations minimal and lightweight.
4. **Dispose Controllers:** Verify that every controller initialized in `initState` has a matching call in `dispose()`.

---

## 8. Verification and Automated Testing

UI tasks that introduce or adjust animations must include verification checks:

### 8.1 Widget Testing Guidelines
- **Use `tester.pump()` for Step-by-Step Ticks:** Test intermediate animation states using `await tester.pump(const Duration(milliseconds: 100));`.
- **Caution with `tester.pumpAndSettle()`:**
  - `tester.pumpAndSettle()` pumps frames until all scheduled microtasks and animations finish.
  - **Do NOT use `pumpAndSettle()`** on screens containing infinite recurring animations (such as looping `CircularProgressIndicator` or endless shimmer loops), as this will cause tests to time out after 10 minutes.
  - For screens with spinners, use `await tester.pump(const Duration(milliseconds: 200));` to settle transient transitions while leaving the continuous indicator running.

### 8.2 PR and Task Review Checklist
When concluding a Flutter UI task involving animations, verify:
- [ ] Existing code and widgets were inspected before choosing the animation.
- [ ] The motion level was consciously chosen (None, Subtle, Moderate, Expressive).
- [ ] No third-party React, npm, or unapproved Flutter packages were added.
- [ ] The animation defaults to subtle and does not block user productivity.
- [ ] `disableAnimations` / reduced motion is handled gracefully.
- [ ] All `AnimationController` instances are properly disposed.
- [ ] Widget tests verify initial, transitional, and settled states without timeout errors.

---

## 9. Agent Reporting Requirements

Whenever an agent implements or modifies a Flutter UI feature involving motion, the task completion report must include an **Animation Analysis Section**:

1. **Motion Assessment:** State which motion level was selected (Level 0 None, Level 1 Subtle, Level 2 Moderate, Level 3 Expressive) and why.
2. **Frequency-of-Use Justification:** Explain how the component's frequency of use informed the decision.
3. **Implementation Technique:** State whether implicit (`AnimatedContainer`, etc.) or explicit (`AnimationController`) widgets were used.
4. **Lifecycle & Accessibility:** Confirm that controller disposal was implemented and that reduced motion is respected.
5. **Zero-Motion Decisions:** If the agent decided that no animation was necessary, state the rationale explicitly (e.g., *"Administrative table pagination kept at Level 0 (None) to maintain immediate data scanning velocity"*).
