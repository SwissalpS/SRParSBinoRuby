
require 'SssStriggerBase.rb'
require 'SssSapp.rb'

# Sends 'r' command to SBAMM with SkyBIKE number attached
# read SssStriggerBase for ruby-side-usage.
#
# Usage from cli:
# 	echo -n '1' >> triggers/stop
# Usage from php:
#	file_put_contents('triggers/stop', '0', FILE_APPEND);

class SssStriggerStop < SssStriggerBase

	def initialize(sPathFile = nil)

		sPathFile = 'triggers/stop' if sPathFile.nil?

		super(sPathFile)

	end # initialize


	# send 'S' command to SBAMM
	# controller calls hasData? if yes controller calls process
	def process()

		iBike = 0;

		# only need to look at the first byte
		i = @sBuffer[0];

		# nil == i that would mean buffer is empty -> should never happen
		return super if i.nil?

		# convert byte-value to natural-value (echo '1' >> start)
		i = i.chr.to_i;

		# if it's not 0, the second BIKE is meant
		# NOTE: limits to 2 BIKEs
		if (0 < i)

			iBike = 1;

		end # if greater than 0

		sBasename = File::basename(@sPathFile)
		puts 'Got stop-signal from Trigger ' << sBasename + ' for BIKE ' << iBike.to_s

		iSBAMMid = SssSapp.get(:idSBAMM, 0);
		sData = 'S' << iBike.chr;

		SssSapp.oSerial.writeFramed(iSBAMMid, sData)

		# clear buffer and return self
		super

	end # process

end # SssStriggerStop
