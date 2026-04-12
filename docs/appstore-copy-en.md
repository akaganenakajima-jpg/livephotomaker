# App Store Copy Draft (English)

> **Review note**: This app's sole responsibility is to create a Live Photo from a video and save it to the user's Photos library. Setting the saved Live Photo as a lock-screen wallpaper is done by the user in the iOS Settings app. The app does not and cannot set wallpapers automatically.

## App Name
**Video to Live Photo**

## Subtitle (max 30 chars)
**Turn videos into Live Photos**

## Promotional Text (max 170 chars)
Create short Live Photos from your favorite videos and save them to your Photos library. An in-app guide shows you how to use them as lock-screen wallpapers.

## Description

Video to Live Photo is a simple utility that turns your videos into Live Photos and saves them to your iPhone's Photos library.

Once saved, you can pick your Live Photo as a lock-screen wallpaper from the standard iOS Settings app. The app shows you a clean step-by-step guide to help you do that.

### Highlights
- Trim a short clip from any video and save it as a Live Photo
- Preview the Live Photo right after it is created
- In-app guide for choosing the Live Photo as a lock-screen wallpaper (from the iOS Settings app — the app never navigates there for you)
- Optimized for portrait, wallpaper-friendly layouts

### Pricing
- Free: standard quality export (ads shown)
- One-time HQ trial: watch a short ad to export one Live Photo in high quality
- One-time unlock: permanently unlock high-quality export and remove ads
  - Product ID: `com.gen.videotolivephoto.premium.hq_unlock`
  - Non-consumable (buy once, available forever across reinstalls via Restore)

### Important
- The app does not set wallpapers for you. iOS does not permit third-party apps to set the lock-screen wallpaper on the user's behalf.
- After saving, open the iOS Settings app and pick the Live Photo under Wallpaper.

---

## Keywords (max 100 chars, comma-separated)
```
Live Photo,video,wallpaper,lock screen,animated,convert,save,portrait,motion,iPhone
```

## Support URL (placeholder)
https://akaganenakajima-jpg.github.io/livephotomaker/

## Marketing URL (placeholder)
https://akaganenakajima-jpg.github.io/livephotomaker/

## Age Rating
4+

## Category
- Primary: Photo & Video
- Secondary: Utilities

---

## App Review Notes (draft)

- The app only creates and saves Live Photos. It never sets the wallpaper on behalf of the user.
- The non-consumable IAP `com.gen.videotolivephoto.premium.hq_unlock` permanently unlocks high-quality export and hides all ads. After reinstalling, users can use "Restore Purchase" to re-enable it.
- Only rewarded ads are used, and only when the user explicitly taps "Watch ad for HQ trial". Progress screens are never interrupted by ads.
- Photo library access is requested with `.addOnly` authorization only.
- No private APIs are used.
- No test account is required; all features work in-app.
- Technical stack: React Native (Expo SDK 51) + TypeScript. Live Photo MOV/JPEG tagging and the `PHAssetCreationRequest` save are implemented in a custom Expo Module written in Swift. Builds and submissions are produced via EAS Build / EAS Submit (cloud).
