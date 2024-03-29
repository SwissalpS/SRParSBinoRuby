
require 'SssSEMapp.rb'
require 'SssSEMtriggerBase.rb'

# Sends 'o' or 'O' command to all SBAMFDDDs
# read SssSEMtriggerBase for ruby-side-usage.
#
# 0 = stop loop; any other value = start loop
#
# Usage from cli (start demo loop):
# 	echo -n '1' >> triggers/demoID
# Usage from php (stop demo loop):
#	file_put_contents('triggers/demoID', '0', FILE_APPEND);

class SssSEMtriggerDemoID < SssSEMtriggerBase

	def initialize(sPathFile = nil)

		sPathFile = 'triggers/demoID' if sPathFile.nil?

		super(sPathFile)

	end # initialize


	# send 'o' or 'O' command to all SBAMFDDDs
	# controller calls hasData? if yes controller calls process
	def process()

		# first byte defines action
		i = @sBuffer[0];

		# nil == i that would mean buffer is empty -> should never happen
		return super if i.nil?

		# convert byte-value to natural-value
		i = i.chr.to_i;

		# start or stop
		if (0 == i)

			# stop loop
			sData = 'O'
			puts 'OK:ft:Got stop-demo-loop-signal from Trigger '

		else

			# start loop
			sData = 'o'
			puts 'OK:ft:Got start-demo-loop-signal from Trigger '

		end # if start or stop loop

		# target serial ID
		iFDD = SssSEMapp.get(:serialBroadcastID, SBSerialBroadcastID);

		SssSEMapp.oIOframeHandler.writeFramed(iFDD, sData)

		# clear buffer and return self
		super

	end # process

end # SssSEMtriggerDemoID
