# frozen_string_literal: true

class Snip < Formula
  desc "macOS clipboard and keyboard diagnostic tool"
  homepage "https://github.com/clanzhang/snip"
  url "https://github.com/clanzhang/snip/archive/refs/tags/v0.1.9.tar.gz"
  sha256 "b36a54af9534658ce9df78afab5c8b00efe2476502e5cb8a43821bd7cee357b0"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  # 预编译二进制 (bottle)
  # 发布流程:
  #   1. brew install --build-bottle snip
  #   2. brew bottle snip
  #   3. 上传 snip--*.tar.gz 到 GitHub Releases
  #   4. 替换下方 sha256 为实际值
  bottle do
    root_url "https://github.com/clanzhang/homebrew-tap/releases/download/v0.1.9"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "REPLACE_WITH_BOTTLE_SHA256"
  end

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    system "swift", "test", "--disable-sandbox"
    bin.install ".build/release/snip"
  end

  test do
    system "#{bin}/snip", "--version"
  end
end