# Creates JSON output with the following format:
#
# {
#   "people": {
#     "uid": {
#       "name": "Public Name",
#       "noLogin": true // present only if the login is not valid
#     }
#     ...
# }
#

require_relative 'public_json_common'

# ASF people
peo = {}

peeps = ASF::Person.preload(['cn', 'loginShell', 'asf-personalURL', 'createTimestamp', 'modifyTimestamp']) # for performance

if peeps.empty?
  Wunderbar.error "No results retrieved, output not created"
  exit 0
end

# Make output smaller by ommitting commonest case (noLogin: false)
def makeEntry(hash, e)
  hash[e.id] = {
      name: e.public_name,
  }
  if e.banned?
    hash[e.id][:noLogin] = true
  else
    # Don't publish urls for banned logins
    if not e.urls.empty?
      hash[e.id][:urls] = e.urls
    end
  end
end

lastmodifyTimestamp = ''
lastcreateTimestamp = ''

peeps.sort_by {|a| a.name}.each do |e|
  makeEntry(peo, e)
  createTimestamp = e.createTimestamp
  if (createTimestamp > lastcreateTimestamp)
    lastcreateTimestamp = createTimestamp
  end
  modifyTimestamp = e.modifyTimestamp
  if (modifyTimestamp > lastmodifyTimestamp)
    lastmodifyTimestamp = modifyTimestamp
  end
end

info = {
  lastCreateTimestamp: lastcreateTimestamp,
#  This field has been disabled because it changes much more frequently than expected
#  This means that the file is flagged as having changed even when no other content has
#  lastTimestamp: lastmodifyTimestamp, # other public json files use this name
  people: peo,
}

public_json_output(info)
