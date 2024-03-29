
require 'SssSEMapp.rb'
require 'SssSEMtriggerBase.rb'

# Sends incoming bytes as-is to SBAMM
# read SssStriggerBase for ruby-side-usage.
#
# Usage from cli:
# 	cat someFrameFile >> triggers/raw
# Usage from php:
#	file_put_contents('triggers/raw', sRawFrameDataToSend, FILE_APPEND);

class SssSEMtriggerRaw < SssSEMtriggerBase

	def initialize(sPathFile = nil)

		sPathFile = 'triggers/raw' if sPathFile.nil?

		super(sPathFile)

	end # initialize


	# send bytes to SBAMM
	# controller calls hasData? if yes controller calls process
	def process()

		puts 'OK:ft:Got raw-bytes-signal from Trigger '

		SssSEMapp.oIOframeHandler.writeRawBytes(@sBuffer)

		# clear buffer and return self
		super()

	end # process

end # SssSEMtriggerRaw
