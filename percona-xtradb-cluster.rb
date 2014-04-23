require 'formula'

class PerconaXtradbCluster < Formula
  homepage 'http://www.percona.com'
  url 'http://www.percona.com/redir/downloads/Percona-XtraDB-Cluster-56/LATEST/source/Percona-XtraDB-Cluster-5.6.15.tar.gz'
  version '5.6.15-25.5.759'
  sha1 'cd883c3aa1483c74c5949f6d40630c315ce1b7d4'

  # https://bugs.launchpad.net/codership-mysql/+bug/1309241
  patch :p0 do
    url 'https://launchpadlibrarian.net/173604067/bug.diff'
    sha1 '2bcda55fef129879764df1c93ab4a1eb99dcf006'
  end

  depends_on 'cmake' => :build
  depends_on 'pidof' unless MacOS.version >= :mountain_lion

  option :universal
  option 'with-tests', 'Build with unit tests'
  option 'with-embedded', 'Build the embedded server'
  option 'with-memcached', 'Build with InnoDB Memcached plugin'
  option 'enable-local-infile', 'Build with local infile loading support'

  conflicts_with 'mysql-connector-c',
    :because => 'both install `mysql_config`'

  conflicts_with 'mariadb', 'mysql', 'mysql-cluster', 'percona-server',
    :because => "mariadb, mysql, mysql-cluster, and percona-server install the same binaries."
  conflicts_with 'mysql-connector-c',
    :because => 'both install MySQL client libraries'

  env :std if build.universal?

  fails_with :llvm do
    build 2334
    cause "https://github.com/Homebrew/homebrew/issues/issue/144"
  end

  # Where the database files should be located. Existing installs have them
  # under var/percona, but going forward they will be under var/msyql to be
  # shared with the mysql and mariadb formulae.
  def datadir
    @datadir ||= (var/'percona').directory? ? var/'percona' : var/'mysql'
  end

  def install
    # Don't hard-code the libtool path. See:
    # https://github.com/Homebrew/homebrew/issues/20185
    inreplace "cmake/libutils.cmake",
      "COMMAND /usr/bin/libtool -static -o ${TARGET_LOCATION}",
      "COMMAND libtool -static -o ${TARGET_LOCATION}"

    # Build without compiler or CPU specific optimization flags to facilitate
    # compilation of gems and other software that queries `mysql-config`.
    ENV.minimal_optimization

    args = %W[
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_FIND_FRAMEWORK=LAST
      -DCMAKE_VERBOSE_MAKEFILE=ON
      -DMYSQL_DATADIR=#{datadir}
      -DINSTALL_INCLUDEDIR=include/mysql
      -DINSTALL_MANDIR=share/man
      -DINSTALL_DOCDIR=share/doc/#{name}
      -DINSTALL_INFODIR=share/info
      -DINSTALL_MYSQLSHAREDIR=share/mysql
      -DWITH_SSL=yes
      -DDEFAULT_CHARSET=utf8
      -DDEFAULT_COLLATION=utf8_general_ci
      -DSYSCONFDIR=#{etc}
      -DCOMPILATION_COMMENT=Homebrew
      -DWITH_EDITLINE=system
      -DCMAKE_BUILD_TYPE=RelWithDebInfo
    ]

    # PAM plugin is Linux-only at the moment
    args.concat %W[
      -DWITHOUT_AUTH_PAM=1
      -DWITHOUT_AUTH_PAM_COMPAT=1
      -DWITHOUT_DIALOG=1
    ]

    # To enable unit testing at build, we need to download the unit testing suite
    if build.with? 'tests'
      args << "-DENABLE_DOWNLOADS=ON"
    else
      args << "-DWITH_UNIT_TESTS=OFF"
    end

    # Build the embedded server
    args << "-DWITH_EMBEDDED_SERVER=ON" if build.with? 'embedded'

    # Build with InnoDB Memcached plugin
    args << "-DWITH_INNODB_MEMCACHED=ON" if build.with? 'memcached'

    # Make universal for binding to universal applications
    args << "-DCMAKE_OSX_ARCHITECTURES='#{Hardware::CPU.universal_archs.as_cmake_arch_flags}'" if build.universal?

    # Build with local infile loading support
    args << "-DENABLED_LOCAL_INFILE=1" if build.include? 'enable-local-infile'

    system "cmake", *args
    system "make"
    system "make install"

    # Don't create databases inside of the prefix!
    # See: https://github.com/Homebrew/homebrew/issues/4975
    rm_rf prefix+'data'

    # Link the setup script into bin
    bin.install_symlink prefix/"scripts/mysql_install_db"

    # Fix up the control script and link into bin
    inreplace "#{prefix}/support-files/mysql.server" do |s|
      s.gsub!(/^(PATH=".*)(")/, "\\1:#{HOMEBREW_PREFIX}/bin\\2")
      # pidof can be replaced with pgrep from proctools on Mountain Lion
      s.gsub!(/pidof/, 'pgrep') if MacOS.version >= :mountain_lion
    end

    bin.install_symlink prefix/"support-files/mysql.server"

    # Move mysqlaccess to libexec
    mv "#{bin}/mysqlaccess", libexec
    mv "#{bin}/mysqlaccess.conf", libexec
  end

  def post_install
    # Make sure that data directory exists
    datadir.mkpath
    unless File.exist? "#{datadir}/mysql/user.frm"
      ENV['TMPDIR'] = nil
      system "#{bin}/mysql_install_db", "--verbose", "--user=#{ENV["USER"]}",
        "--basedir=#{prefix}", "--datadir=#{datadir}", "--tmpdir=/tmp"
    end
  end

  def caveats; <<-EOS.undent
    A "/etc/my.cnf" from another install may interfere with a Homebrew-built
    server starting up correctly.

    To connect:
        mysql -uroot
    EOS
  end

  plist_options :manual => 'mysql.server start'

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>Program</key>
      <string>#{opt_bin}/mysqld_safe</string>
      <key>RunAtLoad</key>
      <true/>
      <key>WorkingDirectory</key>
      <string>#{var}</string>
      <key>HardResourceLimits</key>
      <dict>
        <key>NumberOfFiles</key>
        <integer>16384</integer>
      </dict>
      <key>SoftResourceLimits</key>
      <dict>
        <key>NumberOfFiles</key>
        <integer>16384</integer>
      </dict>
    </dict>
    </plist>
    EOS
  end
end
