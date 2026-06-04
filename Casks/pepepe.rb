cask "pepepe" do
  version "1.0.2"
  sha256 "938461e5739dee66145c742034c27e815def34d434ec22c7bfca02a0ee1a92a8"

  url "https://github.com/anggiedimasta/pepepe/releases/download/v#{version}/Pepepe-v#{version}.zip"
  name "Pepepe"
  desc "Menu bar ping and WiFi monitor"
  homepage "https://github.com/anggiedimasta/pepepe"

  depends_on macos: ">= :sonoma"

  app "Pepepe.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", staged_path/"Pepepe.app"]
  end

  zap trash: [
    "~/Library/Application Support/Pepepe",
  ]
end
