# Xcode Project Setup (Mira)

This project uses Swift Package Manager. The included `Mira.xcodeproj` is a lightweight wrapper so you can use Signing & Capabilities (iCloud) locally.

## Steps in Xcode

1. Open `Mira.xcodeproj`
2. Select the **Mira** target → **Signing & Capabilities**
3. Choose your **Team**
4. Add **iCloud** capability → enable **CloudKit** → select `iCloud.com.snupai.Mira`

## Add Source Files

If the project does not already contain the source files:

- Right‑click the **Mira** group → **Add Files to "Mira"...**
- Select everything inside `Sources/Mira/` (App, Models, Views, Services, etc.)
- Choose **Reference files in place**
- Ensure **Add to targets: Mira** is checked

## Build

Press **⌘R** to run. This will create a provisioning profile with iCloud entitlements.
