#
# This is a sketch of what it would take to send board agendas via a cronjob.
#
# It currently sets @dryrun to true, preventing emails from being sent out.
#
# AGENDA_WORK is a directory that can be used to store information, depending
# on the strategy the cron job takes.
#

Dir.chdir File.expand_path('../..', __FILE__)

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../../../../../lib', __FILE__))
require 'whimsy/asf/agenda'
require 'mail'
require 'listen'

FOUNDATION_BOARD = ASF::SVN['private/foundation/board']
AGENDA_WORK = ASF::Config.get(:agenda_work).untaint || '/srv/agenda'

require './models/agenda'
require './models/ipc'

# draft reminder text
@reminder = ARGV.first || 'reminder1'
reminder = eval(File.read("views/actions/reminder-text.json.rb"))

# send reminders
@agenda = File.basename(Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].sort.last)
@from = "Whimsy <no-reply@apache.org>"
@dryrun = true
@subject = reminder[:subject]
@message = reminder[:body]
response = eval(File.read("views/actions/send-reminders.json.rb"))

# dump results for debugging purposes
puts JSON.pretty_generate(response)
