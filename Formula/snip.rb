# frozen_string_literal: true

class Snip < Formula
  desc "macOS clipboard and keyboard diagnostic tool"
  homepage "https://github.com/clanzhang/snip"
  url "https://github.com/clanzhang/snip/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "2bd858b0d3979891f50d2a9c106a190b21af8aa1a1cf2405a498e77c86d751ac"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  # 预编译二进制 (bottle) — 后续发布时替换 sha256
  # 生成方式: brew bottle --root-url=https://github.com/clanzhang/homebrew-tap/releases/download/v0.1.0 snip
  bottle do
    root_url "https://github.com/clanzhang/homebrew-tap/releases/download/v0.1.0"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "REPLACE_WITH_BOTTLE_SHA256"
  end

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/snip"
  end

  test do
    system "#{bin}/snip", "--version"
  end
end