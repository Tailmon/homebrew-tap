# Extraced from pre- https://github.com/Homebrew/homebrew-core/pull/46876
class OpensslAT10 < Formula
  desc "SSL/TLS cryptography library"
  homepage "https://openssl.org/"
  url "https://www.openssl.org/source/openssl-1.0.2u.tar.gz"
  mirror "https://www.mirrorservice.org/sites/ftp.openssl.org/source/openssl-1.0.2u.tar.gz"
  sha256 "ecd0c6ffb493dd06707d38b14bb4d8c2288bb7033735606569d8f90f89669d16"

  keg_only :provided_by_macos,
    "Apple has deprecated use of OpenSSL in favor of its own TLS and crypto libraries"

  # Add darwin64-arm64-cc & debug-darwin64-arm64-cc build targets.
  patch :DATA

  def install
    # OpenSSL will prefer the PERL environment variable if set over $PATH
    # which can cause some odd edge cases & isn't intended. Unset for safety,
    # along with perl modules in PERL5LIB.
    ENV.delete("PERL")
    ENV.delete("PERL5LIB")

    ENV.deparallelize
    args = %W[
      --prefix=#{prefix}
      --openssldir=#{openssldir}
      no-ssl2
      no-ssl3
      no-zlib
      shared
      enable-cms
      darwin64-#{Hardware::CPU.arch}-cc
      enable-ec_nistp_64_gcc_128
    ]
    system "perl", "./Configure", *args
    system "make", "depend"
    system "make"
    system "make", "test"
    system "make", "install", "MANDIR=#{man}", "MANSUFFIX=ssl"
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
    (openssldir/"cert.pem").atomic_write(valid_certs.join("\n") << "\n")
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

__END__
diff --git a/Configure b/Configure
index 494e0b3..0d1577f 100755
--- a/Configure
+++ b/Configure
@@ -650,7 +650,9 @@ my %table=(
 "darwin-i386-cc","cc:-arch i386 -O3 -fomit-frame-pointer -DL_ENDIAN::-D_REENTRANT:MACOSX:-Wl,-search_paths_first%:BN_LLONG RC4_INT RC4_CHUNK DES_UNROLL BF_PTR:".eval{my $asm=$x86_asm;$asm=~s/cast\-586\.o//;$asm}.":macosx:dlfcn:darwin-shared:-fPIC -fno-common:-arch i386 -dynamiclib:.\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",
 "debug-darwin-i386-cc","cc:-arch i386 -g3 -DL_ENDIAN::-D_REENTRANT:MACOSX:-Wl,-search_paths_first%:BN_LLONG RC4_INT RC4_CHUNK DES_UNROLL BF_PTR:${x86_asm}:macosx:dlfcn:darwin-shared:-fPIC -fno-common:-arch i386 -dynamiclib:.\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",
 "darwin64-x86_64-cc","cc:-arch x86_64 -O3 -DL_ENDIAN -Wall::-D_REENTRANT:MACOSX:-Wl,-search_paths_first%:SIXTY_FOUR_BIT_LONG RC4_CHUNK DES_INT DES_UNROLL:".eval{my $asm=$x86_64_asm;$asm=~s/rc4\-[^:]+//;$asm}.":macosx:dlfcn:darwin-shared:-fPIC -fno-common:-arch x86_64 -dynamiclib:.\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",
+"darwin64-arm64-cc","cc:-arch arm64 -O3 -DL_ENDIAN -Wall::-D_REENTRANT:MACOSX:-Wl,-search_paths_first%:SIXTY_FOUR_BIT_LONG RC4_CHUNK DES_INT DES_UNROLL:${no_asm}:dlfcn:darwin-shared:-fPIC -fno-common:-arch arm64 -dynamiclib:.\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",
 "debug-darwin64-x86_64-cc","cc:-arch x86_64 -ggdb -g2 -O0 -DL_ENDIAN -Wall::-D_REENTRANT:MACOSX:-Wl,-search_paths_first%:SIXTY_FOUR_BIT_LONG RC4_CHUNK DES_INT DES_UNROLL:".eval{my $asm=$x86_64_asm;$asm=~s/rc4\-[^:]+//;$asm}.":macosx:dlfcn:darwin-shared:-fPIC -fno-common:-arch x86_64 -dynamiclib:.\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",
+"debug-darwin64-arm64-cc","cc:-arch arm64 -ggdb -g2 -O0 -DL_ENDIAN -Wall::-D_REENTRANT:MACOSX:-Wl,-search_paths_first%:SIXTY_FOUR_BIT_LONG RC4_CHUNK DES_INT DES_UNROLL:${no_asm}:dlfcn:darwin-shared:-fPIC -fno-common:-arch arm64 -dynamiclib:.\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",
 "debug-darwin-ppc-cc","cc:-DBN_DEBUG -DREF_CHECK -DCONF_DEBUG -DCRYPTO_MDEBUG -DB_ENDIAN -g -Wall -O::-D_REENTRANT:MACOSX::BN_LLONG RC4_CHAR RC4_CHUNK DES_UNROLL BF_PTR:${ppc32_asm}:osx32:dlfcn:darwin-shared:-fPIC:-dynamiclib:.\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",
 # iPhoneOS/iOS
 "iphoneos-cross","llvm-gcc:-O3 -isysroot \$(CROSS_TOP)/SDKs/\$(CROSS_SDK) -fomit-frame-pointer -fno-common::-D_REENTRANT:iOS:-Wl,-search_paths_first%:BN_LLONG RC4_CHAR RC4_CHUNK DES_UNROLL BF_PTR:${no_asm}:dlfcn:darwin-shared:-fPIC -fno-common:-dynamiclib:.\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",
diff --git a/crypto/bn/bn_nist.c b/crypto/bn/bn_nist.c
index 4a45404..75cfc2c 100644
--- a/crypto/bn/bn_nist.c
+++ b/crypto/bn/bn_nist.c
@@ -298,17 +298,28 @@ const BIGNUM *BN_get0_nist_prime_521(void)
     return &_bignum_nist_p_521;
 }
 
-static void nist_cp_bn_0(BN_ULONG *dst, const BN_ULONG *src, int top, int max)
-{
-    int i;
-
-#ifdef BN_DEBUG
-    OPENSSL_assert(top <= max);
-#endif
-    for (i = 0; i < top; i++)
-        dst[i] = src[i];
-    for (; i < max; i++)
-        dst[i] = 0;
+/*
+ * To avoid more recent compilers (specifically clang-14) from treating this
+ * code as a violation of the strict aliasing conditions and omiting it, this
+ * cannot be declared as a function.  Moreover, the dst parameter cannot be
+ * cached in a local since this no longer references the union and again falls
+ * foul of the strict aliasing criteria.  Refer to #18225 for the initial
+ * diagnostics and llvm/llvm-project#55255 for the later discussions with the
+ * LLVM developers.  The problem boils down to if an array in the union is
+ * converted to a pointer or if it is used directly.
+ *
+ * This function was inlined regardless, so there is no space cost to be
+ * paid for making it a macro.
+ */
+#define nist_cp_bn_0(dst, src_in, top, max) \
+{                                           \
+    int ii;                                 \
+    const BN_ULONG *src = src_in;           \
+                                            \
+    for (ii = 0; ii < top; ii++)            \
+        (dst)[ii] = src[ii];                \
+    for (; ii < max; ii++)                  \
+        (dst)[ii] = 0;                      \
 }
 
 static void nist_cp_bn(BN_ULONG *dst, const BN_ULONG *src, int top)
diff --git a/test/smime-certs/smdh.pem b/test/smime-certs/smdh.pem
index f831b07..a053263 100644
--- a/test/smime-certs/smdh.pem
+++ b/test/smime-certs/smdh.pem
@@ -31,3 +31,27 @@ LeXQfR7HXfh+tAum+WzjfLJwbnWbHmPhTbKB01U4lBp6+r8BGHAtNdPjEHqap4/z
 vVZVXti9ThZ20EhM+VFU3y2wyapeQjhQvw/A2YRES0Ik7BSj3hHfWH/CTbLVQnhu
 Uj6tw18ExOYxqoEGixNLPA5qsQ==
 -----END CERTIFICATE-----
+-----BEGIN CERTIFICATE-----
+MIIECjCCAvKgAwIBAgIUVyrSfF24yAGN3aPLZ8GxZOnkiJwwDQYJKoZIhvcNAQEL
+BQAwRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAxHTAbBgNV
+BAMMFFRlc3QgUy9NSU1FIFJTQSBSb290MB4XDTIzMDgwNTA2NDEwNFoXDTMzMDYx
+MzA2NDEwNFowRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAx
+HTAbBgNVBAMMFFRlc3QgUy9NSU1FIEVFIERIICMxMIIBtjCCASsGByqGSM4+AgEw
+ggEeAoGBANQMSgwEcnEZ31kZxa9Ef8qOK/AJ9dMlsXMWVYnf/QevGdN/0Aei/j9a
+8QHG+CvvTm0DOEKhN9QUtABKsYZag865CA7BmSdHjQuFqILtzA25sDJ+3+jk9vbs
+s+56ETRll/wasJVLGbmmHNkBMvc1fC1d/sGFcEn4zJnQvvFaeMgDAoGAaQD9ZvL8
+FYsJuNxN6qp5VfnfRqYvyi2PWSqtRKPGGC+VthYg49PRjwPOcXzvOsdEOQ7iH9jT
+iSvnUdwSSEwYTZkSBuQXAgOMJAWOpoXyaRvhatziBDoBnWS+/kX5RBhxvS0+em9y
+fRqAQleuGG+R1mEDihyJc8dWQQPT+O1l4oUCFQCJlKsQZ0VBrWPGcUCNa54ZW6TH
+9QOBhAACgYAvW95yAjZrAF4kfxQsGFJCl0vbbhVQPEU+JfO3xW7lUufE+/Sl8DkS
+f7xUHJO5Xu7pFLDf/vw25PKv+xPI3xiUHUC5cd1MnKcDUgK17XGAPiPaKOWr52/y
+Cg4AW33GS9fHssO6Yn9wKKCdcRNw0Z8yLz7SzRukxnKgdF1x7wNDbqNgMF4wDAYD
+VR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCBeAwHQYDVR0OBBYEFAtaTV99JcfyncGq
+t2OCL/qPMufAMB8GA1UdIwQYMBaAFP5/WNpYMyVHs2fGKq3sWxINORs0MA0GCSqG
+SIb3DQEBCwUAA4IBAQAK43Zcd7S7Z4hP3JDyiQ7bDKLdHYr5m2pZaVQBUYEpm6wI
+RNJEaSCDwJeYwIxGgPPIwScW10gR80eov4Lpoy9FyPyvOcETmUDIM0l5a2KmnefL
+hamXZUdvb+f57/m6MhcLFmJSyWLs8rKuFAcd00p/IzqWJ50N2btId6Uw8e/oHdsB
+MMzLcO7ikQ4ranlqFT9O7NllciA0PvYe0TfBHiFuDneJ9P8TrBhH7ChpiMDs1DcO
+9VxkjuuJGwfawBbjzvQHAztAA+XIY9PHxO1TWQ2W6gZM23sSVPm8YGs3Z4Y1BEpD
+lekl5pgCb0HKL/tULxLDsvZs7sUq0JDho8LEHTM6
+-----END CERTIFICATE-----
diff --git a/test/smime-certs/smdsa1.pem b/test/smime-certs/smdsa1.pem
index b424f67..c963816 100644
--- a/test/smime-certs/smdsa1.pem
+++ b/test/smime-certs/smdsa1.pem
@@ -1,47 +1,47 @@
 -----BEGIN PRIVATE KEY-----
-MIICZQIBADCCAjkGByqGSM44BAEwggIsAoIBAQCQfLlNdehPnTrGIMhw4rk0uua6
-k1nCG3zcyfXli17BdB2k0HBPaTA3a3ZHfOt1Awy0Uu0wZ3gdPr9z0I64hnJXIGou
-zIanZ7nYRImHtX5JMFbXeyxo1Owd2Zs3oEk9nQUoUsMxvmYC/ghPL5Zx1pPxcHCO
-wzWxoG4yZMjimXOc1/W7zvK/4/g/Cz9fItD3zdcydfgM/hK0/CeYQ21xfhqf4mjK
-v9plnCcWgToGI+7H8VK80MFbkO2QKRz3vP1/TjK6PRm9sEeB5b10+SvGv2j2w+CC
-0fXL4s6n7PtBlm/bww8xL1/Az8kwejUcII1Dc8uNwwISwGbwaGBvl7IHpm21AiEA
-rodZi+nCKZdTL8IgCjX3n0DuhPRkVQPjz/B6VweLW9MCggEAfimkUNwnsGFp7mKM
-zJKhHoQkMB1qJzyIHjDzQ/J1xjfoF6i27afw1/WKboND5eseZhlhA2TO5ZJB6nGx
-DOE9lVQxYVml++cQj6foHh1TVJAgGl4mWuveW/Rz+NEhpK4zVeEsfMrbkBypPByy
-xzF1Z49t568xdIo+e8jLI8FjEdXOIUg4ehB3NY6SL8r4oJ49j/sJWfHcDoWH/LK9
-ZaBF8NpflJe3F40S8RDvM8j2HC+y2Q4QyKk1DXGiH+7yQLGWzr3M73kC3UBnnH0h
-Hxb7ISDCT7dCw/lH1nCbVFBOM0ASI26SSsFSXQrvD2kryRcTZ0KkyyhhoPODWpU+
-TQMsxQQjAiEAkolGvb/76X3vm5Ov09ezqyBYt9cdj/FLH7DyMkxO7X0=
+MIICXQIBADCCAjYGByqGSM44BAEwggIpAoIBAQC0X3cgj3qQoE2lDQF034OnSbdG
+cDZuTsmQ3y7Su8jtbmO3IrYj0bEoVrv7cHpqMCZC6gibXRU7Fh/MzJIfolgkEMan
+tB3mHgyRV2yd9lT+tB5edgdTxpDyjKYglRyea0LkaSK168CA0AbzeniLOmovKbqr
+8RJNaxCbZKh23m7HvW/n9vTIz67j7L4yVDQeOoZyrrip8i9RxwrqJcbp0Wbty7xi
+Ai4uqzSsV+rUMM5+ObJ7O+Quc1mWnOz+/YEkSlPwHcvdP8KB55cMWKngIibGXnrG
+JEWKxLXCM0wm8sXpjQgpQ6t9RzDzFC68dGpNwAjKL0Mn7WwCw8FoO2fKcMM7Ah0A
+ntWBETTddebAVlCPRGNzezl3zMxCF50nG+C2SQKCAQEAgo+Rhu7rfh9pLy84IHB4
+QiFuudFs1Vy7xsWqHwuueNGJaVNqAlfu5IPg6Ckj76RkupxM+cg4bzOPDiQ9A1os
+Sk/bICYSXzUfKz0kFbJpeN6LBRYqSpIwjPQjJ2OrneiUbtAQlmAtQZZPr6XbUNGj
+SHF22vDmfLrbZPQCPviGVfnknZpqEbTUfZvZTvehH5cMOTrJO408z5e/RujaAocg
+w6u6fz4lfm/sYcWxaT/6z05GDYTGkUd8mFAcFeXWRO6vriE+mCQOv3T6YkHYcKae
+aTEKUbktgaHaPtHFRKkndPhrTBxn+Ksq/XhOfCPx9jFOb625hujC0cwqDcep3MQT
+QAQeAhxrOgUjimeP5Uk5LY0vjGQjjVeeJwgMfbUZuiwf
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-MIIFkDCCBHigAwIBAgIJANk5lu6mSyBDMA0GCSqGSIb3DQEBBQUAMEQxCzAJBgNV
-BAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRUZXN0IFMv
-TUlNRSBSU0EgUm9vdDAeFw0xMzA3MTcxNzI4MzFaFw0yMzA1MjYxNzI4MzFaMEUx
-CzAJBgNVBAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR4wHAYDVQQDDBVU
-ZXN0IFMvTUlNRSBFRSBEU0EgIzEwggNGMIICOQYHKoZIzjgEATCCAiwCggEBAJB8
-uU116E+dOsYgyHDiuTS65rqTWcIbfNzJ9eWLXsF0HaTQcE9pMDdrdkd863UDDLRS
-7TBneB0+v3PQjriGclcgai7MhqdnudhEiYe1fkkwVtd7LGjU7B3ZmzegST2dBShS
-wzG+ZgL+CE8vlnHWk/FwcI7DNbGgbjJkyOKZc5zX9bvO8r/j+D8LP18i0PfN1zJ1
-+Az+ErT8J5hDbXF+Gp/iaMq/2mWcJxaBOgYj7sfxUrzQwVuQ7ZApHPe8/X9OMro9
-Gb2wR4HlvXT5K8a/aPbD4ILR9cvizqfs+0GWb9vDDzEvX8DPyTB6NRwgjUNzy43D
-AhLAZvBoYG+XsgembbUCIQCuh1mL6cIpl1MvwiAKNfefQO6E9GRVA+PP8HpXB4tb
-0wKCAQB+KaRQ3CewYWnuYozMkqEehCQwHWonPIgeMPND8nXGN+gXqLbtp/DX9Ypu
-g0Pl6x5mGWEDZM7lkkHqcbEM4T2VVDFhWaX75xCPp+geHVNUkCAaXiZa695b9HP4
-0SGkrjNV4Sx8ytuQHKk8HLLHMXVnj23nrzF0ij57yMsjwWMR1c4hSDh6EHc1jpIv
-yvignj2P+wlZ8dwOhYf8sr1loEXw2l+Ul7cXjRLxEO8zyPYcL7LZDhDIqTUNcaIf
-7vJAsZbOvczveQLdQGecfSEfFvshIMJPt0LD+UfWcJtUUE4zQBIjbpJKwVJdCu8P
-aSvJFxNnQqTLKGGg84NalT5NAyzFA4IBBQACggEAGXSQADbuRIZBjiQ6NikwZl+x
-EDEffIE0RWbvwf1tfWxw4ZvanO/djyz5FePO0AIJDBCLUjr9D32nkmIG1Hu3dWgV
-86knQsM6uFiMSzY9nkJGZOlH3w4NHLE78pk75xR1sg1MEZr4x/t+a/ea9Y4AXklE
-DCcaHtpMGeAx3ZAqSKec+zQOOA73JWP1/gYHGdYyTQpQtwRTsh0Gi5mOOdpoJ0vp
-O83xYbFCZ+ZZKX1RWOjJe2OQBRtw739q1nRga1VMLAT/LFSQsSE3IOp8hiWbjnit
-1SE6q3II2a/aHZH/x4OzszfmtQfmerty3eQSq3bgajfxCsccnRjSbLeNiazRSKNg
-MF4wDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCBeAwHQYDVR0OBBYEFNHQYTOO
-xaZ/N68OpxqjHKuatw6sMB8GA1UdIwQYMBaAFMmRUwpjexZbi71E8HaIqSTm5bZs
-MA0GCSqGSIb3DQEBBQUAA4IBAQAAiLociMMXcLkO/uKjAjCIQMrsghrOrxn4ZGBx
-d/mCTeqPxhcrX2UorwxVCKI2+Dmz5dTC2xKprtvkiIadJamJmxYYzeF1pgRriFN3
-MkmMMkTbe/ekSvSeMtHQ2nHDCAJIaA/k9akWfA0+26Ec25/JKMrl3LttllsJMK1z
-Xj7TcQpAIWORKWSNxY/ezM34+9ABHDZB2waubFqS+irlZsn38aZRuUI0K67fuuIt
-17vMUBqQpe2hfNAjpZ8dIpEdAGjQ6izV2uwP1lXbiaK9U4dvUqmwyCIPniX7Hpaf
-0VnX0mEViXMT6vWZTjLBUv0oKmO7xBkWHIaaX6oyF32pK5AO
+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
 -----END CERTIFICATE-----
diff --git a/test/smime-certs/smdsa2.pem b/test/smime-certs/smdsa2.pem
index 648447f..903a4f3 100644
--- a/test/smime-certs/smdsa2.pem
+++ b/test/smime-certs/smdsa2.pem
@@ -1,47 +1,47 @@
 -----BEGIN PRIVATE KEY-----
-MIICZAIBADCCAjkGByqGSM44BAEwggIsAoIBAQCQfLlNdehPnTrGIMhw4rk0uua6
-k1nCG3zcyfXli17BdB2k0HBPaTA3a3ZHfOt1Awy0Uu0wZ3gdPr9z0I64hnJXIGou
-zIanZ7nYRImHtX5JMFbXeyxo1Owd2Zs3oEk9nQUoUsMxvmYC/ghPL5Zx1pPxcHCO
-wzWxoG4yZMjimXOc1/W7zvK/4/g/Cz9fItD3zdcydfgM/hK0/CeYQ21xfhqf4mjK
-v9plnCcWgToGI+7H8VK80MFbkO2QKRz3vP1/TjK6PRm9sEeB5b10+SvGv2j2w+CC
-0fXL4s6n7PtBlm/bww8xL1/Az8kwejUcII1Dc8uNwwISwGbwaGBvl7IHpm21AiEA
-rodZi+nCKZdTL8IgCjX3n0DuhPRkVQPjz/B6VweLW9MCggEAfimkUNwnsGFp7mKM
-zJKhHoQkMB1qJzyIHjDzQ/J1xjfoF6i27afw1/WKboND5eseZhlhA2TO5ZJB6nGx
-DOE9lVQxYVml++cQj6foHh1TVJAgGl4mWuveW/Rz+NEhpK4zVeEsfMrbkBypPByy
-xzF1Z49t568xdIo+e8jLI8FjEdXOIUg4ehB3NY6SL8r4oJ49j/sJWfHcDoWH/LK9
-ZaBF8NpflJe3F40S8RDvM8j2HC+y2Q4QyKk1DXGiH+7yQLGWzr3M73kC3UBnnH0h
-Hxb7ISDCT7dCw/lH1nCbVFBOM0ASI26SSsFSXQrvD2kryRcTZ0KkyyhhoPODWpU+
-TQMsxQQiAiAdCUJ5n2Q9hIynN8BMpnRcdfH696BKejGx+2Mr2kfnnA==
+MIICXQIBADCCAjYGByqGSM44BAEwggIpAoIBAQC0X3cgj3qQoE2lDQF034OnSbdG
+cDZuTsmQ3y7Su8jtbmO3IrYj0bEoVrv7cHpqMCZC6gibXRU7Fh/MzJIfolgkEMan
+tB3mHgyRV2yd9lT+tB5edgdTxpDyjKYglRyea0LkaSK168CA0AbzeniLOmovKbqr
+8RJNaxCbZKh23m7HvW/n9vTIz67j7L4yVDQeOoZyrrip8i9RxwrqJcbp0Wbty7xi
+Ai4uqzSsV+rUMM5+ObJ7O+Quc1mWnOz+/YEkSlPwHcvdP8KB55cMWKngIibGXnrG
+JEWKxLXCM0wm8sXpjQgpQ6t9RzDzFC68dGpNwAjKL0Mn7WwCw8FoO2fKcMM7Ah0A
+ntWBETTddebAVlCPRGNzezl3zMxCF50nG+C2SQKCAQEAgo+Rhu7rfh9pLy84IHB4
+QiFuudFs1Vy7xsWqHwuueNGJaVNqAlfu5IPg6Ckj76RkupxM+cg4bzOPDiQ9A1os
+Sk/bICYSXzUfKz0kFbJpeN6LBRYqSpIwjPQjJ2OrneiUbtAQlmAtQZZPr6XbUNGj
+SHF22vDmfLrbZPQCPviGVfnknZpqEbTUfZvZTvehH5cMOTrJO408z5e/RujaAocg
+w6u6fz4lfm/sYcWxaT/6z05GDYTGkUd8mFAcFeXWRO6vriE+mCQOv3T6YkHYcKae
+aTEKUbktgaHaPtHFRKkndPhrTBxn+Ksq/XhOfCPx9jFOb625hujC0cwqDcep3MQT
+QAQeAhwwXsdECYihdDNVnPrOIEr9iVbUCYXNu8fphBap
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-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
+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
 -----END CERTIFICATE-----
diff --git a/test/smime-certs/smdsa3.pem b/test/smime-certs/smdsa3.pem
index 77acc5e..89eacfb 100644
--- a/test/smime-certs/smdsa3.pem
+++ b/test/smime-certs/smdsa3.pem
@@ -1,47 +1,47 @@
 -----BEGIN PRIVATE KEY-----
-MIICZQIBADCCAjkGByqGSM44BAEwggIsAoIBAQCQfLlNdehPnTrGIMhw4rk0uua6
-k1nCG3zcyfXli17BdB2k0HBPaTA3a3ZHfOt1Awy0Uu0wZ3gdPr9z0I64hnJXIGou
-zIanZ7nYRImHtX5JMFbXeyxo1Owd2Zs3oEk9nQUoUsMxvmYC/ghPL5Zx1pPxcHCO
-wzWxoG4yZMjimXOc1/W7zvK/4/g/Cz9fItD3zdcydfgM/hK0/CeYQ21xfhqf4mjK
-v9plnCcWgToGI+7H8VK80MFbkO2QKRz3vP1/TjK6PRm9sEeB5b10+SvGv2j2w+CC
-0fXL4s6n7PtBlm/bww8xL1/Az8kwejUcII1Dc8uNwwISwGbwaGBvl7IHpm21AiEA
-rodZi+nCKZdTL8IgCjX3n0DuhPRkVQPjz/B6VweLW9MCggEAfimkUNwnsGFp7mKM
-zJKhHoQkMB1qJzyIHjDzQ/J1xjfoF6i27afw1/WKboND5eseZhlhA2TO5ZJB6nGx
-DOE9lVQxYVml++cQj6foHh1TVJAgGl4mWuveW/Rz+NEhpK4zVeEsfMrbkBypPByy
-xzF1Z49t568xdIo+e8jLI8FjEdXOIUg4ehB3NY6SL8r4oJ49j/sJWfHcDoWH/LK9
-ZaBF8NpflJe3F40S8RDvM8j2HC+y2Q4QyKk1DXGiH+7yQLGWzr3M73kC3UBnnH0h
-Hxb7ISDCT7dCw/lH1nCbVFBOM0ASI26SSsFSXQrvD2kryRcTZ0KkyyhhoPODWpU+
-TQMsxQQjAiEArJr6p2zTbhRppQurHGTdmdYHqrDdZH4MCsD9tQCw1xY=
+MIICXQIBADCCAjYGByqGSM44BAEwggIpAoIBAQC0X3cgj3qQoE2lDQF034OnSbdG
+cDZuTsmQ3y7Su8jtbmO3IrYj0bEoVrv7cHpqMCZC6gibXRU7Fh/MzJIfolgkEMan
+tB3mHgyRV2yd9lT+tB5edgdTxpDyjKYglRyea0LkaSK168CA0AbzeniLOmovKbqr
+8RJNaxCbZKh23m7HvW/n9vTIz67j7L4yVDQeOoZyrrip8i9RxwrqJcbp0Wbty7xi
+Ai4uqzSsV+rUMM5+ObJ7O+Quc1mWnOz+/YEkSlPwHcvdP8KB55cMWKngIibGXnrG
+JEWKxLXCM0wm8sXpjQgpQ6t9RzDzFC68dGpNwAjKL0Mn7WwCw8FoO2fKcMM7Ah0A
+ntWBETTddebAVlCPRGNzezl3zMxCF50nG+C2SQKCAQEAgo+Rhu7rfh9pLy84IHB4
+QiFuudFs1Vy7xsWqHwuueNGJaVNqAlfu5IPg6Ckj76RkupxM+cg4bzOPDiQ9A1os
+Sk/bICYSXzUfKz0kFbJpeN6LBRYqSpIwjPQjJ2OrneiUbtAQlmAtQZZPr6XbUNGj
+SHF22vDmfLrbZPQCPviGVfnknZpqEbTUfZvZTvehH5cMOTrJO408z5e/RujaAocg
+w6u6fz4lfm/sYcWxaT/6z05GDYTGkUd8mFAcFeXWRO6vriE+mCQOv3T6YkHYcKae
+aTEKUbktgaHaPtHFRKkndPhrTBxn+Ksq/XhOfCPx9jFOb625hujC0cwqDcep3MQT
+QAQeAhwkd6QfxIEYr90teX5xrAnKCtIQDguc4YmYq9/b
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-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
+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
 -----END CERTIFICATE-----
diff --git a/test/smime-certs/smec1.pem b/test/smime-certs/smec1.pem
index 75a8626..1a391de 100644
--- a/test/smime-certs/smec1.pem
+++ b/test/smime-certs/smec1.pem
@@ -1,22 +1,22 @@
 -----BEGIN PRIVATE KEY-----
-MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgXzBRX9Z5Ib4LAVAS
-DMlYvkj0SmLmYvWULe2LfyXRmpWhRANCAAS+SIj2FY2DouPRuNDp9WVpsqef58tV
-3gIwV0EOV/xyYTzZhufZi/aBcXugWR1x758x4nHus2uEuEFi3Mr3K3+x
+MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgv9621Gupvf+Ydjp3
+6m3JDAF8BjpLelbrbQTpi2na/LihRANCAASOmwyYYrRq1ttPxeAAYV48NjSJuPJE
+ti1mt8uu2T7QL4sJeSiR4S1scQtQE0VZ3JNycbplIttLPmoz94FDRVZ5
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-MIICoDCCAYigAwIBAgIJANk5lu6mSyBGMA0GCSqGSIb3DQEBBQUAMEQxCzAJBgNV
-BAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRUZXN0IFMv
-TUlNRSBSU0EgUm9vdDAeFw0xMzA3MTcxNzI4MzFaFw0yMzA1MjYxNzI4MzFaMEQx
-CzAJBgNVBAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRU
-ZXN0IFMvTUlNRSBFRSBFQyAjMTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABL5I
-iPYVjYOi49G40On1ZWmyp5/ny1XeAjBXQQ5X/HJhPNmG59mL9oFxe6BZHXHvnzHi
-ce6za4S4QWLcyvcrf7GjYDBeMAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgXg
-MB0GA1UdDgQWBBR/ybxC2DI+Jydhx1FMgPbMTmLzRzAfBgNVHSMEGDAWgBTJkVMK
-Y3sWW4u9RPB2iKkk5uW2bDANBgkqhkiG9w0BAQUFAAOCAQEAdk9si83JjtgHHHGy
-WcgWDfM0jzlWBsgFNQ9DwAuB7gJd/LG+5Ocajg5XdA5FXAdKkfwI6be3PdcVs3Bt
-7f/fdKfBxfr9/SvFHnK7PVAX2x1wwS4HglX1lfoyq1boSvsiJOnAX3jsqXJ9TJiV
-FlgRVnhnrw6zz3Xs/9ZDMTENUrqDHPNsDkKEi+9SqIsqDXpMCrGHP4ic+S8Rov1y
-S+0XioMxVyXDp6XcL4PQ/NgHbw5/+UcS0me0atZ6pW68C0vi6xeU5vxojyuZxMI1
-DXXwMhOXWaKff7KNhXDUN0g58iWlnyaCz4XQwFsbbFs88TQ1+e/aj3bbwTxUeyN7
-qtcHJA==
+MIICqzCCAZOgAwIBAgIUVyrSfF24yAGN3aPLZ8GxZOnkiJowDQYJKoZIhvcNAQEL
+BQAwRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAxHTAbBgNV
+BAMMFFRlc3QgUy9NSU1FIFJTQSBSb290MB4XDTIzMDgwNTA2NDEwNFoXDTMzMDYx
+MzA2NDEwNFowRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAx
+HTAbBgNVBAMMFFRlc3QgUy9NSU1FIEVFIEVDICMxMFkwEwYHKoZIzj0CAQYIKoZI
+zj0DAQcDQgAEjpsMmGK0atbbT8XgAGFePDY0ibjyRLYtZrfLrtk+0C+LCXkokeEt
+bHELUBNFWdyTcnG6ZSLbSz5qM/eBQ0VWeaNgMF4wDAYDVR0TAQH/BAIwADAOBgNV
+HQ8BAf8EBAMCBeAwHQYDVR0OBBYEFAOjahJ6eQQhjKZG97mpmPGE/GMLMB8GA1Ud
+IwQYMBaAFP5/WNpYMyVHs2fGKq3sWxINORs0MA0GCSqGSIb3DQEBCwUAA4IBAQB6
+g9HHdF+NeGvPW+cxmf04T95G+zAiP3zSygcoBY7KjSScU2M+KWA/Mx+flZ8BV8ka
+r5t/34kNoLz3Mg5k5KQFs4MLR8Kw+lsf2EkPCzMX03j7K5kxWEyspEskHJBelSXF
+GjuNcUiJ7llhPJbOTfrHLuHycW2aCmSX7zwYIm6ijG4a3VA6Vc6vNzVcs9FcRFPU
+w11aR6qSpX4CQTtBma8tIBRIqefNO/W4XlwACV3MXMVzLtEUuRGHn+Xnu6p3VW5e
+EWnsJousL4ZZgvs871hhuO8SgXR1UFlENGWnh+BiQjdbI67c0E2MpaRQfClyJy4r
+qyaM3IZHWvN0atGiqUdb
 -----END CERTIFICATE-----
diff --git a/test/smime-certs/smec2.pem b/test/smime-certs/smec2.pem
index 457297a..6546804 100644
--- a/test/smime-certs/smec2.pem
+++ b/test/smime-certs/smec2.pem
@@ -1,23 +1,23 @@
 -----BEGIN PRIVATE KEY-----
-MIGPAgEAMBAGByqGSM49AgEGBSuBBAAQBHgwdgIBAQQjhHaq507MOBznelrLG/pl
-brnnJi/iEJUUp+Pm3PEiteXqckmhTANKAAQF2zs6vobmoT+M+P2+9LZ7asvFBNi7
-uCzLYF/8j1Scn/spczoC9vNzVhNw+Lg7dnjNL4EDIyYZLl7E0v69luzbvy+q44/8
-6bQ=
+MIGQAgEAMBAGByqGSM49AgEGBSuBBAAQBHkwdwIBAQQkAEIQGZuPbpmJPHUGGBPY
+o5svUMNW2uabgJD4BzamVm7ZPyYPoUwDSgAEBGf/Ko8JM9Ljva+PIItkp04VlHyZ
+nwDciKs8ZWvHHWgs1ms7BkGQamet2261+icMKT9kLzcNC2DhqT3dstkjdv6eRocV
+GTU4
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-MIICpTCCAY2gAwIBAgIJANk5lu6mSyBHMA0GCSqGSIb3DQEBBQUAMEQxCzAJBgNV
-BAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRUZXN0IFMv
-TUlNRSBSU0EgUm9vdDAeFw0xMzA3MTcxNzI4MzFaFw0yMzA1MjYxNzI4MzFaMEQx
-CzAJBgNVBAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRU
-ZXN0IFMvTUlNRSBFRSBFQyAjMjBeMBAGByqGSM49AgEGBSuBBAAQA0oABAXbOzq+
-huahP4z4/b70tntqy8UE2Lu4LMtgX/yPVJyf+ylzOgL283NWE3D4uDt2eM0vgQMj
-JhkuXsTS/r2W7Nu/L6rjj/zptKNgMF4wDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8E
-BAMCBeAwHQYDVR0OBBYEFGf+QSQlkN20PsNN7x+jmQIJBDcXMB8GA1UdIwQYMBaA
-FMmRUwpjexZbi71E8HaIqSTm5bZsMA0GCSqGSIb3DQEBBQUAA4IBAQBaBBryl2Ez
-ftBrGENXMKQP3bBEw4n9ely6HvYQi9IC7HyK0ktz7B2FcJ4z96q38JN3cLxV0DhK
-xT/72pFmQwZVJngvRaol0k1B+bdmM03llxCw/uNNZejixDjHUI9gEfbigehd7QY0
-uYDu4k4O35/z/XPQ6O5Kzw+J2vdzU8GXlMBbWeZWAmEfLGbk3Ux0ouITnSz0ty5P
-rkHTo0uprlFcZAsrsNY5v5iuomYT7ZXAR3sqGZL1zPOKBnyfXeNFUfnKsZW7Fnlq
-IlYBQIjqR1HGxxgCSy66f1oplhxSch4PUpk5tqrs6LeOqc2+xROy1T5YrB3yjVs0
-4ZdCllHZkhop
+MIICsDCCAZigAwIBAgIUVyrSfF24yAGN3aPLZ8GxZOnkiJswDQYJKoZIhvcNAQEL
+BQAwRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAxHTAbBgNV
+BAMMFFRlc3QgUy9NSU1FIFJTQSBSb290MB4XDTIzMDgwNTA2NDEwNFoXDTMzMDYx
+MzA2NDEwNFowRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAx
+HTAbBgNVBAMMFFRlc3QgUy9NSU1FIEVFIEVDICMyMF4wEAYHKoZIzj0CAQYFK4EE
+ABADSgAEBGf/Ko8JM9Ljva+PIItkp04VlHyZnwDciKs8ZWvHHWgs1ms7BkGQamet
+2261+icMKT9kLzcNC2DhqT3dstkjdv6eRocVGTU4o2AwXjAMBgNVHRMBAf8EAjAA
+MA4GA1UdDwEB/wQEAwIF4DAdBgNVHQ4EFgQUMMwlODm2hfyZ6lzOUv+7y67gCuQw
+HwYDVR0jBBgwFoAU/n9Y2lgzJUezZ8YqrexbEg05GzQwDQYJKoZIhvcNAQELBQAD
+ggEBABdR8eFvsZ4ronqhvcUpCd78CGRTSUq/S/cRzPzkrmQrzKSZIDeyQ4JNRT15
+WwqHqcUQD6hbueIihG6v7IAnRF1ZefJGR2jLDz6u9gFYv3WQBK6LR4jYgMg/hk1u
+SW1iPSBc7AM4/XN/LuX4nVl6a79nLmdQf1YtSWi1fiNUxL8595ozrsR5FmP/eOog
+GMrMWH51QAekv7e20w9fqfUJZ7p5lmM7e5begRNmpoFqW3WXlQ2MFsTa2lKY6JlB
+N0PHCKK9/mc/XPGayDvcLRlS/xeB5aibqpkJT1dimgQRWJtBa2R2rq6Olha1JVwj
+nuDQmMoyEzFHQWd8035z407ag8Y=
 -----END CERTIFICATE-----
diff --git a/test/smime-certs/smroot.pem b/test/smime-certs/smroot.pem
index d1a253f..e48476d 100644
--- a/test/smime-certs/smroot.pem
+++ b/test/smime-certs/smroot.pem
@@ -1,49 +1,49 @@
 -----BEGIN PRIVATE KEY-----
-MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCyyQXED5HyVWwq
-nXyzmY317yMUJrIfsKvREG2C691dJNHgNg+oq5sjt/fzkyS84AvdOiicAsao4cYL
-DulthaLpbC7msEBhvwAil0FNb5g3ERupe1KuTdUV1UuD/i6S2VoaNXUBBn1rD9Wc
-BBc0lnx/4Wt92eQTI6925pt7ZHPQw2Olp7TQDElyi5qPxCem4uT0g3zbZsWqmmsI
-MXbu+K3dEprzqA1ucKXbxUmZNkMwVs2XCmlLxrRUj8C3/zENtH17HWCznhR/IVcV
-kgIuklkeiDsEhbWvUQumVXR7oPh/CPZAbjGqq5mVueHSHrp7brBVZKHZvoUka28Q
-LWitq1W5AgMBAAECggEASkRnOMKfBeOmQy2Yl6K57eeg0sYgSDnDpd0FINWJ5x9c
-b58FcjOXBodtYKlHIY6QXx3BsM0WaSEge4d+QBi7S+u8r+eXVwNYswXSArDQsk9R
-Bl5MQkvisGciL3pvLmFLpIeASyS/BLJXMbAhU58PqK+jT2wr6idwxBuXivJ3ichu
-ISdT1s2aMmnD86ulCD2DruZ4g0mmk5ffV+Cdj+WWkyvEaJW2GRYov2qdaqwSOxV4
-Yve9qStvEIWAf2cISQjbnw2Ww6Z5ebrqlOz9etkmwIly6DTbrIneBnoqJlFFWGlF
-ghuzc5RE2w1GbcKSOt0qXH44MTf/j0r86dlu7UIxgQKBgQDq0pEaiZuXHi9OQAOp
-PsDEIznCU1bcTDJewANHag5DPEnMKLltTNyLaBRulMypI+CrDbou0nDr29VOzfXx
-mNvi/c7RttOBOx7kXKvu0JUFKe2oIWRsg0KsyMX7UFMVaHFgrW+8DhQc7HK7URiw
-nitOnA7YwIHRF9BMmcWcLFEYBQKBgQDC6LPbXV8COKO0YCfGXPnE7EZGD/p0Q92Z
-8CoSefphEScSdO1IpxFXG7fOZ4x2GQb9q7D3IvaeKAqNjUjkuyxdB30lIWDBwSWw
-fFgsa2SZwD5P60G/ar50YJr6LiF333aUMDVmC9swFfZERAEmGUz2NTrPWQdIx/lu
-PyDtUR75JQKBgHaoCCJ8vl5SJl1IA5GV4Bo8IoeLTSzsY9d09zMy6BoZcMD1Ix2T
-5S2cXhayoegl9PT6bsYSGHVWFCdJ86ktMI826TcXRzDaCvYhzc9THroJQcnfdbtP
-aHWezkv7fsAmkoPjn75K7ubeo+r7Q5qbkg6a1PW58N8TRXIvkackzaVxAoGBALAq
-qh3U+AHG9dgbrPeyo6KkuCOtX39ks8/mbfCDRZYkbb9V5f5r2tVz3R93IlK/7jyr
-yWimtmde46Lrl33922w+T5OW5qBZllo9GWkUrDn3s5qClcuQjJIdmxYTSfbSCJiK
-NkmE39lHkG5FVRB9f71tgTlWS6ox7TYDYxx83NTtAoGAUJPAkGt4yGAN4Pdebv53
-bSEpAAULBHntiqDEOu3lVColHuZIucml/gbTpQDruE4ww4wE7dOhY8Q4wEBVYbRI
-vHkSiWpJUvZCuKG8Foh5pm9hU0qb+rbQV7NhLJ02qn1AMGO3F/WKrHPPY8/b9YhQ
-KfvPCYimQwBjVrEnSntLPR0=
+MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCSGt9um3Vou2Mf
+yJA5NLhzNlzzWhwgK7xyXAwaIh0ZpqpvaXcy8yeJ/6kch/Rn9dYiGXOaUOznrUnl
+h2vo88fTBYfQO5ag/Q9N9TtVY1CHrQwtT3NhZWJxOsHF96teshV0muvQCLBDxrSQ
+P3VkCRg4rFJoBh1jz/7GMl4RAZ9/6KZjKnmJqrOG2tL1xe/Qgc9cO/q9FC6eGO6U
+sFCvAhwdQUz1wocODD+pngIso7mgcP1mXiFKvrUZAwU77orPsACbKqKu6vNhBJd6
+d0spCbH2cBkk0Lx4/RUJk2hCiX4VAmXX42A12LtgZgsGO9UUamwk7T1akoOg71NB
+8rm168ONAgMBAAECggEAEXfUCdndVjm9NrIYiDZk7SVtRI0b+r6v565YphE5EHWM
+QAjIfxdyPT4LXoVks79BLE+FskgFowdlY+Nmg/INjI3HOJ6/Oh03ZLcysllO6gHH
+CG3M2jKwa+A+BajAXPCGvyu8kOFRDbFmqi5kHyM1OaVkrto4TlQyXkjsVTUv+C9O
+0QCfrbbUc8iGire3W7I4TezZSeVeK00vbWdA3S+Flf5hCbGhiRigfllJwVypPu5Q
+YZMIOj/DFBh8x7cPHMteUHe3QzKpe+FwIk7EE1ZtTOmKjJa3c7o9AuzEbGSsuNBG
+ZZN0IlmBTVPBjGlyUd91TjzH82zf0C4pnC4zs1meIwKBgQDMNwaURCgSbwt69zvS
+IU7rHxL8zYn47Qe7hPRIfY3TFMUVO7hywZ+cPbkc+6GspMcvuF46gWZt0G4L6HMG
+baDB0iD0nx4OlQZMM3HCzT0JSqXn/db6oPFFsNyo1V8j07kM+tjYWhg0QTnHwJzA
+GqUmDHh1FxzPryarGvClkDC0TwKBgQC3J4kTBHGu+Y56w/eD2hxU5yWFkJL64HqO
+/z7j5ZPi6rjrvvvPgCemHiBBrjFbIYtX1gqwjvXs81r4HFJGS4hwE3rEEapFonyB
+OhY7VNcb/dFMpC6BJ9MRSg0rbye8LD73ifpZ7aKk/UH1/2S9JLVn41yVKHZVDCJp
+xUr5MQInYwKBgHlEL7b5piYUJOgXSkGkn92FLVxLnaPg9VeIQxuM2xw+WC4csZIL
+ooFAMd2hG0eO7e1LeUEauD17qO2PUka98NlHs2Qv3MRiAERdxC8eeyE6X7ycgv1/
+duageNgVJJL81gV8LCqFjZvyI6KXoT1+VRV8EEfPur8lTjwLGl3metWHAoGAOq4C
+/8HLvnicCn8gnPDTZOxNnDZOsOwcuBXVC2TxdaEoL/eXa8quaU17ni92BrF/mFuu
+PxT+e7UYLye7wGPQyb+j9I+IUxkU9L4sg0PSS1iNpxVvBNhCimaEQ6cwPtyaK+rb
+99Xn5x5w9KSnnOXW7PruHafCCcuCdwrL03y9KOsCgYAK/WAq1Sfk5eQAbsp9xXYM
+rldvphjoFURED6FtUfpDqbSsTxEh8BF2/mcYS1cQyURZau02v9WMhwxSHxxxRz+l
+zO7GJKdVe4Y/mbrvMD5KkfgK5myEzP8c4la+Gi/vFmTPZXiNU4B36tE+pH7W4pFu
+oW3MbA9wpvEjfXaQXcqc7g==
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-MIIDbjCCAlagAwIBAgIJAMc+8VKBJ/S9MA0GCSqGSIb3DQEBBQUAMEQxCzAJBgNV
-BAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRUZXN0IFMv
-TUlNRSBSU0EgUm9vdDAeFw0xMzA3MTcxNzI4MjlaFw0yMzA3MTUxNzI4MjlaMEQx
-CzAJBgNVBAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRU
-ZXN0IFMvTUlNRSBSU0EgUm9vdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
-ggEBALLJBcQPkfJVbCqdfLOZjfXvIxQmsh+wq9EQbYLr3V0k0eA2D6irmyO39/OT
-JLzgC906KJwCxqjhxgsO6W2FoulsLuawQGG/ACKXQU1vmDcRG6l7Uq5N1RXVS4P+
-LpLZWho1dQEGfWsP1ZwEFzSWfH/ha33Z5BMjr3bmm3tkc9DDY6WntNAMSXKLmo/E
-J6bi5PSDfNtmxaqaawgxdu74rd0SmvOoDW5wpdvFSZk2QzBWzZcKaUvGtFSPwLf/
-MQ20fXsdYLOeFH8hVxWSAi6SWR6IOwSFta9RC6ZVdHug+H8I9kBuMaqrmZW54dIe
-untusFVkodm+hSRrbxAtaK2rVbkCAwEAAaNjMGEwHQYDVR0OBBYEFMmRUwpjexZb
-i71E8HaIqSTm5bZsMB8GA1UdIwQYMBaAFMmRUwpjexZbi71E8HaIqSTm5bZsMA8G
-A1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMA0GCSqGSIb3DQEBBQUAA4IB
-AQAwpIVWQey2u/XoQSMSu0jd0EZvU+lhLaFrDy/AHQeG3yX1+SAOM6f6w+efPvyb
-Op1NPI9UkMPb4PCg9YC7jgYokBkvAcI7J4FcuDKMVhyCD3cljp0ouuKruvEf4FBl
-zyQ9pLqA97TuG8g1hLTl8G90NzTRcmKpmhs18BmCxiqHcTfoIpb3QvPkDX8R7LVt
-9BUGgPY+8ELCgw868TuHh/Cnc67gBtRjBp0sCYVzGZmKsO5f1XdHrAZKYN5mEp0C
-7/OqcDoFqORTquLeycg1At/9GqhDEgxNrqA+YEsPbLGAfsNuXUsXs2ubpGsOZxKt
-Emsny2ah6fU2z7PztrUy/A80
+MIIDeTCCAmGgAwIBAgIUaPL1z1id8L6GFbvoQ1GdUrJM1kkwDQYJKoZIhvcNAQEL
+BQAwRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAxHTAbBgNV
+BAMMFFRlc3QgUy9NSU1FIFJTQSBSb290MB4XDTIzMDgwNTA2NDEwM1oXDTMzMDgw
+MjA2NDEwM1owRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAx
+HTAbBgNVBAMMFFRlc3QgUy9NSU1FIFJTQSBSb290MIIBIjANBgkqhkiG9w0BAQEF
+AAOCAQ8AMIIBCgKCAQEAkhrfbpt1aLtjH8iQOTS4czZc81ocICu8clwMGiIdGaaq
+b2l3MvMnif+pHIf0Z/XWIhlzmlDs561J5Ydr6PPH0wWH0DuWoP0PTfU7VWNQh60M
+LU9zYWVicTrBxferXrIVdJrr0AiwQ8a0kD91ZAkYOKxSaAYdY8/+xjJeEQGff+im
+Yyp5iaqzhtrS9cXv0IHPXDv6vRQunhjulLBQrwIcHUFM9cKHDgw/qZ4CLKO5oHD9
+Zl4hSr61GQMFO+6Kz7AAmyqirurzYQSXendLKQmx9nAZJNC8eP0VCZNoQol+FQJl
+1+NgNdi7YGYLBjvVFGpsJO09WpKDoO9TQfK5tevDjQIDAQABo2MwYTAdBgNVHQ4E
+FgQU/n9Y2lgzJUezZ8YqrexbEg05GzQwHwYDVR0jBBgwFoAU/n9Y2lgzJUezZ8Yq
+rexbEg05GzQwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwDQYJKoZI
+hvcNAQELBQADggEBAGR5cH47jQ7hTAhbdsgzsv1rIcljxVgERbwZCOxX6GzI716/
+dU7ZCNWe1mmw1WQIz53/Xseh9hB28pWsHMCHZvVtuFEdC51OxMtI7ltq+X3oupyK
+CUwaKuqrOLH6TJrsRQzf+sZpOh2240rvE6b4nLERaiiaBZQce4F30jqtXRmXB+90
+xT1WWwIhvBFGN08Q5U0EllANZ0NEiP5aAPuqozEku7Nw1+JDa0f/2AbBo97eHV88
+LZeIQFvyzU8LsLizSkkLYRFnKmYZLXFVVT+7R6SSjlUEWHdR3MqxaWMus0rGdfqg
+z6ag/azaObFCMmehjgNa5AGiIZQ1kY9KL0RbG+Y=
 -----END CERTIFICATE-----
diff --git a/test/smime-certs/smrsa1.pem b/test/smime-certs/smrsa1.pem
index d0d0b9e..da64450 100644
--- a/test/smime-certs/smrsa1.pem
+++ b/test/smime-certs/smrsa1.pem
@@ -1,49 +1,49 @@
 -----BEGIN PRIVATE KEY-----
-MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDXr9uzB/20QXKC
-xhkfNnJvl2xl1hzdOcrQmAqo+AAAcA/D49ImuJDVQRaK2bcj54XB26i1kXuOrxID
-3/etUb8yudfx8OAVwh8G0xVA4zhr8uXW85W2tBr4v0Lt+W6lSd6Hmfrk4GmE9LTU
-/vzl9HUPW6SZShN1G0nY6oeUXvLi0vasEUKv3a51T6JFYg4c7qt5RCk/w8kwrQ0D
-orQwCdkOPEIiC4b+nPStF12SVm5bx8rbYzioxuY/PdSebvt0APeqgRxSpCxqYnHs
-CoNeHzSrGXcP0COzFeUOz2tdrhmH09JLbGZs4nbojPxMkjpJSv3/ekDG2CHYxXSH
-XxpJstxZAgMBAAECggEASY4xsJaTEPwY3zxLqPdag2/yibBBW7ivz/9p80HQTlXp
-KnbxXj8nNXLjCytAZ8A3P2t316PrrTdLP4ML5lGwkM4MNPhek00GY79syhozTa0i
-cPHVJt+5Kwee/aVI9JmCiGAczh0yHyOM3+6ttIZvvXMVaSl4BUHvJ0ikQBc5YdzL
-s6VM2gCOR6K6n+39QHDI/T7WwO9FFSNnpWFOCHwAWtyBMlleVj+xeZX8OZ/aT+35
-27yjsGNBftWKku29VDineiQC+o+fZGJs6w4JZHoBSP8TfxP8fRCFVNA281G78Xak
-cEnKXwZ54bpoSa3ThKl+56J6NHkkfRGb8Rgt/ipJYQKBgQD5DKb82mLw85iReqsT
-8bkp408nPOBGz7KYnQsZqAVNGfehM02+dcN5z+w0jOj6GMPLPg5whlEo/O+rt9ze
-j6c2+8/+B4Bt5oqCKoOCIndH68jl65+oUxFkcHYxa3zYKGC9Uvb+x2BtBmYgvDRG
-ew6I2Q3Zyd2ThZhJygUZpsjsbQKBgQDdtNiGTkgWOm+WuqBI1LT5cQfoPfgI7/da
-ZA+37NBUQRe0cM7ddEcNqx7E3uUa1JJOoOYv65VyGI33Ul+evI8h5WE5bupcCEFk
-LolzbMc4YQUlsySY9eUXM8jQtfVtaWhuQaABt97l+9oADkrhA+YNdEu2yiz3T6W+
-msI5AnvkHQKBgDEjuPMdF/aY6dqSjJzjzfgg3KZOUaZHJuML4XvPdjRPUlfhKo7Q
-55/qUZ3Qy8tFBaTderXjGrJurc+A+LiFOaYUq2ZhDosguOWUA9yydjyfnkUXZ6or
-sbvSoM+BeOGhnezdKNT+e90nLRF6cQoTD7war6vwM6L+8hxlGvqDuRNFAoGAD4K8
-d0D4yB1Uez4ZQp8m/iCLRhM3zCBFtNw1QU/fD1Xye5w8zL96zRkAsRNLAgKHLdsR
-355iuTXAkOIBcJCOjveGQsdgvAmT0Zdz5FBi663V91o+IDlryqDD1t40CnCKbtRG
-hng/ruVczg4x7OYh7SUKuwIP/UlkNh6LogNreX0CgYBQF9troLex6X94VTi1V5hu
-iCwzDT6AJj63cS3VRO2ait3ZiLdpKdSNNW2WrlZs8FZr/mVutGEcWho8BugGMWST
-1iZkYwly9Xfjnpd0I00ZIlr2/B3+ZsK8w5cOW5Lpb7frol6+BkDnBjbNZI5kQndn
-zQpuMJliRlrq/5JkIbH6SA==
+MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCJIP62Zu/eP86i
+6UA0C50eweBqC4bK2eYiC7AR5wDsyFQyUFkhNIzViMjndwMLjtRighGkGJ+Ae0Y0
+JfNond7PvHlGtlq5rAZnF9XzkcARGMd27ITOuqhO0IacDca5zVKhE15oHmXUOiR5
+Ob4J7S6mjELWJCYUMO5vXL6ojfsXc35/tjAyFOGP+Kn4SNxL9cQNb7rzhL7/24Tp
+5ypzOILk0WgbTr89LJevXVboliGcQysg3o5kn2VMlciCgMNmaXh3uEr/Wpvbi6OM
+7DRaRb6OvKVdVxqvIgP+ItHwIJHZagQINjpNGpyxmQrM1yeysQIZ7TQ84iBh9nmp
+DaRZb8ZlAgMBAAECggEAFP+qOZzUPQSo3C4bQI0Ju6jFOH/43W3WLZ78EJW/AMNh
+j03aBDlzmoxmdXl2TCoMUGRqFqaVoDtgYgJwvnO0Z7vNF3y7smSLG3TdNL38OzH/
+83BfGvge52jLwDBk3tV4AoYAhjGndsMLjEvBE+yP4P2oC3pAIYXnsUJyyMVrLqkt
+0P4HUvy/cJCm1nNYBP3/T8kZD0PfOBaaP/0LZ4D3YNEVLF5hU9z5dGMDErxU6/0Z
+DHY89bgynzMzeXSudsM11PVuMrXug1edpp+dWnW0y3XBF9n0p8UXI//siw6tX7MF
++d6WncfhdKlyPMzqVt1Mdn7mtQGBz8r+LGdoOLl/oQKBgQC+fzuplSc732PXPgyN
+xfT/bq76O/Vx7iedc7c8hDQvtc32mOp9qbGFAFd/JuqCrMFpkzvAsmKwhIda6mjV
+zvLvGDwYZeyIAtSWyqQX/4/yoNMHZx8etsaCv90eaKBQV8oEcOcQdZGVtyRJtnRP
+kVWbmG7g+Cew9l1Dk9Lyi5EahQKBgQC4R/VPjucre1rZuh9eJTjfkB6cKpmP943s
++CDBIfEwoZFwPDJHhrS1WbqFzz5WTCXg90EUzZkB6PK291iDFmJP5bfysjijIqFA
+s5TzQ53lDSCyEQBuqixNl40rY6fPHYFr76G/ogsad0rTo4kCHFQKBcQ2113WJ98H
+m8ego8fyYQKBgQC+cpVDRUqkIQG//tiuJGp7tDxbD/aioGYak8VtSv6hdDEliFtm
+pnBDd8QB6vYpDm2PDxN94tmnf9eSnSeSGgPl5WSvP7bpg2rmFlFXbLiM6RwRGpeS
+LUjpDsgRzqf3qszdA8L+QYv7Ec3FpBNEORhNJmgzoeSMlsFG/lK3CbFXwQKBgQCx
+z5z/+x9LcWckFtcVfEz4SpN+lAxAQdmMAY95S0ryZbNz3GGXan8LTV0Qp/u6QRd7
+jpgZfphYo3Eu4lNhiUOrXDi10QmdP1jgmWbrox7DWHtn1cfZABJnfAgXCb1tt0ad
+40brJWwZSWnF9FHK25KraQz+7af5b9df/AwPEHlpgQKBgEBDHZ/J/F8SVj0Z4TSQ
+P2BsKWk9vOoZswj0N/F7Or84CjMxhVE+wOYzhWnEhCJXP9b7R8K1PxU0oC/wh9bu
+wK/LHrSuUVXISEQvdRowjKlqlu5ctBtEnmaTWxXyo3VWYEUrCiVMa5TNTeUPSMj2
+F8EyVIr5BuoDEeVp2sUKrxRA
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-MIIDbDCCAlSgAwIBAgIJANk5lu6mSyBAMA0GCSqGSIb3DQEBBQUAMEQxCzAJBgNV
-BAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRUZXN0IFMv
-TUlNRSBSU0EgUm9vdDAeFw0xMzA3MTcxNzI4MzBaFw0yMzA1MjYxNzI4MzBaMEUx
-CzAJBgNVBAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR4wHAYDVQQDDBVU
-ZXN0IFMvTUlNRSBFRSBSU0EgIzEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
-AoIBAQDXr9uzB/20QXKCxhkfNnJvl2xl1hzdOcrQmAqo+AAAcA/D49ImuJDVQRaK
-2bcj54XB26i1kXuOrxID3/etUb8yudfx8OAVwh8G0xVA4zhr8uXW85W2tBr4v0Lt
-+W6lSd6Hmfrk4GmE9LTU/vzl9HUPW6SZShN1G0nY6oeUXvLi0vasEUKv3a51T6JF
-Yg4c7qt5RCk/w8kwrQ0DorQwCdkOPEIiC4b+nPStF12SVm5bx8rbYzioxuY/PdSe
-bvt0APeqgRxSpCxqYnHsCoNeHzSrGXcP0COzFeUOz2tdrhmH09JLbGZs4nbojPxM
-kjpJSv3/ekDG2CHYxXSHXxpJstxZAgMBAAGjYDBeMAwGA1UdEwEB/wQCMAAwDgYD
-VR0PAQH/BAQDAgXgMB0GA1UdDgQWBBTmjc+lrTQuYx/VBOBGjMvufajvhDAfBgNV
-HSMEGDAWgBTJkVMKY3sWW4u9RPB2iKkk5uW2bDANBgkqhkiG9w0BAQUFAAOCAQEA
-dr2IRXcFtlF16kKWs1VTaFIHHNQrfSVHBkhKblPX3f/0s/i3eXgwKUu7Hnb6T3/o
-E8L+e4ioQNhahTLt9ruJNHWA/QDwOfkqM3tshCs2xOD1Cpy7Bd3Dn0YBrHKyNXRK
-WelGp+HetSXJGW4IZJP7iES7Um0DGktLabhZbe25EnthRDBjNnaAmcofHECWESZp
-lEHczGZfS9tRbzOCofxvgLbF64H7wYSyjAe6R8aain0VRbIusiD4tCHX/lOMh9xT
-GNBW8zTL+tV9H1unjPMORLnT0YQ3oAyEND0jCu0ACA1qGl+rzxhF6bQcTUNEbRMu
-9Hjq6s316fk4Ne0EUF3PbA==
+MIIDdzCCAl+gAwIBAgIUVyrSfF24yAGN3aPLZ8GxZOnkiJQwDQYJKoZIhvcNAQEL
+BQAwRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAxHTAbBgNV
+BAMMFFRlc3QgUy9NSU1FIFJTQSBSb290MB4XDTIzMDgwNTA2NDEwM1oXDTMzMDYx
+MzA2NDEwM1owRTELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAx
+HjAcBgNVBAMMFVRlc3QgUy9NSU1FIEVFIFJTQSAjMTCCASIwDQYJKoZIhvcNAQEB
+BQADggEPADCCAQoCggEBAIkg/rZm794/zqLpQDQLnR7B4GoLhsrZ5iILsBHnAOzI
+VDJQWSE0jNWIyOd3AwuO1GKCEaQYn4B7RjQl82id3s+8eUa2WrmsBmcX1fORwBEY
+x3bshM66qE7QhpwNxrnNUqETXmgeZdQ6JHk5vgntLqaMQtYkJhQw7m9cvqiN+xdz
+fn+2MDIU4Y/4qfhI3Ev1xA1vuvOEvv/bhOnnKnM4guTRaBtOvz0sl69dVuiWIZxD
+KyDejmSfZUyVyIKAw2ZpeHe4Sv9am9uLo4zsNFpFvo68pV1XGq8iA/4i0fAgkdlq
+BAg2Ok0anLGZCszXJ7KxAhntNDziIGH2eakNpFlvxmUCAwEAAaNgMF4wDAYDVR0T
+AQH/BAIwADAOBgNVHQ8BAf8EBAMCBeAwHQYDVR0OBBYEFGuuWcjzfRW+t+17+maO
+4/VGgRzqMB8GA1UdIwQYMBaAFP5/WNpYMyVHs2fGKq3sWxINORs0MA0GCSqGSIb3
+DQEBCwUAA4IBAQBFkoLcKDVvpyx0wue9h0VdrIpbgQRSmmzZTjsDtQDFH51w79Zb
+cKJgB7ERoRjwZtTlB9BkonaJVvOz4A44erJZEShzuS+yNFReJK07e4f+hLwI4jJx
+JVZTMVgB2nmbzwlgU6vCFYemIoKAiNz0zcQ8+7iRPijo3uIIKPwC6k9iy+gKcFuA
+LjDnh8XoYf5HnAxiZXA7Q10XuQEsjjSt8a4/sNk7IgTo2kkb7cCzMmVHc3KH0Fvq
+WtheSJMMxw2mGRn0JVEtp5c80ZpaNGTg4xhww/Jc2Bjo8Q+376ERA4CeH6jBABxE
+RfVVDXdKzGTAHUw9h3nlx63GhblltlKO85NP
 -----END CERTIFICATE-----
diff --git a/test/smime-certs/smrsa2.pem b/test/smime-certs/smrsa2.pem
index 2f17cb2..6c5a53f 100644
--- a/test/smime-certs/smrsa2.pem
+++ b/test/smime-certs/smrsa2.pem
@@ -1,49 +1,49 @@
 -----BEGIN PRIVATE KEY-----
-MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDcYC4tS2Uvn1Z2
-iDgtfkJA5tAqgbN6X4yK02RtVH5xekV9+6+eTt/9S+iFAzAnwqR/UB1R67ETrsWq
-V8u9xLg5fHIwIkmu9/6P31UU9cghO7J1lcrhHvooHaFpcXepPWQacpuBq2VvcKRD
-lDfVmdM5z6eS3dSZPTOMMP/xk4nhZB8mcw27qiccPieS0PZ9EZB63T1gmwaK1Rd5
-U94Pl0+zpDqhViuXmBfiIDWjjz0BzHnHSz5Rg4S3oXF1NcojhptIWyI0r7dgn5J3
-NxC4kgKdjzysxo6iWd0nLgz7h0jUdj79EOis4fg9G4f0EFWyQf7iDxGaA93Y9ePB
-Jv5iFZVZAgMBAAECggEBAILIPX856EHb0KclbhlpfY4grFcdg9LS04grrcTISQW1
-J3p9nBpZ+snKe6I8Yx6lf5PiipPsSLlCliHiWpIzJZVQCkAQiSPiHttpEYgP2IYI
-dH8dtznkdVbLRthZs0bnnPmpHCpW+iqpcYJ9eqkz0cvUNUGOjjWmwWmoRqwp/8CW
-3S1qbkQiCh0Mk2fQeGar76R06kXQ9MKDEj14zyS3rJX+cokjEoMSlH8Sbmdh2mJz
-XlNZcvqmeGJZwQWgbVVHOMUuZaKJiFa+lqvOdppbqSx0AsCRq6vjmjEYQEoOefYK
-3IJM9IvqW5UNx0Cy4kQdjhZFFwMO/ALD3QyF21iP4gECgYEA+isQiaWdaY4UYxwK
-Dg+pnSCKD7UGZUaCUIv9ds3CbntMOONFe0FxPsgcc4jRYQYj1rpQiFB8F11+qXGa
-P/IHcnjr2+mTrNY4I9Bt1Lg+pHSS8QCgzeueFybYMLaSsXUo7tGwpvw6UUb6/YWI
-LNCzZbrCLg1KZjGODhhxtvN45ZkCgYEA4YNSe+GMZlxgsvxbLs86WOm6DzJUPvxN
-bWmni0+Oe0cbevgGEUjDVc895uMFnpvlgO49/C0AYJ+VVbStjIMgAeMnWj6OZoSX
-q49rI8KmKUxKgORZiiaMqGWQ7Rxv68+4S8WANsjFxoUrE6dNV3uYDIUsiSLbZeI8
-38KVTcLohcECgYEAiOdyWHGq0G4xl/9rPUCzCMsa4velNV09yYiiwBZgVgfhsawm
-hQpOSBZJA60XMGqkyEkT81VgY4UF4QLLcD0qeCnWoXWVHFvrQyY4RNZDacpl87/t
-QGO2E2NtolL3umesa+2TJ/8Whw46Iu2llSjtVDm9NGiPk5eA7xPPf1iEi9kCgYAb
-0EmVE91wJoaarLtGS7LDkpgrFacEWbPnAbfzW62UENIX2Y1OBm5pH/Vfi7J+vHWS
-8E9e0eIRCL2vY2hgQy/oa67H151SkZnvQ/IP6Ar8Xvd1bDSK8HQ6tMQqKm63Y9g0
-KDjHCP4znOsSMnk8h/bZ3HcAtvbeWwftBR/LBnYNQQKBgA1leIXLLHRoX0VtS/7e
-y7Xmn7gepj+gDbSuCs5wGtgw0RB/1z/S3QoS2TCbZzKPBo20+ivoRP7gcuFhduFR
-hT8V87esr/QzLVpjLedQDW8Xb7GiO3BsU/gVC9VcngenbL7JObl3NgvdreIYo6+n
-yrLyf+8hjm6H6zkjqiOkHAl+
+MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDFxuuhnb1Vwxdg
+1dHpXpKP+HuzA/qmHBKHPmc7+evXjP6xJeA50R3n5/PxXm3I8GIGzTP/A4zrDtKB
+zmPjXY76slEDDPnVRBCMaVHlM1W0oCTk0W9IcOHnF8sMVIoJ/lPXOfMR3N/K2kpZ
+22EJbnZ8HqGVaGpbKZNYlsz+XUcwEcYtewopBkstVgagnNkadenWt/mYWH/hgqRR
+vjqFTNrFTx2Ecz/6OSgNjC1NW6cX7l2E2LYsKrTRdFSex0TE9RwZrsy91tjD4pOc
+jQnSZFU4Gcwrmja+7JpYpaok9WymRjl2G21q2EraPzs+83EvefbxnMwZOLj0Yhmk
+NvlxktJTAgMBAAECggEAYI5GgH8trd6SncyV8CyjOhWScqnZJ1qiMxPku5O+r9ve
+hibbKu7sfkkwP+EdkRHGkdKB9ZjKpgF1BTl5a8nD4aHHykj9+cACokJS4Kaoy4e5
+q1qSTVgK+dMUZt8pC0r2rKdWg5yFR5g931OqsruSrfMYaQRylDIehQwOZYqtlAnl
+DLA8m4erxhIbJ2AyhcvoYuBGom5U5BClhhAN3X2iZ6pQ0/Y6AcH+9N5Ok2Gnxoqw
+eWEOFcZBgIj/dWAkNBYs0db/0HhcKRuEpWr8j+RRYVGnAOUftIKf+uEPrWepF4sB
+wUHoxku1NM7KL0heXJrareV3H91fEqoLYzTHfe5PEQKBgQDzGrDLbBNVI0kmk+BO
+q5eEK1DPGpp3ADmjCI3YEpAhdzmv11sUMKTanziHm4hhvb1RpwI/VQkGosLkywjQ
+8do0n4CpTYbslwi97lvgm2VuweBtoXbPMzml1mkBQ+V8734TXfjAKXS93WU54ZHq
+f62yhtY/Vl2ytz53NTRsiRESAwKBgQDQRLHa8y2v2fj1ZqFcm0/BcK942To6xZjT
+2Y6CqAdY4IbK2+md4zkPVt2G7svGzxabRCPQvQVrEAhlqKEMNEiiqNMBH0R0te3D
+ckZIvHm2GhdEE1QdUXTKWtK1VUq5hEkzWJVM9ti2ELr8Kt6TFaytMZ5O2pMuyco/
+4LVn7u/1cQKBgGvSW7VtcsmhA9G7ZpId4u6483dXukirbeTUZ2z9FrXxFkHaR0gW
+Jxfb5IuovP101SIA66tBQOaTi9NEBd3+VqReVgdBHmWSu0raDB/7bCqKjMqzAWn2
+s0vNY/cusPsPkaBvXmOEP4XySvI4DKqwBE8ZJK8k1Bvu0CK5E05MIKkXAoGABCm7
+XGMMAL3cqhsZEp7QI0+7UjEVZuNYQLPSk24EZ5RlXVyz+MH3/ASCfRX84MZ27zeX
+d66vkwpJAK80OOg6o3W4cgdL+QFB9WwtV3rc+/TdjjDMt6FPMlRKbfF8guTQCcS1
+h0pP3qPK+QtqU4pVX0jknzLjSkYiUtCND7zI8yECgYEAphEdUaS7S4ny1Cwuum4E
+L29cR9t2ehQE25kaPXGiPEyjjpHlQjqZxFROCPlHTloMO39UAaNI0ajy0eRcsDVO
+22i4z0EzP7K6ZZzymJTgu0m1TfpEoUr4sCz1Y+y6Bxcxm3RC9w38N5Q4j3lWZ+ht
+ahwiYQIX1sdm+nW+ZlCKtJE=
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-MIIDbDCCAlSgAwIBAgIJANk5lu6mSyBBMA0GCSqGSIb3DQEBBQUAMEQxCzAJBgNV
-BAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRUZXN0IFMv
-TUlNRSBSU0EgUm9vdDAeFw0xMzA3MTcxNzI4MzBaFw0yMzA1MjYxNzI4MzBaMEUx
-CzAJBgNVBAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR4wHAYDVQQDDBVU
-ZXN0IFMvTUlNRSBFRSBSU0EgIzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
-AoIBAQDcYC4tS2Uvn1Z2iDgtfkJA5tAqgbN6X4yK02RtVH5xekV9+6+eTt/9S+iF
-AzAnwqR/UB1R67ETrsWqV8u9xLg5fHIwIkmu9/6P31UU9cghO7J1lcrhHvooHaFp
-cXepPWQacpuBq2VvcKRDlDfVmdM5z6eS3dSZPTOMMP/xk4nhZB8mcw27qiccPieS
-0PZ9EZB63T1gmwaK1Rd5U94Pl0+zpDqhViuXmBfiIDWjjz0BzHnHSz5Rg4S3oXF1
-NcojhptIWyI0r7dgn5J3NxC4kgKdjzysxo6iWd0nLgz7h0jUdj79EOis4fg9G4f0
-EFWyQf7iDxGaA93Y9ePBJv5iFZVZAgMBAAGjYDBeMAwGA1UdEwEB/wQCMAAwDgYD
-VR0PAQH/BAQDAgXgMB0GA1UdDgQWBBT0arpyYMHXDPVL7MvzE+lx71L7sjAfBgNV
-HSMEGDAWgBTJkVMKY3sWW4u9RPB2iKkk5uW2bDANBgkqhkiG9w0BAQUFAAOCAQEA
-I8nM42am3aImkZyrw8iGkaGhKyi/dfajSWx6B9izBUh+3FleBnUxxOA+mn7M8C47
-Ne18iaaWK8vEux9KYTIY8BzXQZL1AuZ896cXEc6bGKsME37JSsocfuB5BIGWlYLv
-/ON5/SJ0iVFj4fAp8z7Vn5qxRJj9BhZDxaO1Raa6cz6pm0imJy9v8y01TI6HsK8c
-XJQLs7/U4Qb91K+IDNX/lgW3hzWjifNpIpT5JyY3DUgbkD595LFV5DDMZd0UOqcv
-6cyN42zkX8a0TWr3i5wu7pw4k1oD19RbUyljyleEp0DBauIct4GARdBGgi5y1H2i
-NzYzLAPBkHCMY0Is3KKIBw==
+MIIDdzCCAl+gAwIBAgIUVyrSfF24yAGN3aPLZ8GxZOnkiJUwDQYJKoZIhvcNAQEL
+BQAwRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAxHTAbBgNV
+BAMMFFRlc3QgUy9NSU1FIFJTQSBSb290MB4XDTIzMDgwNTA2NDEwM1oXDTMzMDYx
+MzA2NDEwM1owRTELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAx
+HjAcBgNVBAMMFVRlc3QgUy9NSU1FIEVFIFJTQSAjMjCCASIwDQYJKoZIhvcNAQEB
+BQADggEPADCCAQoCggEBAMXG66GdvVXDF2DV0eleko/4e7MD+qYcEoc+Zzv569eM
+/rEl4DnRHefn8/FebcjwYgbNM/8DjOsO0oHOY+NdjvqyUQMM+dVEEIxpUeUzVbSg
+JOTRb0hw4ecXywxUign+U9c58xHc38raSlnbYQludnweoZVoalspk1iWzP5dRzAR
+xi17CikGSy1WBqCc2Rp16da3+ZhYf+GCpFG+OoVM2sVPHYRzP/o5KA2MLU1bpxfu
+XYTYtiwqtNF0VJ7HRMT1HBmuzL3W2MPik5yNCdJkVTgZzCuaNr7smlilqiT1bKZG
+OXYbbWrYSto/Oz7zcS959vGczBk4uPRiGaQ2+XGS0lMCAwEAAaNgMF4wDAYDVR0T
+AQH/BAIwADAOBgNVHQ8BAf8EBAMCBeAwHQYDVR0OBBYEFKENak8LioRBxmq8iDXu
+MQzoUSP9MB8GA1UdIwQYMBaAFP5/WNpYMyVHs2fGKq3sWxINORs0MA0GCSqGSIb3
+DQEBCwUAA4IBAQA3tHkuyzZM8ojIf6YmtneOluWkFhg9qX2psdreRijlwrbes1B6
+IqDuZTQuCOIb2B4kP9AqC8cmtK/5ZtJAM25iqr74Vvk1IfhNcJ/QKtsbR+Y6VAP/
+76fNwcUYTt3qqeBXPcLGgWOf3naP+5pR+nOT5x2SAypTA289JznlP5NixJpc3R+j
+yK58KxE5JEkTXdfSlWvdQM8/SCcDIWmV/5pWrfP/qTaFeIdE9OfVn62H9Dpb+phG
+FJC3S6Vwq/UCUB1JjCKSkB0h1eMFoPnFOjKx1gcBP+A4ofsBYp9Hn2k313zMVxID
+B3aUOByyAQxN+BJvZ40USFSSLEZ7YJgiius/
 -----END CERTIFICATE-----
diff --git a/test/smime-certs/smrsa3.pem b/test/smime-certs/smrsa3.pem
index 14c27f6..bbdb17e 100644
--- a/test/smime-certs/smrsa3.pem
+++ b/test/smime-certs/smrsa3.pem
@@ -1,49 +1,49 @@
 -----BEGIN PRIVATE KEY-----
-MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCyK+BTAOJKJjji
-OhY60NeZjzGGZxEBfCm62n0mwkzusW/V/e63uwj6uOVCFoVBz5doMf3M6QIS2jL3
-Aw6Qs5+vcuLA0gHrqIwjYQz1UZ5ETLKLKbQw6YOIVfsFSTxytUVpfcByrubWiLKX
-63theG1/IVokDK/9/k52Kyt+wcCjuRb7AJQFj2OLDRuWm/gavozkK103gQ+dUq4H
-XamZMtTq1EhQOfc0IUeCOEL6xz4jzlHHfzLdkvb7Enhav2sXDfOmZp/DYf9IqS7l
-vFkkINPVbYFBTexaPZlFwmpGRjkmoyH/w+Jlcpzs+w6p1diWRpaSn62bbkRN49j6
-L2dVb+DfAgMBAAECggEAciwDl6zdVT6g/PbT/+SMA+7qgYHSN+1koEQaJpgjzGEP
-lUUfj8TewCtzXaIoyj9IepBuXryBg6snNXpT/w3bqgYon/7zFBvxkUpDj4A5tvKf
-BuY2fZFlpBvUu1Ju1eKrFCptBBBoA9mc+BUB/ze4ktrAdJFcxZoMlVScjqGB3GdR
-OHw2x9BdWGCJBhiu9VHhAAb/LVWi6xgDumYSWZwN2yovg+7J91t5bsENeBRHycK+
-i5dNFh1umIK9N0SH6bpHPnLHrCRchrQ6ZRRxL4ZBKA9jFRDeI7OOsJuCvhGyJ1se
-snsLjr/Ahg00aiHCcC1SPQ6pmXAVBCG7hf4AX82V4QKBgQDaFDE+Fcpv84mFo4s9
-wn4CZ8ymoNIaf5zPl/gpH7MGots4NT5+Ns+6zzJQ6TEpDjTPx+vDaabP7QGXwVZn
-8NAHYvCQK37b+u9HrOt256YYRDOmnJFSbsJdmqzMEzpTNmQ8GuI37cZCS9CmSMv+
-ab/plcwuv0cJRSC83NN2AFyu1QKBgQDRJzKIBQlpprF9rA0D5ZjLVW4OH18A0Mmm
-oanw7qVutBaM4taFN4M851WnNIROyYIlkk2fNgW57Y4M8LER4zLrjU5HY4lB0BMX
-LQWDbyz4Y7L4lVnnEKfQxWFt9avNZwiCxCxEKy/n/icmVCzc91j9uwKcupdzrN6E
-yzPd1s5y4wKBgQCkJvzmAdsOp9/Fg1RFWcgmIWHvrzBXl+U+ceLveZf1j9K5nYJ7
-2OBGer4iH1XM1I+2M4No5XcWHg3L4FEdDixY0wXHT6Y/CcThS+015Kqmq3fBmyrc
-RNjzQoF9X5/QkSmkAIx1kvpgXtcgw70htRIrToGSUpKzDKDW6NYXhbA+PQKBgDJK
-KH5IJ8E9kYPUMLT1Kc4KVpISvPcnPLVSPdhuqVx69MkfadFSTb4BKbkwiXegQCjk
-isFzbeEM25EE9q6EYKP+sAm+RyyJ6W0zKBY4TynSXyAiWSGUAaXTL+AOqCaVVZiL
-rtEdSUGQ/LzclIT0/HLV2oTw4KWxtTdc3LXEhpNdAoGBAM3LckiHENqtoeK2gVNw
-IPeEuruEqoN4n+XltbEEv6Ymhxrs6T6HSKsEsLhqsUiIvIzH43KMm45SNYTn5eZh
-yzYMXLmervN7c1jJe2Y2MYv6hE+Ypj1xGW4w7s8WNKmVzLv97beisD9AZrS7sXfF
-RvOAi5wVkYylDxV4238MAZIq
+MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDl8CSTTlMftgFz
++mVpn/AKmAB5xYqcPGt4FvVgGdYIWIMsgGxVJDaEcxDk9CndqAhIc++Of8s4tvb7
+VYsSjI2JyokbQI4KWm0XjozG4NRQN9UgoOMEDZonMoybtsw3xIQHolFl48mExDWb
+Pitk3WWx1555dlqqrVnLaM7t+eCf9+LOi6UlYaqoVHSZhHUbb0S8JOLw3sdh2LTe
+TN8Kd8o33uJioO5kGoV4FMV7icYbHOB5o7GMC1+Yrrg4hmDqYQoBCjNddpf28DYz
+3nBythzDygxPLrqvZgt9uJKOGVnWSBo7jDGmZzNqJHoYLnhtfWWgNG5oSA2cvVCy
+obToEFBzAgMBAAECggEAR/eBexloquQsUEBuvUBxwN8SRwqs93lxqYSGCC4N707E
+v4jyXzOWXJ4nC4HgGKAe945RzCfzUyzw4HlFreiP5DCf+QebbWIgAt968EQuL21K
+J4wzgXFAbkRD/fiYsluvdzQ2hc1lpUhD/vLWYhtpWOBDmYCRoBnhoOiM2675vxce
+0fo0UBuktIbPVvdTmRrkK2omhHEp1Q4L+PsHccNak+6Yb0+kJgAwRri299ef3U5e
+JquRfwffZE2obqVCBcPHOS2RaAEO486d9iNt/tm8o2+3z28R7xBw6nEXDewcIOki
+mCshPp3yTMZMnBfsw03bH91B6EZbnoR/Bo3D/fKpAQKBgQD6iYQ90zBTMsKf99tu
+NFBCQRQQjTgVZh/vse7DUX7w+bWvCjiMtCk0geGMnTl1Ti6Lf5QfDNPdhRvLqw5P
+K3N6O/+BQV65zHltk6t2UYjK2zD+DhVufr0REoJXmPWQuqFySb2UQuMj7pnxoEyh
+MDEWNbQ2cQuf7fOrJR6xwXVsLwKBgQDq86St4cTZ2nfSqZCIfrQCzSiPgugDxxsA
+/fPedVe+/iVzq8bKc/tsCHWMIaBLWO8v+L3MRjBWyrmBKqb81zeu9YGT4ybCJhob
+PLy1zs8fn1uccVZilBM2Y5lBwmEp/m5M3t15UsCN83JA8zuW/9yBKrIeVi8zUCJW
+vOC76mp6/QKBgExG6/UqxC7AaJLtkmgmEz1otOQpKqcRNa3zfV8IA974F8GYGgl0
+nIr49COshp7ZU8By8jTV4fcynHjQtoWSFBFmDO9caKumvl2HNQ/L2RrxyyO+Q/Yl
+Lgjxmq9yyWjr+VVjcA2go6j/7uyqwknc80TwytI8bq6dcq9rmMHDxa1PAoGBALFj
+/T0PjbnSGc/jGG4GA9Ftpqcb9iMMDBZmpt6aCAL7DbnUwwWOJhD+HgoMRWM+JXE5
+w8tcXxjYfNDKLEQQFkmxsQDAaz4A2IsiA3TdTUKZ5egrJkbNd+gDsO2WXhf/srW1
+OtBkK1/Bo8zoGGC8k3aujsca2Q5L/XExsBgROA3dAoGADNHBlAH43VCHRDGOmSvO
+/crV+fT0TR2A/iklbx/2DdrD5Kb7EohgQJVkA4EuPZWtoGMhpv+pSuT7luPln4FW
+TwpApp7ZqS8S/HiECfIHZO99hDnI7UBQfd4oOvF+OZykQo1Qa8DGLB0PQaF07zwT
+KBpWyAJfNZwFJCZaHxHv7oE=
 -----END PRIVATE KEY-----
 -----BEGIN CERTIFICATE-----
-MIIDbDCCAlSgAwIBAgIJANk5lu6mSyBCMA0GCSqGSIb3DQEBBQUAMEQxCzAJBgNV
-BAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR0wGwYDVQQDDBRUZXN0IFMv
-TUlNRSBSU0EgUm9vdDAeFw0xMzA3MTcxNzI4MzBaFw0yMzA1MjYxNzI4MzBaMEUx
-CzAJBgNVBAYTAlVLMRYwFAYDVQQKDA1PcGVuU1NMIEdyb3VwMR4wHAYDVQQDDBVU
-ZXN0IFMvTUlNRSBFRSBSU0EgIzMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
-AoIBAQCyK+BTAOJKJjjiOhY60NeZjzGGZxEBfCm62n0mwkzusW/V/e63uwj6uOVC
-FoVBz5doMf3M6QIS2jL3Aw6Qs5+vcuLA0gHrqIwjYQz1UZ5ETLKLKbQw6YOIVfsF
-STxytUVpfcByrubWiLKX63theG1/IVokDK/9/k52Kyt+wcCjuRb7AJQFj2OLDRuW
-m/gavozkK103gQ+dUq4HXamZMtTq1EhQOfc0IUeCOEL6xz4jzlHHfzLdkvb7Enha
-v2sXDfOmZp/DYf9IqS7lvFkkINPVbYFBTexaPZlFwmpGRjkmoyH/w+Jlcpzs+w6p
-1diWRpaSn62bbkRN49j6L2dVb+DfAgMBAAGjYDBeMAwGA1UdEwEB/wQCMAAwDgYD
-VR0PAQH/BAQDAgXgMB0GA1UdDgQWBBQ6CkW5sa6HrBsWvuPOvMjyL5AnsDAfBgNV
-HSMEGDAWgBTJkVMKY3sWW4u9RPB2iKkk5uW2bDANBgkqhkiG9w0BAQUFAAOCAQEA
-JhcrD7AKafVzlncA3cZ6epAruj1xwcfiE+EbuAaeWEGjoSltmevcjgoIxvijRVcp
-sCbNmHJZ/siQlqzWjjf3yoERvLDqngJZZpQeocMIbLRQf4wgLAuiBcvT52wTE+sa
-VexeETDy5J1OW3wE4A3rkdBp6hLaymlijFNnd5z/bP6w3AcIMWm45yPm0skM8RVr
-O3UstEFYD/iy+p+Y/YZDoxYQSW5Vl+NkpGmc5bzet8gQz4JeXtH3z5zUGoDM4XK7
-tXP3yUi2eecCbyjh/wgaQiVdylr1Kv3mxXcTl+cFO22asDkh0R/y72nTCu5fSILY
-CscFo2Z2pYROGtZDmYqhRw==
+MIIDdzCCAl+gAwIBAgIUVyrSfF24yAGN3aPLZ8GxZOnkiJYwDQYJKoZIhvcNAQEL
+BQAwRDELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAxHTAbBgNV
+BAMMFFRlc3QgUy9NSU1FIFJTQSBSb290MB4XDTIzMDgwNTA2NDEwM1oXDTMzMDYx
+MzA2NDEwM1owRTELMAkGA1UEBhMCVUsxFjAUBgNVBAoMDU9wZW5TU0wgR3JvdXAx
+HjAcBgNVBAMMFVRlc3QgUy9NSU1FIEVFIFJTQSAjMzCCASIwDQYJKoZIhvcNAQEB
+BQADggEPADCCAQoCggEBAOXwJJNOUx+2AXP6ZWmf8AqYAHnFipw8a3gW9WAZ1ghY
+gyyAbFUkNoRzEOT0Kd2oCEhz745/yzi29vtVixKMjYnKiRtAjgpabReOjMbg1FA3
+1SCg4wQNmicyjJu2zDfEhAeiUWXjyYTENZs+K2TdZbHXnnl2WqqtWctozu354J/3
+4s6LpSVhqqhUdJmEdRtvRLwk4vDex2HYtN5M3wp3yjfe4mKg7mQahXgUxXuJxhsc
+4HmjsYwLX5iuuDiGYOphCgEKM112l/bwNjPecHK2HMPKDE8uuq9mC324ko4ZWdZI
+GjuMMaZnM2okehgueG19ZaA0bmhIDZy9ULKhtOgQUHMCAwEAAaNgMF4wDAYDVR0T
+AQH/BAIwADAOBgNVHQ8BAf8EBAMCBeAwHQYDVR0OBBYEFOZ4epuLEXfkuQLVJsND
+gS4jGBKLMB8GA1UdIwQYMBaAFP5/WNpYMyVHs2fGKq3sWxINORs0MA0GCSqGSIb3
+DQEBCwUAA4IBAQBvXe3ZvMq8hvjU9R3rHT1ljVP1YP/fUqhmQ/qbYA1xPHY4HjG7
+O9ZOVVh6qPOwlnM6d9Qp2niKQ52qJBQUSTJIeSRVgOJpjnz831eselOTqw5tCsw0
+EeSbhI4KeSPzp2pR2D2U5kJGaOnxWcMC+PS5HCbSS8Q4qCozJr2ACjXvJtDjlRrx
+1c+FQDLxDORmy7Wk7f42gZhBeatPrx0ozo7eWAxVcZcCmVTM4bZe/a1Gib5luGXP
+O9qIVAN2NqK7DRWCcXXgzBxLydJo1Qp5dCLC9grQ2D3460qmOAt6MIvSt2DquFH+
+vsM5eol7xZqT5LfTaehwWMXYcV1CXmscDvsC
 -----END CERTIFICATE-----