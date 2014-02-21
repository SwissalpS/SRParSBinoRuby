
require 'SssStriggerBase.rb'
require 'SssSapp.rb'

# Sends 'r' command to SBAMM with SkyBIKE number attached
# read SssStriggerBase for ruby-side-usage.
#
# Usage from cli:
# 	echo -n '1' >> triggers/reset
# Usage from php:
#	file_put_contents('triggers/reset', '0', FILE_APPEND);

class SssStriggerReset < SssStriggerBase

	def initialize(sPathFile = nil)

		sPathFile = 'triggers/reset' if sPathFile.nil?

		super(sPathFile)

	end # initialize


	# controller calls hasData? if yes controller calls process<br>
	# send 'r' command to SBAMM
	def process()

		iBike = 0;

		# only need to look at the first byte
		i = @sBuffer[0];

		# nil == i that would mean buffer is empty -> should never happen
		return super if i.nil?

		# convert byte-value to natural-value (echo '1' >> start)
		i = i.chr.to_i;

		# if it's greater than 2, then third BIKE is meant
		# NOTE: this sets the maximum amount of bikes, if you want more than 3...
		if (2 < i)

			iBike = 2;

		end # if greater than 2

		sBasename = File::basename(@sPathFile)
		puts 'Got reset-signal from Trigger ' << sBasename + ' for BIKE ' << iBike.to_s

		iSBAMMid = SssSapp.get(:idSBAMM, 0);
		sData = 'r' << iBike.chr;

		$oSssSapp.oIOframeHandler.writeFramed(iSBAMMid, sData)

		# clear buffer and return self
		super

	end # process

end # SssStriggerReset
