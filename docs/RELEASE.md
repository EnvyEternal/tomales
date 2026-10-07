# Personal releases

The public source repository and Homebrew tap are both `EnvyEternal/tomales`. Keep releases on this personal account. Do not use company credentials or repositories.

## Current distribution

Homebrew builds the native app from source with the user's Apple compiler. This route requires no Apple Developer subscription and makes no changes to Gatekeeper or quarantine settings. Users need macOS 13 or later, Homebrew, and current Command Line Tools or Xcode with Swift 5.9 or newer. The app has no external Swift package dependencies.

One installation line:

```sh
brew tap EnvyEternal/tomales https://github.com/EnvyEternal/tomales && brew install EnvyEternal/tomales/tomales && tomales --restart
```

One update line:

```sh
brew update && brew upgrade EnvyEternal/tomales/tomales && tomales --restart
```

The explicit tap URL makes a separate `homebrew-tomales` repository unnecessary. Homebrew manages the bundle in the formula's prefix and symlinks its `tomales` launcher into the normal Homebrew `bin` directory. The launcher follows the stable `opt` path across upgrades. Normal launch leaves an existing instance running; `--restart` quits it before opening the new app. Preferences are preserved and active awake sessions end when restarting.

Formula builds embed the correct update command in Settings. Local builds without a tap keep their local-installation information. Uninstalling the formula does not delete preferences.

## Publish a version

1. Update `VERSION` and `Resources/Info.plist` to the same numeric `X.Y.Z`, and write `docs/RELEASE_NOTES.md`.
2. Commit and push the desired source to `main`.
3. Create and push its matching tag:

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

`.github/workflows/release.yml` runs on a GitHub Ubuntu runner. It validates the personal repository and version, creates a source archive from the tagged commit, computes SHA-256, and generates the formula using `homebrew/tomales.rb.in`. It publishes the source archive and checksums to GitHub Releases before committing the formula to `main`. The formula downloads that exact archive and verifies its hash. Versions below 1.0 are marked as prereleases.

The workflow uses the repository's own `GITHUB_TOKEN` with Contents write permission. No personal token, second repository, signing secret, or Apple credentials are needed. If repository policies block Actions from writing, enable repository workflow write access. Branch protection must allow the formula update or it needs to be submitted through a pull request instead.

No test suite runs automatically. Runtime behavior, sensor compatibility, and resource use remain unverified unless the user separately requests those checks.

## Recovery

If the release exists but the formula push fails, download the existing source archive and run:

```sh
python3 scripts/generate-formula.py --repository EnvyEternal/tomales --tap EnvyEternal/tomales --archive dist/Tomales-X.Y.Z-source.tar.gz --output Formula/tomales.rb
```

Commit and push the generated formula to `main`. Always use the exact published archive. Do not replace a published version with changed source or downloads; release a new version instead.

If a formula is already installed but needs rebuilding, use:

```sh
brew reinstall EnvyEternal/tomales/tomales && tomales --restart
```

## Optional signed downloads later

Local `scripts/package.sh --universal` outputs are ad-hoc signed development packages. A downloaded app for general distribution should use Developer ID signing and notarization. This requires the user's own Apple Developer membership and certificate. No company credentials should be reused.

The previous signed-release workflow is preserved as an inactive example in `docs/examples/release-signed.yml`. It is not part of the current Actions pipeline. Adapt its personal repository/tap variables and release flow before enabling it; it needs signing/notarization secrets and a separate cask tap. Do not enable both workflows for the same version without coordinating release publication.

For local signed packaging, store personal notarization credentials with `xcrun notarytool store-credentials`, then use:

```sh
export TOMALES_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export TOMALES_NOTARY_PROFILE='tomales-notary'
export TOMALES_REPOSITORY='EnvyEternal/tomales'
export TOMALES_HOMEBREW_TAP='EnvyEternal/tomales'
./scripts/package.sh --release
```

Keep bundle identifier `app.tomales.menubar` stable so preferences and app identity survive upgrades.

Sources: [Homebrew taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap), [formula cookbook](https://docs.brew.sh/Formula-Cookbook), [Apple Developer ID](https://developer.apple.com/developer-id/), [Apple notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
