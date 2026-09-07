## 0.1.0

- Initial release. Publishes `FanContextMenuHost`, `FanContextMenuTarget`, `FanContextMenuAction`, and `FanContextMenuStyle`.
- A fan-shaped menu: press and hold, slide to an action, release to execute. Accepts 2 to 5 actions, and notifies highlight changes, execution, and cancellation of action buttons.
- Look-and-feel and timing values can all be changed at once via `FanContextMenuStyle`.
- Invalid `FanContextMenuStyle` / action specifications are rejected with `ArgumentError` (including duplicate spoken names).
