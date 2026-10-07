class Tomales < Formula
  desc "Keep display awake and monitor your Mac from the menu bar"
  homepage "https://github.com/EnvyEternal/tomales"
  url "https://github.com/EnvyEternal/tomales/releases/download/v0.2.2/Tomales-0.2.2-source.tar.gz"
  version "0.2.2"
  sha256 "b344b2af263da4e6e9706ec112a597cbf24333497f2d7f3adb1727a1b013bc2d"
  license "MIT"

  depends_on macos: :ventura

  def install
    ENV["TOMALES_ARCHITECTURE"] = "native"
    ENV["TOMALES_HOMEBREW_TAP"] = "EnvyEternal/tomales"
    ENV["TOMALES_HOMEBREW_KIND"] = "formula"
    system "/bin/bash", "scripts/build.sh"
    prefix.install "dist/Tomales.app"

    bin.mkpath
    (bin/"tomales").write <<~SH
      #!/bin/bash
      set -euo pipefail
      if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--restart" ) ]]; then
        echo "Usage: tomales [--restart]" >&2
        exit 2
      fi
      if [[ "${1:-}" == "--restart" ]] && /usr/bin/pgrep -x Tomales >/dev/null; then
        /usr/bin/osascript -e 'tell application id "app.tomales.menubar" to quit'
        for attempt in {1..30}; do
          if ! /usr/bin/pgrep -x Tomales >/dev/null; then break; fi
          /bin/sleep 0.1
        done
        if /usr/bin/pgrep -x Tomales >/dev/null; then
          echo "Quit Tomales before reopening the updated version." >&2
          exit 1
        fi
      fi
      exec /usr/bin/open '#{opt_prefix}/Tomales.app'
    SH
    (bin/"tomales").chmod 0755
  end

  def caveats
    <<~EOS
      Tomales is built locally with Apple's Swift compiler; no Apple Developer subscription is needed.
      Use current Command Line Tools or Xcode with Swift 5.9 or newer.
      Launch: tomales
      Update: brew update && brew upgrade EnvyEternal/tomales/tomales && tomales --restart
      Restarting ends an active keep-awake session and keeps your preferences.
      App location: #{opt_prefix}/Tomales.app
    EOS
  end
end
