cask "showmd" do
  version "1.0.3"
  sha256 "d8a372085ac700825d82a118d000d98b4c5bd6da21f2d7986b51f7f59e16eafb"

  url "https://github.com/johannesnagl/showmd/releases/download/v#{version}/showmd-#{version}.zip"
  name "showmd"
  desc "Quick Look extension that renders Markdown beautifully on macOS"
  homepage "https://showmd.yetanother.one"

  depends_on macos: :tahoe

  app "showmd.app"

  postflight do
    system_command "/usr/bin/qlmanage", args: ["-r"]
  end

  zap trash: [
    "~/Library/Group Containers/group.one.yetanother.showmd",
  ]
end
