# App Intents

`Intents/PhotoPedalIntents.swift` defines two foreground-app intents:

| Intent | Behavior | Limitation |
| --- | --- | --- |
| `CreatePedalIntent` | Sets `AppIntentRouter` to `.create`; UI opens camera flow | Does not capture or create autonomously |
| `PlayLastPedalIntent` | Sets router to `.playLast`; UI requests playback | Does not directly render audio; reloads only when the view model has no pedal |

Both set `openAppWhenRun = true`. `PhotoPedalShortcuts` exposes Portuguese phrases. There is no intent parameter, `AppEntity`, entity query, play-by-name behavior, or deep-link routing.

Validate routing, camera permission, stored-pedal availability, foreground launch, audible playback, and Siri/Shortcuts behavior on a physical device. The current intent design does not claim background audio playback support.
