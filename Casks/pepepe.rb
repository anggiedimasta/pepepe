cask "pepepe" do
  version "1.0.3"
  sha256 "ebad40f6ffc381c7b38f8900092209e539d98f2c03e32c9afd95001e5b675534"

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
