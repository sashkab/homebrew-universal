# This formula tracks 1.0.2 branch of OpenSSL, not the 1.1.0 branch. Due to
# significant breaking API changes in 1.1.0 other formulae will be migrated
# across slowly, so core will ship `openssl` & `openssl@1.1` for foreseeable.
class Uopenssl < Formula
  desc "SSL/TLS cryptography library"
  homepage "https://openssl.org/"
  url "https://www.openssl.org/source/openssl-1.0.2p.tar.gz"
  mirror "https://dl.bintray.com/homebrew/mirror/openssl--1.0.2p.tar.gz"
  mirror "https://www.mirrorservice.org/sites/ftp.openssl.org/source/openssl-1.0.2p.tar.gz"
  mirror "http://artfiles.org/openssl.org/source/openssl-1.0.2p.tar.gz"
  sha256 "50a98e07b1a89eb8f6a99477f262df71c6fa7bef77df4dc83025a2845c827d00"

  keg_only :provided_by_macos,
    "Apple has deprecated use of OpenSSL in favor of its own TLS and crypto libraries"

  option :universal
  option "without-test", "Skip build-time tests (not recommended)"

  deprecated_option "without-check" => "without-test"

  depends_on "makedepend" => :build

  def arch_args
    {
      :x86_64 => %w[darwin64-x86_64-cc enable-ec_nistp_64_gcc_128],
      :i386 => %w[darwin-i386-cc],
    }
  end

  def configure_args; %W[
    --prefix=#{prefix}
    --openssldir=#{openssldir}
    no-ssl2
    no-ssl3
    no-zlib
    shared
    enable-cms
  ]
  end

  def install
    # OpenSSL will prefer the PERL environment variable if set over $PATH
    # which can cause some odd edge cases & isn't intended. Unset for safety,
    # along with perl modules in PERL5LIB.
    ENV.delete("PERL")
    ENV.delete("PERL5LIB")

    if build.universal?
      ENV.permit_arch_flags
      archs = Hardware::CPU.universal_archs
    elsif MacOS.prefer_64_bit?
      archs = [Hardware::CPU.arch_64_bit]
    else
      archs = [Hardware::CPU.arch_32_bit]
    end

    dirs = []

    archs.each do |arch|
      if build.universal?
        dir = "build-#{arch}"
        dirs << dir
        mkdir dir
        mkdir "#{dir}/engines"
        system "make", "clean"
      end

      ENV.deparallelize
      system "perl", "./Configure", *(configure_args + arch_args[arch])
      system "make", "depend"
      system "make"
      system "make", "test" if build.with?("test")

      next unless build.universal?
      cp "include/openssl/opensslconf.h", dir
      cp Dir["*.?.?.?.dylib", "*.a", "apps/openssl"], dir
      cp Dir["engines/**/*.dylib"], "#{dir}/engines"
    end

    system "make", "install", "MANDIR=#{man}", "MANSUFFIX=ssl"

    if build.universal?
      %w[libcrypto libssl].each do |libname|
        $stdout.print "dirs=",dirs,"\n"
        $stdout.print "libname=",libname,"\n"
        $stdout.print "Removing ","#{lib}/#{libname}.1.0.0.dylib","\n"
        rm_f "#{lib}/#{libname}.1.0.0.dylib"
        $stdout.print "macho\n"
        MachO::Tools.merge_machos("#{lib}/#{libname}.1.0.0.dylib",
                                  "#{dirs.first}/#{libname}.1.0.0.dylib",
                                  "#{dirs.last}/#{libname}.1.0.0.dylib")
        $stdout.print "Removing ","#{lib}/#{libname}.a","\n"
        rm_f "#{lib}/#{libname}.a","\n"
        $stdout.print "macho\n"
        MachO::Tools.merge_machos("#{lib}/#{libname}.a",
                                  "#{dirs.first}/#{libname}.a",
                                  "#{dirs.last}/#{libname}.a")
      end

      Dir.glob("#{dirs.first}/engines/*.dylib") do |engine|
        libname = File.basename(engine)
        rm_f "#{lib}/engines/#{libname}"
        MachO::Tools.merge_machos("#{lib}/engines/#{libname}",
                                  "#{dirs.first}/engines/#{libname}",
                                  "#{dirs.last}/engines/#{libname}")
      end

      MachO::Tools.merge_machos("#{bin}/openssl",
                                "#{dirs.first}/openssl",
                                "#{dirs.last}/openssl")

      confs = archs.map do |arch|
        <<~EOS
          #ifdef __#{arch}__
          #{(buildpath/"build-#{arch}/opensslconf.h").read}
          #endif
        EOS
      end
      (include/"openssl/opensslconf.h").atomic_write confs.join("\n")
    end
  end

  def openssldir
    etc/"openssl"
  end

  def post_install
    keychains = %w[
      /System/Library/Keychains/SystemRootCertificates.keychain
    ]

    certs_list = `security find-certificate -a -p #{keychains.join(" ")}`
    certs = certs_list.scan(
      /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m,
    )

    valid_certs = certs.select do |cert|
      IO.popen("#{bin}/openssl x509 -inform pem -checkend 0 -noout", "w") do |openssl_io|
        openssl_io.write(cert)
        openssl_io.close_write
      end

      $CHILD_STATUS.success?
    end

    openssldir.mkpath
    (openssldir/"cert.pem").atomic_write(valid_certs.join("\n"))
  end

  def caveats; <<~EOS
    A CA file has been bootstrapped using certificates from the SystemRoots
    keychain. To add additional certificates (e.g. the certificates added in
    the System keychain), place .pem files in
      #{openssldir}/certs

    and run
      #{opt_bin}/c_rehash
  EOS
  end

  test do
    # Make sure the necessary .cnf file exists, otherwise OpenSSL gets moody.
    assert_predicate HOMEBREW_PREFIX/"etc/openssl/openssl.cnf", :exist?,
            "OpenSSL requires the .cnf file for some functionality"

    # Check OpenSSL itself functions as expected.
    (testpath/"testfile.txt").write("This is a test file")
    expected_checksum = "e2d0fe1585a63ec6009c8016ff8dda8b17719a637405a4e23c0ff81339148249"
    system "#{bin}/openssl", "dgst", "-sha256", "-out", "checksum.txt", "testfile.txt"
    open("checksum.txt") do |f|
      checksum = f.read(100).split("=").last.strip
      assert_equal checksum, expected_checksum
    end
  end
end
