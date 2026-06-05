cask "pepepe" do
  version "1.0.6"
  sha256 "519f7d53f88bc14e50df38ea489c18cfde333c683fe3916ff35057eb36f9fc50"

  url "https://github.com/anggiedimasta/pepepe/releases/download/v#{version}/Pepepe-v#{version}.zip"
  name "Pepepe"
  desc "Menu bar ping and WiFi monitor"
  homepage "https://github.com/anggiedimasta/pepepe"

  depends_on macos: ">= :sonoma"

  app "Pepepe.app"

  uninstall quit: "com.anggiedimasta.pepepe"

  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", staged_path/"Pepepe.app"]
  end

  zap trash: [
    "~/Library/Application Support/Pepepe",
  ]
end
