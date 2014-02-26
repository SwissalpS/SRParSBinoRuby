require 'SssSapp.rb'
require 'SssSfletcher16.rb'
require 'SssSEventManager.rb'
require 'SssSserialFrame.rb'
require 'SssSbitMath.rb'
require 'SssSonlineMarkerFile.rb'

SssSdebugMode = 7 if !defined? SssSdebugMode

SBSerialSpaceLength = 29 if !defined? SBSerialSpaceLength # :doc:
SBSerialMaxFrameLength = 35 if !defined? SBSerialMaxFrameLength
SBSerialMaxDataLengthPerFrame = 28 if !defined? SBSerialMaxDataLengthPerFrame
SBSerialBroadcastID = 254 if !defined? SBSerialBroadcastID

SBSerialRaspberryPiID = 0xDD if !defined? SBSerialRaspberryPiID
SssSNullSpacer = 0.chr * SBSerialSpaceLength if !defined? SssSNullSpacer

SBethernetDefaultIP = '192.168.123.40' if !defined? SBethernetDefaultIP
SBethernetDefaultIPbroadcast = '224.0.0.1' if !defined? SBethernetDefaultIPbroadcast
SBethernetDefaultIPgateway = '192.168.123.123' if !defined? SBethernetDefaultIPgateway
SBethernetDefaultIPsubnet = '255.255.255.0' if !defined? SBethernetDefaultIPsubnet
SBethernetDefaultPort = 12345 if !defined? SBethernetDefaultPort

##
# intermediates communication and controls who sends what
# also manages the SssSEventManager instance
# Instantiated and controlled by SssSapp

class SssSIOframeHandlerClass

  private

	@@bufferMaxLen = SBSerialMaxFrameLength + SBSerialSpaceLength;

	@@fDelayBetweenFrames = 0.004; attr_reader :fDelayBetweenFrames

  protected

	@hFrameHistory = {}; attr_reader :hFrameHistory #[222];

	@hOnlineClientHash = {}; attr_reader :hOnlineClientHash

	@iCountSpace;

	@iMySerialID; attr_reader :iMySerialID

	@iNextFrameID;

	# bit-hash of our (and other members on the bus) status
	# starting from least significant bit
	# 00: MemberID0 is busy or not (Arduino 0 -> master)
	# 01: MemberID1 is busy or not
	# 02: MemberID2 is busy or not
	# 03: MemberID3 is busy or not
	# 04: MemberID4 is busy or not (Raspberry Pi)
	# 05: current frames are for us or not
	# 06: header detected, else counting spaces
	# 07: header parsed (we are reading frame-data), else parsing or searching
	# 08: SBF3DSerial: load incoming to data buffer, else parse as command
	# 09: SBF3DSerial: load incoming to name buffer, else parse as command
	# 10: SBF3DSerial: load incoming to category buffer, else parse as command
	# 11: SBF3DSerial: (0 = 8-bit-mode; 1 = 16-bit-mode)
	# 12: SBF3DSerial: [0 = 8 or 16-bit-mode; 1 = 32-bit-mode] <-- we have only 1 32-bit-value at a time so this is resereved in case we have more some day
	# 13: SBF3DSerial: first or second byte in 16-bit-mode; [bytes 1, 2, or 4 in 32-bit-mode]
	# 14: SBF3DSerial: [third and fourth byte (in combo with bit 12) in 32-bit-mode] <-- --> 11
	@iStatus; attr_reader :iStatus

 public

	@oEventManager = nil

	# for incoming traffic we use a seperate fletcher instance to avaid colusion
	@oFletcher = nil

	@oIncomingFrame = nil; attr_reader :oIncomingFrame


	def initialize(*options)

		@hFrameHistory = {} #Array.new(222) { Array.new(SBSerialMaxFrameLength); }

		@hOnlineClientHash = {}

		@iCountSpace = 0

		@iMySerialID = $oSssSapp.get(:serialID, SBSerialRaspberryPiID)

		# frame ids 7...222
		@iNextFrameID = 7 + rand(215);

		@iStatus = 0;

		@oFletcher = SssSfletcher16Class.new()

		@oIncomingFrame = nil

		@oEventManager = SssSEventManager.new()

		#@oEventManager.addInitialSyncEvents()

	end # initialize


	# destroy this object cleanly
	def dealloc()

		@oEventManager.dealloc if !@oEventManager.nil?
		@oEventManager = nil

		@oFletcher.dealloc if !@oFletcher.nil?
		@oFletcher = nil

		@oIncomingFrame.dealloc if !@oIncomingFrame.nil?
		@oIncomingFrame = nil

		@hFrameHistory = nil

		@hOnlineClientHash.each do |hClient|
			hClient[:marker].dealloc if !hClient[:marker].nil?
		end # loop all markers
		@hOnlineClientHash = nil

		nil;

	end # dealloc


	# chance to filter debug messages: Raw view of byte-stream
	def debugIncoming(mRead)

		sOut = ''
		mRead.each_byte do |iByte|

			if 0 == iByte
				sOut += '.'
			else
				sOut += ' 0x' << iByte.to_s(16)  << ' '
				sOut += iByte.chr if 32 <= iByte
				sOut += '.' if 32 > iByte
			end # if

		end # mRead

		puts sOut

	end # debugIncoming
	protected :debugIncoming


	def getIPstringForID(iID)

		sID = 'id' << iID.to_s

		# is it a known ID?
		return nil if @hOnlineClientHash[sID].nil?

		# has it talked to us over Ethernet?
		return nil if @hOnlineClientHash[sID][:ethernetIP].nil?

		@hOnlineClientHash[sID][:ethernetIP]

	end # getIPstringForID


	# invalidate incoming frame
	def invalidate()

		@iCountSpace = 0;
	#	@iCountFrameBytes = 0;
		# not for us
		@iStatus = SssSbitMath.bitClear(@iStatus, 5);
		# header not detected -> look for next header
		@iStatus = SssSbitMath.bitClear(@iStatus, 6);
		# header not parsed
		@iStatus = SssSbitMath.bitClear(@iStatus, 7);

		@oIncomingFrame.dealloc()
		@oIncomingFrame = nil;

	end # invalidate


	def isOnlineEthernet?(iID)

		return NO if $oSssSapp.oEthernet.nil?
		return NO if $oSssSapp.oEthernet.disconected?

		sID = 'id' << iID.to_s
		return NO if @hOnlineClientHash[sID].nil?

		return @hOnlineClientHash[sID][:marker].isOnlineEthernet?
		# or to avoid disk access
		return !@hOnlineClientHash[sID][:ethernetIP].nil?

	end # isOnlineEthernet?


	def isOnlineSerial?(iID)

		# NO if no serial connection at all
		return NO if $oSssSapp.oSerial.nil?
		return NO if $oSssSapp.oSerial.disconected?

		sID = 'id' << iID.to_s
		return NO if @hOnlineClientHash[sID].nil?

		return @hOnlineClientHash[sID][:marker].isOnlineSerial?
		# or to avoid disk access
		return @hOnlineClientHash[sID][:ethernetIP].nil?

	end # isOnlineSerial?


	def markOnline(iID, sIP)

		sID = 'id' << iID.to_s
		iNow = Time.now.to_i

		# do we already have this?
		if (@hOnlineClientHash[sID].nil?)
			# new client
			@hOnlineClientHash[sID] = { :ethernetIP => sIP, :serialID => iID, :firstSeen => iNow, :marker => SssSonlineMarkerFile.new(iID, sIP) }
		else
			# update entry
			if (!sIP.nil?)
				if (@hOnlineClientHash[sID][:ethernetIP].nil?)
					@hOnlineClientHash[sID][:ethernetIP] = sIP
					@hOnlineClientHash[sID][:ethernetLastSeen] = iNow
					@hOnlineClientHash[sID][:marker].goOnlineEthernet(sIP)
				end # if got IP now
			else
				@hOnlineClientHash[sID][:serialLastSeen] = iNow
				@hOnlineClientHash[sID][:marker].goOnlineSerial()
			end # if got an IP

		end # if already seen

	end # markOnline


	# Returns the next frame-id to use
	def nextFrameID()

		@iNextFrameID += 1

		# if rollover
		@iNextFrameID = 7 if (222 < @iNextFrameID)

		return @iNextFrameID

	end # nextFrameID


	# Check the first four bytes after <0xFF> and determine if frame is for us
	def parseHeader(iByte, sIP)

	#	if (0 == @iCountFrameBytes)
		if @oIncomingFrame.targetID.nil?

			# target ID

			if (iMySerialID == iByte || SBSerialBroadcastID == iByte)

				# this is for us
				@iStatus = SssSbitMath.bitSet(@iStatus, 5);
				# we are busy?
				#@iStatus = SssSbitMath.bitSet(@iStatus, iMySerialID);

				@oFletcher.reset();
				@oFletcher.addByte(iByte);
				@oIncomingFrame.targetID= iByte

				self.markOnline(iByte, sIP)
				@oIncomingFrame.targetIP= sIP if !sIP.nil?

			else

				# not for us --> look for next frame
				self.invalidate();

			end # if for this Arduino, another or error

		elsif @oIncomingFrame.senderID.nil?

			# sender ID

			if (@iMySerialID > iByte)

				# valid sender ID

				@oFletcher.addByte(iByte)
				@oIncomingFrame.senderID= iByte

				self.markOnline(iByte, sIP)

			else

				# invalid sender ID --> look for next frame
	# TODO: debug
				self.invalidate()

			end # valid sender or not

		elsif @oIncomingFrame.frameID.nil?

			# frame ID

			@oFletcher.addByte(iByte)
			@oIncomingFrame.frameID= iByte

		elsif @oIncomingFrame.dataLength.nil?

			# data length

			@oFletcher.addByte(iByte)
			@oIncomingFrame.dataLength= iByte

			# header is parsed now
			@iStatus = SssSbitMath.bitSet(@iStatus, 7);

		end # if target ID, sender ID, frame ID or data length

	end # parseHeader


	def parseIncoming(mRead, sIP = nil)

		return 0 if mRead.nil?

		self.debugIncoming(mRead);

		mRead.each_byte() do |iByte|

			if (SssSbitMath.bitRead(@iStatus, 6))

				# header has been detected, has address been detected too?

				if (SssSbitMath.bitRead(@iStatus, 7))

					# header is parsed, and frame is for us (or to be relayed)
					# we are reading frame-data

					# check first if end reached!
					if @oIncomingFrame.filled?

						# validate checksum and conclude command
						self.validateChecksum(iByte);

					elsif @oIncomingFrame.command.nil?

						# first data byte = command
						@oFletcher.addByte(iByte)
						@oIncomingFrame.command = iByte

					else

						#self.eventsStage2(iByte)

						@oFletcher.addByte(iByte)
						@oIncomingFrame.addByte(iByte)

					end # if done or doing data

				else

					# parsing header
					self.parseHeader(iByte, sIP);

				end # if header parsed or still at it

			else

				# scanning for header
				self.scanForHeader(iByte);

			end # if header found or looking for one

		end # loop each byte

		return mRead.length;
		
	end # parseIncoming


	def ping(iTarget)

		sData = '?'

		self.writeFramed(iTarget, sData)

	end # ping


	def pong(iTarget, iFrameID)

		sData = '@' << iFrameID

		self.writeFramed(iTarget, sData)

	end # pong


	def requestResend(iSender, iFrameID)

		puts 'TODO: SssSIOframeHandlerClass.requestResend()'

	end # requestResend


	# count <0x00>s looking for <0xFF>
	def scanForHeader(iByte)

		if (0x00 == iByte)

			# add space count
			@iCountSpace += 1;

		elsif (0xFF == iByte)

			# possibly found a header
			if (SBSerialSpaceLength <= @iCountSpace)

				# definitely a header
				@iStatus = SssSbitMath.bitSet(@iStatus, 6);
				# header not yet parsed
				@iStatus = SssSbitMath.bitClear(@iStatus, 7);
				# clear out multi-byte-mode stuff
				#self.clearMultiByteFlags();
				# reset frame-buffer pointer
			#	@iCountFrameBytes = 0;

				# instantiate new frame
				@oIncomingFrame = SssSserialFrame::new()

			end # if header or other data

			@iCountSpace = 0;

		else

			# mumbo jumbo, possibly debug information
			@iCountSpace = 0;

		end # if 0, 255 or something else

	end # scanForHeader


	# Full frame has been received, last two bytes are checksum
	def validateChecksum(iByte)

		# who is it from

		iSender = @oIncomingFrame.senderID
		iFrameID = @oIncomingFrame.frameID

		# first, second checksum or done?
		if @oIncomingFrame.checksumA.nil?

			# first checksum byte

			if (iByte != @oFletcher.checksum(SssSf16firstByte))

				# does not match

				self.requestResend(iSender, iFrameID)

				if (0 < SssSdebugMode)

					puts 'checksum failed from ' << iSender.to_s << ' frame: 0x' << iFrameID.to_s(16)

				end # if debugging

	# TODO: rewind if was loading to data buffer

				self.invalidate();

			else

				# so far so good
				@oIncomingFrame.checksumA= iByte

			end # if first checksum matches or not

		elsif @oIncomingFrame.checksumB.nil?

			# second checksum byte

			if (iByte != @oFletcher.checksum(SssSf16secondByte))

				self.requestResend(iSender, iFrameID);
	# TODO: rewind if was loading to data buffer

				if (0 < SssSdebugMode)

					puts 'invalid checksum 2 from ' << iSender.to_s << ' frame: 0x' << iFrameID.to_s(16)

				end # if debugging

			else

				# ok, check passed
				@oIncomingFrame.checksumB= iByte

				# at any rate, respond ack unless this is already an ack
				self.pong(iSender, iFrameID) if 64 != @oIncomingFrame.command

				# all ok, now depending on the command we need to do something
				self.executeFrame(@oIncomingFrame)

			end # if second checksum matches or not

			self.invalidate();

		else

			# this byte should be 0x0 --> first spacer
			self.invalidate();
			self.scanForHeader(iByte);

		end # if first, second checksum or done

	end # validateChecksum


	# envelope data into frames and send to serial bus
	# returns byte-count
	def writeFramed(iTo = 1, mData = nil, iFrameID = 0, mSubsequentFrameDataPrefix = nil, iFrom = SBSerialRaspberryPiID)

		# TODO: allow arrays too
		if (String != mData.class)
			return nil;
		end

		iCountSend = 0;

		if (0 == iFrameID)
			iFrameID = self.nextFrameID();
		end # if auto-frame-number

		# send over Ethernet or Serial
		bEthernet = self.isOnlineEthernet?(iTo)
		bSerial = self.isOnlineSerial?(iTo)

		if (!(bEthernet || bSerial))
			p 'can not reach ID: ' << iTo.to_s << ' over Ethernet nor Serial because it has not yet pinged me on either. Or some other reason'
			return nil
		end # if Ethernet or serial

		# how many frames will we need? more than one?
		iTotalFrames = 1;
		iLengthData = mData.length();
		if (SBSerialMaxDataLengthPerFrame < iLengthData)

			# more than one frame
# TODO: add prefix...
			if (mSubsequentFrameDataPrefix.nil?)

				iLengthPrefix = 0;

			else

				iLengthPrefix = mSubsequentFrameDataPrefix.length();

			end # if got prefix for subsequentFrames

			# total data minus first frame. divide by (max length minus prefix
			# multiply by 1.0 to cast as float
			fFrames = (1.0 * (iLengthData -  SBSerialMaxDataLengthPerFrame)) / (SBSerialMaxDataLengthPerFrame - iLengthPrefix);

			# all ints, so result is int
			iFrames = (iLengthData -  SBSerialMaxDataLengthPerFrame) / (SBSerialMaxDataLengthPerFrame - iLengthPrefix);

			if (0.0 < (fFrames - iFrames))
				iFrames += 1;
			end # if needs an extra frame

			iTotalFrames += iFrames;

		else

			iLengthPrefix = 0;

		end # if multiple frames or just one

		iPointer = 0;
		for iCountFrames in 0...iTotalFrames do

			# prepend space
			iLengthSpace = SBSerialSpaceLength;
			aFrame = Array.new(iLengthSpace, 0x0);

			# init fletcher 16 calculator
			SssSf16.reset();

			aFrame << 0xFF;

			SssSf16.addByte(iTo);
			aFrame << iTo;

			SssSf16.addByte(iFrom);
			aFrame << iFrom;

			SssSf16.addByte(iFrameID);
			aFrame << iFrameID;

			iDelta = iLengthData - iPointer;
			if (0 == iCountFrames || 0 == iLengthPrefix)

				# first frame or subsequent without prefix
				iLengthSub = (iDelta > SBSerialMaxDataLengthPerFrame) ? SBSerialMaxDataLengthPerFrame : iDelta;
				SssSf16.addByte(iLengthSub);
				aFrame << iLengthSub;

			else

				# subsequent frame with prefix
				iDelta += iLengthPrefix
				iLengthSub = (iDelta > SBSerialMaxDataLengthPerFrame) ? SBSerialMaxDataLengthPerFrame : iDelta
				SssSf16.addByte(iLengthSub)
				aFrame << iLengthSub

			# there seems to be different treatment on OSX (irb 0.9.5) and Debian (0.9.6) -Ruby: on OSX iByte is the byte-value while in Debian it's a String
				mTest = mSubsequentFrameDataPrefix[0]
				if String == mTest.class

					# debian
					for j in 0...iLengthPrefix do

						iByte = mSubsequentFrameDataPrefix[j].ord

						SssSf16.addByte(iByte)
						aFrame << iByte

					end # for loop data portion

				else

					# osx
					for j in 0...iLengthPrefix do

						iByte = mSubsequentFrameDataPrefix[j]

						SssSf16.addByte(iByte)
						aFrame << iByte

					end # for loop data portion

				end # if on debian or darwin

				iLengthSub -= iLengthPrefix

			end # if first frame or subsequent with prefix

			# there seems to be different treatment on OSX (irb 0.9.5) and Debian (0.9.6) -Ruby: on OSX iByte is the byte-value while in Debian it's a String
			mTest = mData[0]
			if String == mTest.class

				# debian
				for j in 0...iLengthSub do

					iByte = mData[iPointer].ord
					iPointer += 1

					SssSf16.addByte(iByte)
					aFrame << iByte

				end # for loop data portion

			else

				# osx
				for j in 0...iLengthSub do

					iByte = mData[iPointer]
					iPointer += 1

					SssSf16.addByte(iByte)
					aFrame << iByte

				end # for loop data portion

			end # if on debian or darwin

			# add checksum
			aFrame << SssSf16.checksum(SssSf16firstByte);
			aFrame << SssSf16.checksum(SssSf16secondByte);

			# send over Ethernet or Serial
			if bEthernet
				$oSssSapp.oEthernet.sendTo(iTo, aFrame.drop(iLengthSpace))
			elsif bSerial
p 'about to write to serial target: ' << iTo.to_s
				$oSssSapp.oSerial.writeRawBytes(aFrame)
p 'wrote to serial frame: 0x' << iFrameID.to_s(16)
			end # if Ethernet and/or serial

			iCountSend += aFrame.length();

			# store a copy in history (only what is unique)
			self.historyAddFrame(iFrameID, aFrame.drop(iLengthSpace + 1))

			# get next frame ID
			iFrameID = self.nextFrameID();

			sleep(@iMySerialID * @@fDelayBetweenFrames)

		end # for loop frames

		return iCountSend

	end # writeFramed
	public :writeFramed


	# write a string of bytes over serial without modification or envelopement
	# returns byte-count (mData.bytesize)
	def writeRawBytes(mData = nil)

		if (self.isOnlineEthernet?(SBSerialBroadcastID))
			iCountSent = $oSssSapp.oEthernet.writeRawBytes(mData)
		elsif (self.isOnlineSerial?(SBSerialBroadcastID))
			iCountSent = $oSssSapp.oSerial.writeRawBytes(mData)
		else
			p ' can not send raw bytes to either Ethernet nor Serial'
			return nil
		end # if Ethernet or serial or neither

		sleep(@iMySerialID * @@fDelayBetweenFrames)

		iCountSent

	end # writeRawBytes
	public :writeRawBytes


	# write contents of a file byte-by-byte as-is
	# returns byte-count
	def writeRawFile(sPathFile = nil)

		if (self.isOnlineEthernet?(SBSerialBroadcastID))
			iCountSent = $oSssSapp.oEthernet.writeRawFile(sPathFile)
		elsif (self.isOnlineSerial?(SBSerialBroadcastID))
			iCountSent = $oSssSapp.oSerial.writeRawFile(sPathFile)
		else
			p 'can not send raw file to either Ethernet nor Serial'
			return nil
		end # if Ethernet or serial or neither

		sleep(@iMySerialID * @@fDelayBetweenFrames)

		iCountSent;

	end # writeRawFile
	public :writeRawFile


	def executeFrame(oFrame)

		# analyze command
		# the first command byte
		iCommand = oFrame.command
		# who is it from
		iSender = oFrame.senderID
		iFrameID = oFrame.frameID

		iFirstDataByte = oFrame.resetPointer().nextByte()

		if (0x29 == iCommand)

			# - 41 - ) - set debug port

			# not required

		elsif (0x2A == iCommand)

			# - 42 - * - set RasPi port

			# not required

		elsif (0x2F == iCommand)

			# - 47 - / - Set Serial Bus Port

			# not required

		elsif (0x3C == iCommand)

			# - 60 - < - Request ASV

			# not required

		elsif (0x3D == iCommand)

			# - 61 - = - Response ASV
			# TODO: probably only RasPi is interested in this

		elsif (0x3E == iCommand)

			# - 62 - > - print debug info onto debug port

			# not required

		elsif (0x3F == iCommand)

			# - 63 - ? - PING

			# mark sender as not busy
			@iStatus = SssSbitMath.bitClear(@iStatus, iSender);
			# also mark for POSIX clients
			self.markOnline(iSender, oFrame.senderIP)

			# respond delayed according to our ID to avoid a pile-up
	# TODO: maybe we should not use delay() especially if we are currently in a race
			sleep(@iMySerialID * @@fDelayBetweenFrames)

			self.pong(iSender, iFrameID);

		elsif (0x40 == iCommand)

			# - 64 - @ - PONG

			#@aLatency[iSender] = millis() - @aLatency[iSender];

			if (0 < SssSdebugMode)

				#puts 'latency of ID ' << iSender << ' is ' << @aLatency[iSender];

			end # if debugging

			# for subclasses that implement a history
			self.historyRemoveFrame(iFirstDataByte)

		elsif (0x44 == iCommand)

			# - 68 - D - set debug mode

			# not required

		elsif (0x45 == iCommand)

			# - 69 - E - upload to EEPROM

			# not required

		elsif (0x52 == iCommand)

			# - 82 - R repeat frame

			self.historyResendFrame(iFirstDataByte)

		elsif (0x53 == iCommand)

			# - 83 - S - Stop Stopwatch
			$oSssSapp.tellSkyTabStop(iFirstDataByte)

		elsif (0x5C == iCommand)

			# - 92 - \ - Set Date

			# not required

		elsif (0x5D == iCommand)

			# - 93 - ] - set FDD StopWatch IDs

			# not required

		elsif (0x64 == iCommand)

			# - 100 - d - Duration

			# expecting 4 bytes with duration in milliseconds
			# followed by 1 byte with the BIKE ID
			if (5 == oFrame.data.count)

				ulDuration = iFirstDataByte << 24
				ulDuration += oFrame.nextByte() << 16
				ulDuration += oFrame.nextByte() << 8
				ulDuration += oFrame.nextByte()

				iBike = oFrame.nextByte()

				# tell database about the change
				$oSssSapp.tellSkyTabDurationForBIKE(ulDuration, iBike)

			else

				puts 'ERROR: duration Frame with incorrect length. Should be 5 but is ' << oFrame.data.count.to_s

			end # if data count correct or not

		elsif (0x65 == iCommand)

			# - 101 - e - dump EEPROM

			# not required

		elsif (0x66 == iCommand)

			# - 102 - f - EEPROM dump frame

			# let event manager know what to do on next cycle
			@oEventManager.responseDumpEEPROM(oFrame)

		elsif (0x72 == iCommand)

			# - 114 -  r - reset stopwatch
			$oSssSapp.tellSkyTabReset(iFirstDataByte)

		elsif (0x73 == iCommand)

			# - 115 -  s - start stopwatch
			$oSssSapp.tellSkyTabStart(iFirstDataByte)

		elsif (0x74 == iCommand)

			# - 116 - t - time

			# not required

		elsif (0x7A == iCommand)

			# - 122 - z - change baud to

			# not required

		elsif (0x7B == iCommand)

			# - 123 - { - Request Checksum of EEPROM range

			# not required

		elsif (0x7D == iCommand)

			# - 125 - } - Response Checksum of EEPROM

			# let the event manager know
			@oEventManager.responseChecksumEEPROM(oFrame)

		else

			# give subclasses a chance to know this command
			if (!self.executeUnknownFrame(oFrame))

				# unknown command -> ignore silently unless debug mode is set
				if (0 < SssSdebugMode)

					puts 'unknown command (0x' << iCommand.to_s(16) << ') from ' << iSender.to_s;

				end # if debugging

			end # if subclass does not know command either

		end # switch command

	end # executeFrame
	protected :executeFrame


	# hook for subclasses to expand on commands
	def executeUnknownFrame(oFrame)
		NO
	end # executeUnknownFrame

  public

	# for subclasses to implement frame history
	def historyAddFrame(iFrameID, aFrame)

		sIndex = 'id' << iFrameID.to_s
		@hFrameHistory[sIndex] = aFrame

		sIndex = nil

		self

	end # historyAddFrame


	# for subclasses to implement frame history
	def historyRemoveFrame(iFrameID)

		sIndex = 'id' << iFrameID.to_s
		@hFrameHistory[sIndex] = nil

		sIndex = nil

		self

	end # historyRemoveFrame


	# for subclasses to implement frame history
	def historyResendFrame(iFrameID)

		sIndex = 'id' << iFrameID.to_s
		return nil if @hFrameHistory[sIndex].nil?

		# prepend space
		aFrame = Array.new(SBSerialSpaceLength, 0x0)
		aFrame << 0xFF
		aFrame += @hFrameHistory[sIndex]

		# send over Ethernet or Serial?
		iTo = @hFrameHistory[sIndex][0].to_i
		if (!SssSethernet.nil? && SssSethernet.isOnline(iTo))
			SssSethernet.sendTo(iTo, aFrame.drop(SBSerialSpaceLength))
		elsif (!SssSserial.nil? && SssSserial.isOnline(iTo))
			SssSserial.send(aFrame)
		end

		aFrame.count

	end # historyResendFrame

end # SssSIOframeHandlerClass
