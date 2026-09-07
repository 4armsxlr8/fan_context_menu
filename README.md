# fan_context_menu

A Flutter package for a fan-shaped menu: press and hold, slide to an action, release to execute. Long-pressing a target Widget opens 2 to 5 action buttons in a fan around the press point. Without lifting your finger, slide onto one of the action buttons to highlight it, and release while it's highlighted to execute that action.

<p align="center">
  <img src="https://raw.githubusercontent.com/4armsxlr8/fan_context_menu/main/doc/demo.gif" width="270" alt="Press and hold a pin, slide onto the save action button, and release to execute it.">
</p>

## Installation

Local reference:

```yaml
dependencies:
  fan_context_menu:
    path: /path/to/fan_context_menu
```

pub.dev reference:

```yaml
dependencies:
  fan_context_menu: ^0.1.0
```

## Usage

Wrap the whole area where you want the fan-shaped menu with `FanContextMenuHost`. The host defines the area where the dimming, lifted copy, and action buttons are drawn.

```dart
FanContextMenuHost(
  child: Stack(
    children: [
      // Your screen content
    ],
  ),
)
```

Wrap each target that should open the fan-shaped menu with `FanContextMenuTarget`. `FanContextMenuTarget` must be placed under a host (otherwise it reports a `FlutterError` in debug mode).

```dart
FanContextMenuTarget(
  actions: const [
    FanContextMenuAction(
      icon: Icon(Icons.favorite_border),
      semanticLabel: 'React',
    ),
    FanContextMenuAction(
      icon: Icon(Icons.share),
      semanticLabel: 'Share',
    ),
    FanContextMenuAction(
      icon: Icon(Icons.bookmark_border),
      semanticLabel: 'Save',
    ),
  ],
  onAction: (index) {
    const labels = ['React', 'Share', 'Save'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Executed ${labels[index]}')),
    );
  },
  child: Container(
    width: 160,
    height: 160,
    decoration: BoxDecoration(
      color: Colors.blueGrey,
      borderRadius: BorderRadius.circular(16),
    ),
  ),
)
```

## Specifying actions

`actions` takes 2 to 5 `FanContextMenuAction` values (0 or 1, or 6 or more, throws `ArgumentError`). Each action has an icon Widget drawn on its action button and a name a screen reader reads aloud (`semanticLabel`). An empty or whitespace-only `semanticLabel`, or a `semanticLabel` that duplicates another one within the same Widget, also throws `ArgumentError`.

When an action is executed, `onAction(index)` is called. `index` is the position of the action in the list passed to `actions`.

## Notifications

`FanContextMenuTarget` reports state changes in the fan-shaped menu through these callbacks:

- `onOpened`: when the fan-shaped menu opens (once)
- `onHighlightChanged`: called every time the highlight changes (the index it moved onto / `null` when it moved off)
- `onAction`: when the finger is released while an action button is highlighted, and that action is executed (`onClosed` is not called)
- `onClosed`: when the finger is released with nothing highlighted, or the gesture is interrupted. Nothing is executed (`onAction` is not called)

The callbacks fire in this order: `onOpened` (once) -> `onHighlightChanged` (every time the highlight changes) -> `onAction` or `onClosed` (exactly one of the two).

## Playing haptics from the notifications

The package itself never calls `HapticFeedback`. If you want haptics, play them yourself in response to the notifications.

```dart
FanContextMenuTarget(
  actions: actions,
  onAction: onAction,
  onOpened: HapticFeedback.mediumImpact,
  onHighlightChanged: (i) {
    if (i != null) HapticFeedback.selectionClick();
  },
  child: child,
)
```

`onOpened` plays `mediumImpact` the instant the menu opens, and `onHighlightChanged` plays `selectionClick` whenever it's called with a non-null value (the finger newly landed on an action button).

## Style

`FanContextMenuHost`'s `style` (`FanContextMenuStyle`) lets you change every look-and-feel and timing value at once.

| Property | Default | Meaning |
| --- | --- | --- |
| `longPressDuration` | `Duration(milliseconds: 500)` | Time until a long press is recognized |
| `openDuration` | `Duration(milliseconds: 180)` | Duration of the open/close animation of the fan-shaped menu |
| `highlightDuration` | `Duration(milliseconds: 120)` | Duration of the animation when an action button's highlight changes |
| `dimmingOpacity` | `0.6` | Opacity of the dimming layer (0 to 1) |
| `liftScale` | `1.08` | Scale factor of the lifted copy |
| `tiltDegrees` | `-3.0` | Tilt of the lifted copy (degrees) |
| `buttonDiameter` | `48.0` | Diameter of an action button |
| `highlightScale` | `1.35` | Scale factor of a highlighted action button |
| `actionButtonEnterScale` | `0.6` | Initial scale factor of an action button as it emerges from the press point |
| `arcRadius` | `66.0` | Radius of the fan-shaped menu's arc |
| `sweepDegrees` | `180.0` | Sweep angle of the arc (degrees) |
| `arcLiftDegrees` | `40.0` | Angle that tilts the center of the arc upward from horizontal (degrees) |
| `actionButtonColor` | `Color(0xFF3C3C3C)` | Color of an unhighlighted action button |
| `highlightedActionButtonColor` | `Color(0xFFFFFFFF)` | Color of a highlighted action button |
| `iconColor` | `Color(0xFFFFFFFF)` | Color of an unhighlighted icon |
| `highlightedIconColor` | `Color(0xFF000000)` | Color of a highlighted icon |

Setting `sweepDegrees` to exactly `360` spaces all action buttons evenly around the full circle so the two ends of the arc don't overlap.

## Invalid values

`FanContextMenuHost` or `FanContextMenuTarget` throws `ArgumentError` at construction time (this is a normal execution path, not an assert, so it's rejected in release builds too) in the following cases:

- `actions` has 0 or 1 elements, or 6 or more (2 to 5 is accepted)
- an `actions` `semanticLabel` is empty, or only whitespace (half-width/full-width spaces, newlines, tabs)
- an `actions` `semanticLabel` duplicates another one within the same Widget
- `longPressDuration` / `openDuration` / `highlightDuration` is non-positive (`Duration.zero` or negative)
- `dimmingOpacity` is below 0, above 1, or NaN (0 to 1 is accepted)
- `buttonDiameter` / `arcRadius` / `liftScale` / `highlightScale` / `actionButtonEnterScale` is non-positive, NaN, or infinite
- `sweepDegrees` is 0 or below, or above 360, or NaN (360 is accepted)
- `tiltDegrees` / `arcLiftDegrees` is NaN or infinite (negative values are accepted)

## Accessibility

`FanContextMenuTarget` automatically attaches a custom semantics action for each action, so a screen reader can perform the same operations as the fan-shaped menu. The spoken name of the target Widget itself is left to the `Semantics` your app attaches to `child` (`FanContextMenuTarget` itself carries no spoken name).

## Running the example

```sh
cd example && flutter run
```

## Limitations

- Long-press only. The fan-shaped menu does not open on right-click.
- On the web, holding the mouse button down is treated as a long press.
- Fitting the action buttons on screen is not guaranteed for radius/diameter combinations other than the defaults.
- Outside the host is never dimmed (only the area the host wraps is dimmed).
- If the `child` you pass has a `GlobalKey` or holds input state, you need `liftedChildBuilder` to substitute the look of the lifted copy, since such a `child` can't simply be duplicated.
