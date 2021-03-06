require 'weakref'

module ASF

  class Mail
    def self.list
      begin
        return Hash[@list.to_a] if @list
      rescue NoMethodError, WeakRef::RefError
      end

      list = Hash.new

      # load info from LDAP
      people = ASF::Person.preload(['mail', 'asf-altEmail'])
      people.each do |person|
        (person.mail+person.alt_email).each do |mail|
          list[mail.downcase] = person
        end
      end

      # load all member emails in one pass
      ASF::Member.each do |id, text|
        Member.emails(text).each do |mail| 
          list[mail.downcase] ||= Person.find(id)
        end
      end

      # load all ICLA emails in one pass
      ASF::ICLA.each do |icla|
        person = Person.find(icla.id)
        list[icla.email.downcase] ||= person
        next if icla.id == 'notinavail'
        list["#{icla.id.downcase}@apache.org"] ||= person
      end

      @list = WeakRef.new(list)
      list
    end

    def self.lists(public_private= false)
      apmail_bin = ASF::SVN['infra/infrastructure/apmail/trunk/bin']
      file = File.join(apmail_bin, '.archives')
      if not @lists or File.mtime(file) != @list_mtime
        @list_mtime = File.mtime(file)
        @lists = Hash[File.read(file).scan(
          /^\s+"(\w[-\w]+)", "\/home\/apmail\/(public|private)-arch\//
        )]
      end

      public_private ? @lists : @lists.keys
    end

    # common configuration for sending mail
    def self.configure
      # fetch overrides
      sendmail = ASF::Config.get(:sendmail)

      if sendmail
        # convert string keys to symbols
        options = Hash[sendmail.map {|key, value| [key.to_sym, value.untaint]}]

        # extract delivery method
        method = options.delete(:delivery_method).to_sym
      else
        # provide defaults that work on whimsy-vm* infrastructure.  Since
        # procmail is configured with a self-signed certificate, verification
        # isn't a possibility
        method = :smtp
        options = {openssl_verify_mode: 'none'}
      end

      ::Mail.defaults do
        delivery_method method, options
      end
    end
  end

  class Person < Base
    def self.find_by_email(value)
      value.downcase!

      person = Mail.list[value]
      return person if person
    end

    def obsolete_emails
      return @obsolete_emails if @obsolete_emails
      result = []
      if icla
        unless active_emails.any? {|mail| mail.downcase == icla.email.downcase}
          result << icla.email
        end
      end
      @obsolete_emails = result
    end

    def active_emails
      (mail + alt_email + member_emails).uniq
    end

    def all_mail
      active_emails + obsolete_emails
    end
  end

  class Committee
    def mail_list
      case name.downcase
      when 'comdev'
        'community'
      when 'httpcomponents'
        'hc'
      when 'whimsy'
        'whimsical'

      when 'brand management'
        'trademarks@apache.org'
      when 'executive assistant'
        'ea@apache.org'
      when 'legal affairs'
        'legal-internal@apache.org'
      when 'marketing and publicity'
        'press@apache.org'
      when 'tac'
        'travel-assistance@apache.org'
      when 'w3c relations'
        'w3c@apache.org'
      else
        name
      end
    end
  end
end
