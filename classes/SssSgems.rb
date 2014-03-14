##
# minimal OS detection and attempt to auto-install missing gems
require 'rubygems'
require 'rbconfig'

class SssSos

 public

	def self.os()

		host_os = RbConfig::CONFIG['host_os']

		case host_os

			when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
				:windows

			when /darwin|mac os/
				:macosx

			when /linux/
				:linux

			when /solaris|bsd/
				:unix

			else
				:unknown

		end # switch case

	end # os
	def os()
		SssSos::os()
	end # os

end # SssSos



begin

	require 'socket'
	puts 'OK:Socket gem loaded'

rescue LoadError

	puts 'KO:Socket gem not installed!'

	if (:macosx == SssSos::os())

		puts '    Open Terminal'
		puts '      login <admin account name><return>'
		puts '      <admin password><return>'
		puts '      sudo gem install socket<return>'
		puts '      <admin password><return>'
		puts ' wait, then:'
		puts '      exit<return>'
		exit(1)

	elsif (:linux == SssSos::os())

		if ('root' == ENV['USER'])

			puts '   I\'ll attempt to install it (needs internet)'
			puts `gem install socket`
			require 'socket'

		else

			puts '   Please login as root (or sudo)'
			puts '      gem install socket'
			exit(1)

		end # if is root

	end # if which os

end # try catch if Socket gem is installed


begin

	require 'eventmachine'
	puts 'OK:EventMachine gem loaded'
	
rescue LoadError

	puts 'KO:Eventmachine gem not installed!'

	if (:macosx == SssSos::os())

		puts '    Open Terminal'
		puts '      login <admin account name><return>'
		puts '      <admin password><return>'
		puts '      sudo gem install eventmachine<return>'
		puts '      <admin password><return>'
		puts ' wait, then:'
		puts '      exit<return>'
		exit(1)

	elsif (:linux == SssSos::os())

		if ('root' == ENV['USER'])

			puts '   I\'ll attempt to install it (needs internet)'
			puts `gem install eventmachine`
			require 'eventmachine'

		else

			puts '   Please login as root (or sudo)'
			puts '      gem install eventmachine'
			exit(1)

		end # if is root

	end # if which os

end # try catch if EM gem is installed
