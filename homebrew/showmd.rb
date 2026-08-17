cask "showmd" do
  version "1.0.4"
  sha256 "44f71e62ab2abf23226ed1eeec06e72835442a47022d54ec4cbd1fcbd31f677d"

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
