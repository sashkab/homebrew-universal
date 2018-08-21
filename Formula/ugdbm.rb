class Ugdbm < Formula
  desc "GNU database manager"
  homepage "https://www.gnu.org/software/gdbm/"
  url "https://ftp.gnu.org/gnu/gdbm/gdbm-1.17.tar.gz"
  mirror "https://ftpmirror.gnu.org/gdbm/gdbm-1.17.tar.gz"
  sha256 "7cd8cc2e35b1aaede6084ea57cc9447752f498daaea854100a4bad567614977d"

  keg_only "avoiding conflict with Homebrew/core"
  option :universal
  option "with-libgdbm-compat", "Build libgdbm_compat, a compatibility layer which provides UNIX-like dbm and ndbm interfaces."

  # Remove for > 1.17
  # Upstream commit from 31 July 2018: "(gdbm_sync): Always return a meaningful value"
  patch do
    url "http://git.gnu.org.ua/cgit/gdbm.git/patch/?id=1059526e357da1aa92e5c020332f4b39ceb37503"
    sha256 "c7b13e3779b6701fa3c802e22d383341a483db7419c533ffbca9766ee4688575"
  end

  # Use --without-readline because readline detection is broken in 1.13
  # https://github.com/Homebrew/homebrew-core/pull/10903
  def install
    ENV.universal_binary if build.universal?

    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --without-readline
      --prefix=#{prefix}
    ]

    args << "--enable-libgdbm-compat" if build.with? "libgdbm-compat"

    system "./configure", *args
    system "make", "install"
  end

  test do
    pipe_output("#{bin}/gdbmtool --norc --newdb test", "store 1 2\nquit\n")
    assert_predicate testpath/"test", :exist?
    assert_match /2/, pipe_output("#{bin}/gdbmtool --norc test", "fetch 1\nquit\n")
  end
end
