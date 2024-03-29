
#require 'SssSEMapp.rb'
require 'SssSEMtriggerBase.rb'

# responds to 'e', q', 'r', 's' or 'w' commands:
# 'sync EEPROM images', 'quit', 'restart system', 'shutdown system' or 'write settings'
# read SssSEMtriggerBase for ruby-side-usage.
#
# Usage from cli (quit SRParSBinoRuby):
# 	echo 'q' >> triggers/command.me
# Usage from php:
#	file_put_contents('triggers/command.me', 'q', FILE_APPEND);

class SssSEMtriggerCommandMe < SssSEMtriggerBase

	@sPathFileCronInject; attr_accessor :sPathFileCronInject

	def initialize(sPathFile = nil, sPathFileCronInject = nil)

		sPathFile = 'triggers/command.me' if sPathFile.nil?
		sPathFileCronInject = 'triggers/command.cron' if sPathFileCronInject.nil?

		super(sPathFile)

		@sPathFileCronInject = sPathFileCronInject

		self.removeCronInjector()

		self

	end # initialize


	# deploy a trigger for cron job to include as 'source' or '.'
	def deployTriggerSystemRestart()

		File.open(@sPathFileCronInject, 'wb') { |f| f.write('shutdown -r now; exit 0;') }

	end # deployTriggerSystemRestart


	# deploy a trigger for cron job to include as 'source' or '.'
	def deployTriggerSystemShutdown()

		File.open(@sPathFileCronInject, 'wb') { |f| f.write('shutdown -h now; exit 0;') }

	end # deployTriggerSystem


	# respond to 'q', 'r' or 's' commands: 'quit', 'restart system' or 'shutdown system'
	# controller calls hasData? if yes controller calls process
	def process()

		# first byte holds the command
		i = @sBuffer[0]

		# nil == i that would mean buffer is empty -> should never happen
		return super if i.nil?

		# OS X has different handling
		i = i.chr() if (:macosx == @sOS)

		sBasename = File::basename(@sPathFile)

		case i
			when 'e'
				# update EEPROM caches
				puts 'OK:ft:Got e-signal from Trigger ' << sBasename
				SssSEMapp.updateEEPROMcaches();

			when 'q'
				# quit
				puts 'OK:ft:Got quit-signal from Trigger ' << sBasename
				SssSEMapp.dealloc()

			when 'r'
				# restart system
				puts 'OK:ft:Got restart-signal from Trigger ' << sBasename
				self.deployTriggerSystemRestart()
				SssSEMapp.dealloc()

			when 's'
				# shutdown system
				puts 'OK:ft:Got shutdown-signal from Trigger ' << sBasename
				self.deployTriggerSystemShutdown()
				SssSEMapp.dealloc()

			when 'w'
				# write settings to disk
				puts 'OK:ft:Got write-settings-signal from Trigger ' << sBasename
				SssSEMapp.saveConfig()

			else

				# if not a valid command, clear buffer

		end # switch case

		super

	end # process


	# delete trigger file if it exists<br>
	# called by ::new()
	def removeCronInjector()

		# delete if exists
		if (File.exists?(@sPathFileCronInject))

			# remove it first
			File.delete(@sPathFileCronInject);

			if (File.exists?(@sPathFileCronInject))
				raise 'Can not delete file: ' << @sPathFileCronInject;
			end # if file still exists

		end # if trigger-file already exists

		self

	end # removeCronInjector
	protected :removeCronInjector

end # SssSEMtriggerCommandMe
