
require 'SssSEMapp.rb'
require 'SssSEMtriggerBase.rb'

# Sends 't' command then sends 'T' command
# read SssSEMtriggerBase for ruby-side-usage.
#
# Usage from cli (tell display 1 to show time):
# 	echo -n '1' >> triggers/currentTime
# Usage from php (display time on display 2):
#	file_put_contents('triggers/currentTime', '2', FILE_APPEND);

class SssSEMtriggerCurrentTime < SssSEMtriggerBase

	def initialize(sPathFile = nil)

		sPathFile = 'triggers/currentTime' if sPathFile.nil?

		super(sPathFile)

	end # initialize


	# send 't' and 'T' commands to FDD<br>
	# t = set time; T = display time
	# controller calls hasData? if yes controller calls process
	def process()

		# first byte holds the address
		i = @sBuffer[0]

		# nil == i that would mean buffer is empty -> should never happen
		return super if i.nil?

		# convert byte-value to natural-value
		iID = i.chr.to_i

		# no broadcast possible as we are using natural chars instead of byte-value
		# and are looking at only 1 byte
#TODO: allow 0 to 9 and map eg 9 to broadcast
		# abort if not a valid ID
		return super if !((0..3).member?(iID)) # if invalid ID

		# target serial ID
		iFDD = iID;

		# current time is (since midnight localtime)
		# convert to seconds since midnight: 86400 = (24*60*60)
		# multiply with 1000 for milliseconds
		i = 1000 * (Time.now.to_i % 86400)

		# set time
		sData = 't'

		# append time (4 bytes)
		sData << ((i >> 24) & 0xFF) << ((i >> 16) & 0xFF)
		sData << ((i >> 8) & 0xFF) << (i & 0xFF)

		puts 'OK:ft:Got show-utc-time-signal from Trigger '

		SssSEMapp.oIOframeHandler.writeFramed(iFDD, sData)

		# start displaying time
		sData = 'T'
		SssSEMapp.oIOframeHandler.writeFramed(iFDD, sData)

		# clear buffer and return self
		super

	end # process

end # SssSEMtriggerCurrentTime
