cask "pepepe" do
  version "1.0.5"
  sha256 "91266cbb2f807cf6782ef0ce4e05e2efaa3bcd44b866eddf94d705da52ef6f7e"

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
