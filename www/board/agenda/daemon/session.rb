require 'fileutils'
require 'thread'
require 'securerandom'
require 'concurrent'

#
# Low-tech, file based session manager.  Each session is stored as a separate
# file on disk, and expires after two days.  Each request for a new session
# is guaranteed to return a session with a minimum of a day left before
# expiring.
#
# Concurrent::Map provides thread safe access to data; a mutex is used
# to additionally prevent concurrent updates.
#
# No direct use of timers, events, or threads are made allowing this
# service to be used in a varienty of contexts (e.g. Sinatra and 
# EventMachine).
#

class Session
  WORKDIR = File.expand_path('sessions', AGENDA_WORK)
  DAY = 24*60*60 # seconds

  @@sessions = Concurrent::Map.new
  @@users = Concurrent::Map.new {|map,key| map[key]=[]}

  @@semaphore = Mutex.new

  # find the latest session for the given user, creating one if necessary.
  def self.user(id)
    session = @@users[id].sort_by {|session| session[:mtime]}.last
    session = nil if session and session[:mtime] < Time.now - DAY

    # if not found, try refreshing data from disk and try again
    if not session
      self.load 
      session = @@users[id].sort_by {|session| session[:mtime]}.last
      session = nil if session and session[:mtime] < Time.now - DAY
    end

    # if still not found, generate a new session
    if not session
      @@semaphore.synchronize do
        secret = SecureRandom.hex(16)
        file = File.join(WORKDIR, secret)
        File.write(file, id)
        session = {id: id, secret: secret, mtime: File.mtime(file)}
        @@sessions[secret] = session
        @@users[id] << session
      end
    end

    # return the secret
    session[:secret]
  end

  # retrieve session for a given secret
  def self.[](secret)
    @@sessions[secret]
  end

  # load sessions from disk
  def self.load(files=nil)
    @@semaphore.synchronize do
      # default files to all files in the workdir and @@sessions hash
      files ||= Dir["#{WORKDIR}/*"].map {|file| file.dup.untaint} +
        @@sessions.keys.map {|secret| File.join(WORKDIR, secret)}

      files.uniq.each do |file|
        secret = File.basename(file)
        session = @@sessions[secret]

        File.delete file if session and session[:mtime] < Time.now - 2 * DAY

        if File.exist? file
          # update class variables if the file changed
          mtime = File.mtime(file)
          next if session and session[:mtime] == mtime

          session = {id: File.read(file), secret: secret, mtime: mtime}
          @@sessions[secret] == session
          @@users[session[:id]] << session
        else
          # remove session if the file no longer exists
          @@users[session[:id]].delete(session) if session
          @@sessions.delete(secret)
        end
      end
    end
  end

  # ensure the working directory exists
  FileUtils.mkdir_p WORKDIR
end
