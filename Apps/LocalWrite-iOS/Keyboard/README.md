# LocalWrite Keyboard

The iOS version is a custom keyboard extension.

The keyboard stays deliberately small:

- microphone action
- recording state
- automatic insertion into the current text field
- globe/next-keyboard control

The containing app owns onboarding and settings.

Apple custom keyboards have tighter resource constraints, so the extension should avoid unnecessary UI and delegate refinement to LocalWriteCore.
