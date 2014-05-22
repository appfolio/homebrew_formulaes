require 'formula'

class ApacheSolr48 < Formula
  homepage 'http://lucene.apache.org/solr'
  url 'http://archive.apache.org/dist/lucene/solr/4.8.0/solr-4.8.0.tgz'
  sha1 '192b4095361a2a140aa6557d75f63636c24dccf1'

  def solr_xml; <<-XML.undent
    <solr persistent="false">
      <cores adminPath="/admin/cores">
      </cores>
    </solr>
    XML
  end
  
  def install
    libexec.install Dir['*']
    
    solr_webapp_dir = libexec + 'example/webapps/solr'
    solr_webapp_dir.mkpath
    
    (prefix + 'solr.xml').write solr_xml
    
    plist_path.write startup_plist
    plist_path.chmod 0644
  end

  def caveats; <<-TEXT.undent
    If this is your first install, automatically load on login with:
        mkdir -p ~/Library/LaunchAgents
        cp #{plist_path} ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/#{plist_path.basename}

    If this is an upgrade and you already have the #{plist_path.basename} loaded:
        launchctl unload -w ~/Library/LaunchAgents/#{plist_path.basename}
        cp #{plist_path} ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/#{plist_path.basename}

    Web access:
        http://localhost:8988/solr

    Log:
        tail -f /usr/local/var/log/apache-solr-48.log

    !!! Solr cores are not persisted between restarts of the solr server !!!
  TEXT
  end

  def startup_plist; <<-XML.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>java</string>
          <string>-Dsolr.solr.home=#{prefix}</string>
          <string>-Djetty.port=8988</string>
          <string>-Dcom.sun.management.jmxremote</string>
          <string>-jar</string>
          <string>start.jar</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>UserName</key>
        <string>#{`whoami`.chomp}</string>
        <key>WorkingDirectory</key>
        <string>#{libexec}/example</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/apache-solr-48.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/apache-solr-48.log</string>
      </dict>
    </plist>
    XML
  end
end
