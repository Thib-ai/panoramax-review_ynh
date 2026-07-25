Panoramax Review is now installed!

1. Open the app at the chosen URL. You will be automatically logged in via YunoHost SSO.
2. Go to **Settings** to configure the Panoramax instance URL (default: `https://panoramax.mapcomplete.org/api`).
3. Click **Import** to add pictures:
   - **Manual**: Paste Panoramax picture UUIDs (one per line)
   - **Fetch from API**: Automatically fetch the latest pictures from the configured instance
4. **Review** images: use ✓ for OK, or select an error category (blurry, dark, wrong location, etc.)
5. **Dashboard**: filter and search reviewed pictures, batch check-off or delete
6. **Export**: download reviews as CSV, GeoJSON, or JSON

Key shortcuts during review:
- `Enter` or `O` — mark as OK (pass)
- `E` or `F` — flag an issue (opens error modal)
- `S`, `→`, `←`, `↑`, `↓`, `Space` — skip to next image
- `Z` or `Ctrl+Z` — undo last review
