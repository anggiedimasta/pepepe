cask "pepepe" do
  version "1.0.4"
  sha256 "5a3d132b2be9e3144a848e38df6a033a9790cce673578ac2d68a3307b3ee870c"

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
