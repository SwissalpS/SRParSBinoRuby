
#require 'SssSEMapp.rb'
require 'SssSEMframeHandler.rb'
require 'SssSfletcher16.rb'

SssSEventTypeRequestEEPROMupload = 69
SssSEventTypeRequestEEPROMdump = 101
SssSEventTypeRequestEEPROMchecksum = 125

# match these with values from SBEEPROMSettings.h
SBEEPROMShighestAddress = 0xFFF
SBEEPROMSamountOfPages = 17
SBEEPROMSmaxSizeFDDpageWithMeta = 0xE5
SBEEPROMSmetaSizeFDDpage = 5



SssSEventStatusQued = 0x10
SssSEventStatusSent = 0x20
SssSEventStatusAckd = 0x30 # maybe one day we will be forced to really manage the flow
SssSEventStatusDone = 0x40

SssSEventSyncPriorityRaspberryPi = 0x2
SssSEventSyncPriorityArduino = 0x4

# object to hold sync event info
class SssSserialEvent

	# for events that need to keep track of ranges
	@addressRange = 0..0; attr_reader :addressRange

	# checksum buffers
	@iChecksumA = nil; attr_accessor :iChecksumA
	@iChecksumB = nil; attr_accessor :iChecksumB

	@iEventType = nil; attr_accessor :iEventType

	# do not execute before this time
	@iExecuteAfterTS = nil; attr_accessor :iExecuteAfterTS
	@iStatus = nil; attr_accessor :iStatus

	# an attempt to prioratize events
	@iSyncPriority = nil; attr_accessor :iSyncPriority

	# who will receive the message generated by this event (serial ID)
	@iTargetID = nil; attr_accessor :iTargetID

	# address pointer used for multiple return frames
	@iPointer = 0; attr_accessor :iPointer

	def initialize(iTargetID = nil, iEventType = nil, iStatus = SssSEventStatusQued, addressRange = 0..0, iChecksumA = nil, iChecksumB = nil, iSyncPriority = SssSEventSyncPriorityRaspberryPi)

		@iTargetID = iTargetID
		@iEventType = iEventType
		@iStatus = (iStatus.nil?) ? SssSEventStatusQued : iStatus

		self.setAddressRange(addressRange)

		@iChecksumA = iChecksumA & 0xFF
		@iChecksumB = iChecksumB & 0xFF

		@iSyncPriority = (iSyncPriority.nil?) ? SssSEventSyncPriorityRaspberryPi : iSyncPriority

		@iPointer = 0

	end # initialize


	def checksumMatch?(iChecksumA, iChecksumB)

		(iChecksumA == @iChecksumA) && (iChecksumB == @iChecksumB)

	end # checksumMatch?


	# pass nil for target and/or type to match any target and/or type
	def matches?(iTarget = nil, iType = nil, iStatus = SssSEventStatusSent)

		# only match status
		return (iStatus == @iStatus) if (iTarget.nil? && iType.nil?)

		# only match status and type
		return (iType == @iEventType) && (iStatus == @iStatus) if iTarget.nil?

		# only match status and target
		return (iTarget == @iTargetID) && (iStatus == @iStatus) if iType.nil?

		# match all three
		(iTarget == @iTargetID) && (iType == @iEventType) && (iStatus == @iStatus)

	end # matches?


	def setAddressRange(newRange)

		return nil if (Range != newRange.class)

		iFirst = newRange.first
		iLast = newRange.last

		return nil if iFirst > iLast

		iFirst = [0, iFirst].max

		iLast -= 1 if newRange.exclude_end?

		iLast = [SBEEPROMShighestAddress, iLast].min

		@addressRange = iFirst..iLast

	end # setAddressRange
	alias addressRange= :setAddressRange

end # SssSserialEvent




# the EventManager makes sure one request is sent at a time and that the next
# request is only sent after the previous has been satisfied.
class SssSEMeventManager

	@aEvents = []; attr_reader :aEvents
	@oFletcher = nil; attr_reader :oFletcher


	def initialize()

		@aEvents = []

		# initialize fletcher
		@oFletcher = SssSfletcher16Class.new()

	end # initialize


	# create and add the initial events needed to sync EEPROM settings
	def addInitialSyncEvents()

		# SBAMM - id 0
		iTarget = 0
		oRange = 0..13
		iChecksumA, iChecksumB = self.checksumForRange(iTarget, oRange)

		self.addEvent(SssSserialEvent.new(iTarget, SssSEventTypeRequestEEPROMchecksum, SssSEventStatusQued, oRange, iChecksumA, iChecksumB, SssSEventSyncPriorityRaspberryPi))

		# SBAMFDDDs - ids 1..3
		for iTarget in 1..3 do

			iChecksumA, iChecksumB = self.checksumForRange(iTarget, oRange)

			self.addEvent(SssSserialEvent.new(iTarget, SssSEventTypeRequestEEPROMchecksum, SssSEventStatusQued, oRange, iChecksumA, iChecksumB, SssSEventSyncPriorityRaspberryPi))

			for iPage in 0...SBEEPROMSamountOfPages do

				oRange = self.rangeForFDDpage(iPage)
				iChecksumA, iChecksumB = self.checksumForRange(iTarget, oRange)

				self.addEvent(SssSserialEvent.new(iTarget, SssSEventTypeRequestEEPROMchecksum, SssSEventStatusQued, oRange, iChecksumA, iChecksumB, SssSEventSyncPriorityArduino))

			end # loop each page

		end # for loop FDDDs

	end # addInitialSyncEvents


	def addEvent(oEvent)

		return self if oEvent.class != SssSserialEvent

		@aEvents << oEvent

		self

	end # addEvent


	def checksumForRange(iID, oRange)

		oFile = self.fileForID(iID)
		return [nil, nil] if oFile.nil?

		# initialize fletcher
		@oFletcher.reset()

		# position file pointer
		oFile.seek(oRange.first)

		for iPos in oRange

			@oFletcher.addByte(oFile.getc())

		end # for loop full range

		oFile.close

		# return checksum
		@oFletcher.aChecksum

	end # checksumForRange


	def dealloc()
		# TODO:

		@oFletcher.dealloc if !@oFletcher.nil?
		@oFletcher = nil
		
	end


	def defaultEEPROMstringForID(iID)

		# NOTE: read SBEEPROMSettings.h and .cpp for exact address mapping!!!!
		sOut = ''

		# valid id?
		return sOut if !(0..3).member? iID

		# byte 0 - composition of IDs (mainly for id 0)
		sOut << (180 + iID).chr

		# byte 1 - serial port mapping
		sOut << (0b01001110).chr

		# byte 2 - debug level
		sOut << (0).chr

		# byte 3 - year
		oT = Time.now
		sOut << ((oT.year() - 2000) & 0xFF).chr()

		# byte 4 - month
		sOut << ((oT.month() - 1) & 0xFF).chr()

		# byte 5 - day
		sOut << ((oT.day() - 1) & 0xFF).chr()

		# byte 6 - randomizer analog pin
		sOut << (0).chr

		# byte 7..10 - serial delay between frames
		sOut << (0).chr << (0).chr << (0).chr << (50).chr

		# byte 11..12 - serial baud indexes (each port uses 4 bits)
		sOut << (238).chr << (238).chr

		# byte 13 - serial id of RasPi = 0xDD
		sOut << SBSerialRaspberryPiID.chr

		# byte 14 - active ports
		sOut << (5).chr

		# byte 15 - reset loop
		sOut << (0).chr

		if (0 == iID)
			# master (time-keeper)
			iLastOctet = 10
		elsif (SBSerialBroadcastID == iID)
			iLastOctet = 40
		else
			iLastOctet = 10 * iID
		end # translate serial ID to Ethernet MAC and IP last octet

		# bytes 16..21 - Ethernet MAC address
		sOut << ().chr << ().chr << ().chr << ().chr << ().chr << iLastOctet.chr

		# bytes 22..25 - Ethernet IP address
		sOut << (192).chr << (168).chr << (123).chr << iLastOctet.chr

		# bytes 26..29 - Ethernet broadcast IP
		sOut << (224).chr << (0).chr << (0).chr << (1).chr

		# bytes 30..33 - Ethernet gateway IP
		sOut << (192).chr << (168).chr << (123).chr << (123).chr

		# bytes 34..37 - Ethernet subnet
		sOut << (255).chr << (255).chr << (255).chr << (0).chr

		#bytes 38..39 - Ethernet port
		sOut << (SBethernetDefaultPort >> 8).chr << (SBethernetDefaultPort & 0xFF).chr
		
		sBlank = (0xFF).chr()

		for i in 0x30..SBEEPROMShighestAddress do
			sOut << sBlank
		end # loop fill up rest with blanks

		sOut

	end # defaultEEPROMstringForID


	def deleteEvent(oEvent)

		@aEvents.delete oEvent

		self

	end # deleteEvent


	def executeNextStep()

		# not waiting for any response?
		if self.matchingEvents(nil, nil, SssSEventStatusSent).empty?

			aQue = self.matchingEvents(nil, nil, SssSEventStatusQued)
			# got none in que -> nothing to do
			return self if aQue.empty?

			self.sendRequest(aQue.first)

		end # if not waiting for a response -> we can send one from que

		self

	end # executeNextStep


	# return file object ready for random access
	def fileForID(iID)

		sPathBase = SssSEMapp.get(:pathEEPROMimages, '/var/tmp/EEPROMimages/')

		# ensure trailing slash
		sPathBase += '/' if '/' != sPathBase[sPathBase.length() -1].chr

		begin

			# TODO: ensure path exists
			`mkdir -p #{sPathBase}`

			# does file already exist?
			sPathFile = sPathBase + iID.to_s + '.bin'
			if !File.exists? sPathFile

				File.open(sPathFile, 'wb') { |f| f.write(self.defaultEEPROMstringForID(iID)) }

			end # if file does not exist

			# open for random access
			File.open(sPathFile, 'r+b')

		rescue Exception => e

			puts e

		ensure

			nil

		end # try

	end # fileForID


	def matchingEvents(iTarget, iType, iStatus)

		aMatches = []

		@aEvents.each do |oEvent|

			aMatches << oEvent if oEvent.matches?(iTarget, iType, iStatus)

		end # loop collecting matching Events

		aMatches

	end # matchingEvents


	def sendRequest(oEvent)

		return self if oEvent.class != SssSserialEvent

		iType = oEvent.iEventType
		iTarget = oEvent.iTargetID

		# what kind of request is this?
		if SssSEventTypeRequestEEPROMdump == iType

			# send request to copy to local storage
			sData = 'e'

			# start address
			sData << ((oEvent.addressRange.first >> 8) & 0xFF).chr
			sData << (oEvent.addressRange.first & 0xFF).chr

			# last address
			sData << ((oEvent.addressRange.last >> 8) & 0xFF).chr
			sData << (oEvent.addressRange.last & 0xFF).chr

			# length
			sData << ((oEvent.addressRange.last - oEvent.addressRange.first + 1) & 0xFF).chr

			SssSEMapp.oIOframeHandler.writeFramed(iTarget, sData)

			oEvent.iStatus = SssSEventStatusSent

			# make sure the pointer is ready for when the dump frame(s) come in
			oEvent.iPointer = oEvent.addressRange.first

		elsif SssSEventTypeRequestEEPROMchecksum == iType

			# request checksum comparison for range
			sData = '{'

			# start address
			sData << ((oEvent.addressRange.first >> 8) & 0xFF).chr
			sData << (oEvent.addressRange.first & 0xFF).chr

			# last address
			sData << ((oEvent.addressRange.last >> 8) & 0xFF).chr
			sData << (oEvent.addressRange.last & 0xFF).chr

			SssSEMapp.oIOframeHandler.writeFramed(iTarget, sData)

			oEvent.iStatus = SssSEventStatusSent

			# make sure the pointer is ready for when the dump frame(s) come in
			oEvent.iPointer = oEvent.addressRange.first

		elsif SssSEventTypeRequestEEPROMupload == iType

			# upload data
			sData = 'E'

			# start address
			iFirst = oEvent.iPointer
			sData << ((iFirst >> 8) & 0xFF).chr
			sData << (iFirst & 0xFF).chr

			# last address (either given range or fill max 1 frame)
			# command, start address, last address, length
			# 1 byte  + 2 bytes		+ 2 bytes	  + 1 byte
			iEffectiveDataLength = SBSerialMaxDataLengthPerFrame - 4
			iLast = [oEvent.addressRange.last, (iFirst + iEffectiveDataLength - 1)].min

			sData << ((iLast >> 8) & 0xFF).chr
			sData << (iLast & 0xFF).chr

			# length
			sData << ((iLast - iFirst + 1) & 0xFF).chr

			# actual data
			oFile = self.fileForID(iTarget)
			raise 'real bad error, can not read stupid file' if oFile.nil?

			for iPos in iFirst..iLast

				sData << oFile.getc().chr()

				oEvent.iPointer += 1

			end # for loop data

			oFile.close

			SssSEMapp.oIOframeHandler.writeFramed(iTarget, sData)

			# are we done?
			if oEvent.addressRange.last < oEvent.iPointer

				oEvent.iStatus = SssSEventStatusDone

			#else

				# move range for next cycle
				# no longer required as we us pointer now
				#oEvent.addressRange = ((iLast + 1)..oEvent.addressRange.last)

			end # if done with this upload task or not

		end # if dump request or checksum request

		sData = iType = iTarget = iFirst = iLast = nil

		self

	end # sendRequest


	def rangeForFDDpage(iPage)

		# range check
		iPage = [iPage, SBEEPROMSamountOfPages].min
		iPage = [iPage, 0].max

		# address where meta data starts
		iFirst = 1 + (SBEEPROMShighestAddress - (SBEEPROMSmaxSizeFDDpageWithMeta * (iPage + 1)))
		iLast = iFirst + SBEEPROMSmaxSizeFDDpageWithMeta - 1

		iFirst..iLast

	end # rangeForFDDpage


	# called by SssSserial::executeFrame(oFrame) if a - 102 - f - EEPROM dump frame is encountered
	def responseDumpEEPROM(oFrame)
		
		# check aEvents to find an event of type 101 sent to same id as frame sender
		iSender = oFrame.senderID
		aMatchingEvents = self.matchingEvents(iSender, SssSEventTypeRequestEEPROMdump, SssSEventStatusSent)

		# no match? not good, but what can we do?
		return self if aMatchingEvents.empty?

		oEvent = aMatchingEvents.first

		oFile = self.fileForID(iSender)
		return self if oFile.nil?

		# write data from frame to local storage
		oFile.seek(oEvent.iPointer)

		oFrame.resetPointer
		while iByte = oFrame.nextByte() do

			oFile.putc iByte

			oEvent.iPointer += 1

		end # loop bytes

		oFile.close

		# are there more frames to be expected?
		if oEvent.iPointer > oEvent.addressRange.last

			# no, this was the last one
			# mark as done
			oEvent.iStatus = SssSEventStatusDone

		end # if 'event' now satisfied

		# cleanup
		oFile = iSender = oEvent = aMatchingEvents = iByte = nil

		self

	end # responseDumpEEPROM

	# called by SssSserial::executeFrame(oFrame) if a - 125 - } - Response Checksum of EEPROM - frame is encountered
	def responseChecksumEEPROM(oFrame)

		# no point in proceding if invalid data length
		return self if 2 < oFrame.data.count

		# check aEvents to find an event of type 123 sent to same id as frames sender
		iSender = oFrame.senderID
		aMatchingEvents = self.matchingEvents(iSender, SssSEventTypeRequestEEPROMchecksum, SssSEventStatusSent)

		# no match? not good, but what can we do?
		return self if aMatchingEvents.empty?

		# what could cause more than one match and how do we priorotize... or respond to all? hmm, notification and event seem to be a bit mixed up
		# for now we will simply use the first
		oEvent = aMatchingEvents.first

		# compare the checksums
		# if same, nothing to do but mark done
		if oEvent.checksumMatch?(oFrame.data[0], oFrame.data[1])

			# ok, match no sync required
			oEvent.iStatus = SssSEventStatusDone

		else

			# do not match
			# who has priority?
			if (SssSEventSyncPriorityArduino == oEvent.iSyncPriority)

				# Arduino has priority -> ask for dump
				oEvent.iStatus = SssSEventStatusQued
				oEvent.iEventType = SssSEventTypeRequestEEPROMdump

			elsif (SssSEventSyncPriorityRaspberryPi == oEvent.iSyncPriority)

				# Raspberry Pi has priority -> send data
				oEvent.iStatus = SssSEventStatusQued
				oEvent.iEventType = SssSEventTypeRequestEEPROMupload
				oEvent.iPointer = oEvent.addressRange.first

			else

				# should never happen
				puts 'exceptional situation here, should never happen but it did!'
				oEvent.iStatus = SssSEventStatusDone

			end # if Arduino has priority or RasPi

		end # if checksums match or not

		# if not same, send local copy or fetch EEPROM values?

		self

	end # responseChecksumEEPROM

end # SssSEMeventManager
