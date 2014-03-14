
require 'SssSEMapp.rb'
require 'SssSEMtriggerBase.rb'

# Sends 'u', 'v' or 'V' command to SBAMM optionally with duration attached
# read SssSEMtriggerBase for ruby-side-usage.
#
# u = set timer to duration -> milliseconds
# Usage from cli (set timer to 5 minutes on display 2):
# 	echo -n '2u300000' >> triggers/timer
# Usage from php:
#	file_put_contents('triggers/timer', '2u300000', FILE_APPEND);
#
# v = start timer
# Usage from cli (on display 2):
# 	echo -n '2v' >> triggers/timer
# Usage from php:
#	file_put_contents('triggers/timer', '2v', FILE_APPEND);
#
# V = stop timer
# Usage from cli (on display 2):
# 	echo -n '2V' >> triggers/timer
# Usage from php:
#	file_put_contents('triggers/timer', '2V', FILE_APPEND);

class SssSEMtriggerTimer < SssSEMtriggerBase

	def initialize(sPathFile = nil)

		sPathFile = 'triggers/timer' if sPathFile.nil?

		super(sPathFile)

	end # initialize


	# send 'u', 'v' or 'V' command to SBAMM
	# controller calls hasData? if yes controller calls process
	def process()

		# first byte holds the address
		i = @sBuffer[0]

		# nil == i that would mean buffer is empty -> should never happen
		return super if i.nil?

		# convert byte-value to natural-value
		i = i.chr.to_i

		# no broadcast possible as we are using natural chars instead of byte-value
		# abort if not a valid ID
# TODO: why? really?
		#return super if !((1..3).member?(i)) # if invalid ID

		# target serial ID
		iFDD = i

		sBasename = File::basename(@sPathFile)

		# second byte holds the command
		i = @sBuffer[1]

		case i.chr
			when 'u'
				# set duration
				sData = 'u'

				# read duration
				i = @sBuffer[2..-1].to_i

				# if not a valid duration, clear buffer
				return super if (1 > i)

				puts 'OK:ft:Got set-timer-duration-signal from Trigger ' << sBasename + ' for FDD ' << iFDD.to_s << ' value: ' << i.to_s

				# append 4 bytes
				sData << ((i >> 24) & 0xFF) << ((i >> 16) & 0xFF)
				sData << ((i >> 8) & 0xFF) << (i & 0xFF)

			when 'v'
				# start timer
				puts 'OK:ft:Got start-timer-signal from Trigger ' << sBasename + ' for FDD ' << iFDD.to_s

				sData = 'v'

			when 'V'
				# stop timer
				puts 'OK:ft:Got stop-timer-signal from Trigger ' << sBasename + ' for FDD ' << iFDD.to_s

				sData = 'V'

			else

				# if not a valid command, clear buffer
				puts 'KO:ft: Got invalid-timer signal from Trigger ' << sBasename
				return super

		end # switch case

		SssSEMapp.oIOframeHandler.writeFramed(iFDD, sData)

		# clear buffer and return self
		super

	end # process

end # SssSEMtriggerTimer
