cask "showmd" do
  version "1.0.2"
  sha256 "e01fde6bb7d57531e9da64acbf8eb6175809f6c3513a42038e44c8c2e5b5533b"

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
