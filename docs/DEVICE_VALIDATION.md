# Device Validation

This is a reusable checklist, not a run report.

## Required For Every Audio Milestone

- Test first and repeated playback.
- Test reverb and distortion selection and intensity changes.
- Test wired headphones and Bluetooth audio.
- Test route changes and interruption by other audio or calls.
- Background and foreground the app during and after playback.
- Check silent-mode behavior and volume expectations.
- Confirm app relaunch reloads the latest pedal.

## Required For Release Candidates

- Test camera permission denied, limited, and granted states.
- Capture with the camera and import through the photo library.
- Check Foundation Models available, unavailable, refusal, and invalid-output paths.
- Test App Intents through Shortcuts and Siri, including foreground launch.
- Test haptics when a feature introduces them.
- Create multiple pedals repeatedly and observe memory behavior.
- Verify persistence after termination and relaunch.

## Optional Exploratory Checks

- Different device classes and locales.
- AirPlay or external audio routes.
- Low-power mode and low-storage behavior.
- Accessibility settings, including Reduce Motion, after relevant UI work.

Record results in the feature or release work that prompted the validation; do not create standalone device reports unless requested.
