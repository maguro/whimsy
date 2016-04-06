#!/usr/bin/env ruby
require 'json'
require 'time'

json = File.expand_path('../status.json', __FILE__)
status = JSON.parse(File.read(json)) rescue {}
git_info = `git show --format="%h  %ci"  -s HEAD`.strip rescue "?"
# TODO better format; don't assume we use master
git_repo = `git ls-remote origin master`.strip rescue "?"

# Get new status every minute
if not status['mtime'] or Time.now - Time.parse(status['mtime']) > 60
  begin
    require_relative './monitor'
    status = Monitor.new.status || {}
  rescue Exception => e
    print "Status: 500 Internal Server Error\r\n"
    print "Context-Type: text/plain\r\n\r\n"
    puts e.to_s
    puts "\nbacktrace:"
    e.backtrace.each {|line| puts "  #{line}"}
    exit
  end
end

# The following is what infrastructure team sees:
if %w(success info).include? status['level']
  print "Status: 200 OK\r\n\r\n"
else
  print "Status: 400 #{status['title'] || 'failure'}\r\n\r\n"
end

# What the browser sees:
print <<-EOF
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8"/>
    <title>Whimsy Status</title>

    <link rel="stylesheet" type="text/css" href="css/bootstrap.min.css"/>
    <link rel="stylesheet" type="text/css" href="css/status.css"/>
    
    <script type="text/javascript" src="js/jquery.min.js"></script>
    <script type="text/javascript" src="js/bootstrap.min.js"></script>
    <script type="text/javascript" src="js/status.js"></script>
  </head>

  <body>
    <img src="../whimsy.svg" class="logo"/>
    <h1>Whimsy VM2 Status</h1>

    <div class="list-group list-group-root well">
      Loading...
    </div>

    <table>
    <tr>
      <td class="alert-success">Success</td>
      <td>&nbsp;</td>
      <td class="alert-info">Info</td>
      <td>&nbsp;</td>
      <td class="alert-warning">Warning</td>
      <td>&nbsp;</td>
      <td class="alert-danger">Danger</td>
      <td>&nbsp;</td>
      <td class="alert-fatal">Fatal</td>
    </tr>
    </table>
    <br/>

    <p>
      This status is monitored by:
      <a href="https://www.pingmybox.com/dashboard?location=470">Ping My
      Box</a> (<a href="errors">full log</a>).
    </p>

    <h2>Additional status</h2>

    <ul>
      <li><a href="passenger">Passenger</a> (ASF committer only)</li>
      <li><a href="svn">Subversion</a></li>
      <li>Git code info: #{git_info}</li>
      <li>Git repo info: #{git_repo}</li>
    </ul>
  </body>
</html>
EOF
