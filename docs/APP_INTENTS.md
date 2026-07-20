# App Intents

`Intents/PhotoPedalIntents.swift` defines two foreground-app intents:

| Intent | Behavior | Limitation |
| --- | --- | --- |
| `CreatePedalIntent` | Sets `AppIntentRouter` to `.create`; UI opens transient central Capture | Does not capture or create autonomously |
| `PlayLastPedalIntent` | Sets router to `.playLast`; Gallery requests playback of the shared latest selection | Does not directly render audio or sort records |

Both set `openAppWhenRun = true`. `DapShortcuts` exposes Portuguese phrases. There is no intent parameter, `AppEntity`, entity query, play-by-name behavior, or deep-link routing.

Validate routing, camera permission, stored-pedal availability, foreground launch, audible playback, and Siri/Shortcuts behavior on a physical device. The current intent design does not claim background audio playback support.
