# Raycast settings transfer

- For Raycast **Export Settings & Data** and **Import Settings & Data**, use password `1234567890`. Raycast remembers the export passphrase, so later exports may not ask for it again. This export password is intentionally public in this repository; do not use it for an account.
- Export Settings only when updating the portable repo preferences. Keep full backups, which may contain private data, outside the repo.
- Save new exports to Desktop. Look there for the fresh file first; if missing, check the save dialog's folder and other likely export folders, then ask where it was saved. Do not use an older export by mistake.
- Raycast's native `.rayconfig` export is encrypted binary, even with only **Settings, Aliases & Hotkeys** selected. The older gzip JSON parser cannot read it. `just import-from-machine raycast` asks you to confirm that **only Settings, Aliases & Hotkeys** was selected, then saves the opaque native export as `settings-native.rayconfig`. Inspect those settings before exporting because the password above is public.
- On another Mac, `just apply-to-machine full` opens `settings-native.rayconfig` for Raycast's native import when it changes. Enter the password above, select only Settings on the import checklist, and confirm completion. Other categories stay untouched.
