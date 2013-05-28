require 'rubygems';
require 'serialport';
require 'SssSfletcher16.rb'
require 'SssSserialFrame.rb'
require 'SssSEventManager.rb'

YES = true if !defined? YES
NO = false if !defined? NO

SssSdebugMode = 7 if !defined? SssSdebugMode

SBSerialSpaceLength = 29; # :doc:
SBSerialMaxFrameLength = 35;
SBSerialMaxDataLengthPerFrame = 28;
SBSerialBroadcastID = 254;

##
# Listen to serial connected to SBAMM and notifies SkyTab<br>
# Also message SBAMM and SBAMFDDDs
# Instantiated and controlled by SssSapp

class SssSserialClass

  private

	@@bufferMaxLen = SBSerialMaxFrameLength + SBSerialSpaceLength;

	@@fDelayBetweenFrames = 0.004;

  protected

#	@aFrameBuffer; #[SBSerialMaxFrameLength];

	@hFrameHistory = {}; attr_reader :hFrameHistory #[222];

#	@iCountFrameBytes = 0;

#	@iCountFrameDataBytes = 0;

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

	@mPort;

 public

	@mPortOptions; attr_accessor :mPortOptions

	# for incoming traffic we use a seperate fletcher instance to avaid colusion
	@oFletcher;

	@oPort; attr_reader :oPort

	@oIncomingFrame; attr_reader :oIncomingFrame


	# create a serial connection on mPort with options<br>
	# raises on failure<br>
	# mPort may be a natural number (0 => com1:) or a POSIX path ('/dev/ttyS0')
	def initialize(mPort = 0, *options)

	#	@aFrameBuffer = Array.new(SBSerialMaxFrameLength);

		@hFrameHistory = {} #Array.new(222) { Array.new(SBSerialMaxFrameLength); }
	#	@iCountFrameBytes = 0;
	#	@iCountFrameDataBytes = 0;
		@iCountSpace = 0;

		@iMySerialID = 4;

		# frame ids 7...222
		@iNextFrameID = 7 + rand(215);

		@iStatus = 0;

		@mPort = mPort;
		# TODO: @mPortOptions = options;
		@mPortOptions = {
				'baud' => SssSapp.get(:serialBaud, 115200),
				'data_bits' => SssSapp.get(:serialDataBits, 8),
				'stop_bits' => SssSapp.get(:serialStopBits, 1),
				'parity' => SssSapp.get(:serialParity, SerialPort::NONE)
			};

		@oFletcher = SssSfletcher16Class.new()

		@oIncomingFrame = nil

		@oEventManager = SssSEventManager.new()
		#@oEventManager.addInitialSyncEvents()

		@oPort = nil;

		self.connect();

	end # initialize


	# set n-th bit of iHash to 0
	def self.bitClear(iHash = 0, iShift = 0)

		iShift = iShift.abs

		# is set?
		if (SssSserialClass::bitRead(iHash, iShift))

			# it is, safe to simply subtract
			return (iHash - (1 << iShift));

		end # if set

		# not set, so safe to simply return given value
		return iHash;

	end # bitClear
	# set n-th bit of iHash to 0
	def bitClear(iHash = 0, iShift = 0) # :nodoc:

		return SssSserialClass::bitClear(iHash, iShift);

	end # bitClear

	# set n-th bit of iHash to 1
	def self.bitSet(iHash = 0, iShift = 0)

		iShift = iShift.abs

		# already set?
		if (SssSserialClass::bitRead(iHash, iShift))

			return iHash;

		end # if already set

		# not yet set, so safe to simply add
		return (iHash + (1 << iShift));

	end # bitSet
	# set n-th bit of iHash to 1
	def bitSet(iHash = 0, iShift = 0) # :nodoc:

		return SssSserialClass::bitSet(iHash, iShift);

	end # bitSet

	# return n-th bit of iHash
	def self.bitRead(iHash = 0, iShift = 0)

		iShift = iShift.abs

		return (1 == ((iHash >> iShift) & 1)) ? YES : NO;

	end # bitRead
	def bitRead(iHash = 0, iShift = 0) # :nodoc:

		return SssSserialClass::bitRead(iHash, iShift);

	end # bitRead

	# set n-th bit of iHash to bValue
	def self.bitWrite(iHash = 0, iShift = 0, bValue = YES)

		bValue = bValue.abs
		bValue = YES if (1 < bValue)

		# if set
		return SssSserialClass::bitSet(iHash, iShift) if (bValue)

		return SssSserialClass::bitClear(iHash, iShift);

	end # bitWrite
	# set n-th bit of iHash to bValue
	def bitWrite(iHash = 0, iShift = 0, bValue = YES) # :nodoc:

		return SssSserialClass::bitWrite(iHash, iShift, bValue);

	end # bitWrite


	# check if we have bytes comming in on serial<br>
	# if not returns nil otherwise the count of bytes received after having
	# filtered and loaded the bytes to the correct buffer
	def checkIncoming()

		mRead = self.readSerial();
		return nil if mRead.nil?

		self.debugIncoming(mRead);

		mRead.each_byte() do |iByte|

			if (self.bitRead(@iStatus, 6))

				# header has been detected, has address been detected too?

				if (self.bitRead(@iStatus, 7))

					# header is parsed, and frame is for us (or to be relayed)
					# we are reading frame-data

					# check first if end reached!
				#	if (0 == @iCountFrameDataBytes)
					if @oIncomingFrame.filled?

						# validate checksum and conclude command
						self.validateChecksum(iByte);

					elsif @oIncomingFrame.command.nil?

						# first data byte = command
						@oFletcher.addByte(iByte)

						@oIncomingFrame.command = iByte

					else

						#self.eventsStage2(iByte)

					#	@iCountFrameDataBytes -= 1

					#	@aFrameBuffer[iCountFrameBytes] = iByte
						@oFletcher.addByte(iByte)

						@oIncomingFrame.addByte(iByte)

					#	iCountFrameBytes += 1

					end # if done or doing data

				else

					# parsing header
					self.parseHeader(iByte);

				end # if header parsed or still at it

			else

				# scanning for header
				self.scanForHeader(iByte);

			end # if header found or looking for one

		end # loop each byte

		return mRead.length;

	end # checkIncoming


	# called by ::new()<br>
	# raises on error causing SssSapp to exit
	def connect()

		# if already connected
		return nil if self.connected?

		# TODO: start settings synchronizer, event manager? We need to read or at least write settings to Arduinos and provide information to SkyTab
		puts 'TODO: settings synchronizer'

		begin

			@oPort = SerialPort.new(@mPort, @mPortOptions)

			# seems to work better than only using read_nonblock
			# set the timeout to a negative number is essentially read_nonblock
#			@oPort.read_timeout = -3

		rescue Exception => e

			self.disconnect()
p 'error when connecting to ' << @mPort.to_s << ' options: ' << @mPortOptions.to_s
			raise e

		ensure;

		end

	end # connect


	def connected?()

		return !@oPort.nil?

	end # connected?


	# destroy this object cleanly
	def dealloc()

		self.disconnect();

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

	def disconnect()

		puts 'OK: disconnecting serial'

		@oPort.close() if self.connected?

		@oPort = nil;

	end # disconnect


	def disconnected?()

		return @oPort.nil?

	end # disconnected?

  protected

	# invalidate incoming frame
	def invalidate()

		@iCountSpace = 0;
	#	@iCountFrameBytes = 0;
		# not for us
		@iStatus = self.bitClear(@iStatus, 5);
		# header not detected -> look for next header
		@iStatus = self.bitClear(@iStatus, 6);
		# header not parsed
		@iStatus = self.bitClear(@iStatus, 7);

		@oIncomingFrame.dealloc()
		@oIncomingFrame = nil;

	end # invalidate


	# Returns the next frame-id to use
	def nextFrameID()

		@iNextFrameID += 1

		# if rollover
		@iNextFrameID = 7 if (222 < @iNextFrameID)

		return @iNextFrameID

	end # nextFrameID


	# Check the first four bytes after <0xFF> and determine if frame is for us
	def parseHeader(iByte)

	#	if (0 == @iCountFrameBytes)
		if @oIncomingFrame.targetID.nil?

			# target ID

			if (iMySerialID == iByte || SBSerialBroadcastID == iByte)

				# this is for us
				@iStatus = self.bitSet(@iStatus, 5);
				# we are busy?
				#@iStatus = self.bitSet(@iStatus, iMySerialID);

				@oFletcher.reset();
			#	@aFrameBuffer[@iCountFrameBytes] = iByte;
				@oFletcher.addByte(iByte);
				@oIncomingFrame.targetID= iByte

			#	@iCountFrameBytes += 1;

			else

				# not for us --> look for next frame
				self.invalidate();

			end # if for this Arduino, another or error

	#	elsif (1 == @iCountFrameBytes)
		elsif @oIncomingFrame.senderID.nil?

			# sender ID

			if (@iMySerialID > iByte)

				# valid sender ID

			#	@aFrameBuffer[@iCountFrameBytes] = iByte;
				@oFletcher.addByte(iByte)
				@oIncomingFrame.senderID= iByte

			#	@iCountFrameBytes += 1

			else

				# invalid sender ID --> look for next frame
	# TODO: debug
				self.invalidate()

			end # valid sender or not

	#	elsif (2 == @iCountFrameBytes)
		elsif @oIncomingFrame.frameID.nil?

			# frame ID

		#	@aFrameBuffer[@iCountFrameBytes] = iByte;
			@oFletcher.addByte(iByte)
			@oIncomingFrame.frameID= iByte

		#	@iCountFrameBytes += 1

	#	elsif (3 == @iCountFrameBytes)
		elsif @oIncomingFrame.dataLength.nil?

			# data length

		#	@iCountFrameDataBytes = iByte

		#	@aFrameBuffer[@iCountFrameBytes] = iByte;
			@oFletcher.addByte(iByte)
			@oIncomingFrame.dataLength= iByte

		#	@iCountFrameBytes += 1

			# header is parsed now
			@iStatus = self.bitSet(@iStatus, 7);

		end # if target ID, sender ID, frame ID or data length

	end # parseHeader


	def ping(iTarget)

		sData = '?'

		self.writeFramed(iTarget, sData)

	end # ping


	def pong(iTarget, iFrameID)

		sData = '@' << iFrameID

		self.writeFramed(iTarget, sData)

	end # pong


	# read nonblocking from serial port. Returns nil or a string of bytes<br>
	# called by #checkIncoming()
	def readSerial()

		# if not connected
		return nil if self.disconnected?

		begin

			sRead = @oPort.read_nonblock(@@bufferMaxLen);

		rescue Exception => e #IO::WaitReadable # this is raised when there's no data in the stream
p e if EOFError != e.class
			# don't wait for data
			return nil;

		end

		return sRead;

	end # readSerial


	def requestResend(iSender, iFrameID)

		puts 'TODO: SssSserial.requestResend()'

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
				@iStatus = self.bitSet(@iStatus, 6);
				# header not yet parsed
				@iStatus = self.bitClear(@iStatus, 7);
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
	#	iSender = self.incomingSenderID();
	#	iFrameID = self.incomingFrameID();
	#	iLengthIncomming = self.incomingDataLength()

		iSender = @oIncomingFrame.senderID
		iFrameID = @oIncomingFrame.frameID

		# first, second checksum or done?
	#	if ((iLengthIncomming + 4) == @iCountFrameBytes)
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

			#	@iCountFrameBytes += 1;

			end # if first checksum matches or not

	#	elsif ((iLengthIncomming + 5) == @iCountFrameBytes)
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
	def writeFramed(iTo = 1, mData = nil, iFrameID = 0, mSubsequentFrameDataPrefix = nil, iFrom = 4)

		# TODO: allow arrays too
		if (String != mData.class)
			return nil;
		end

		iCountSend = 0;

		if (0 == iFrameID)
			iFrameID = self.nextFrameID();
		end # if auto-frame-number

		# how many frames will we need? more than one?
		iTotalFrames = 1;
		iLengthData = mData.length();
		if (SBSerialMaxDataLengthPerFrame < iLengthData)

			# more than one frame

			if (nil == mSubsequentFrameDataPrefix)

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

			else

				# subsequent frame with prefix

				iDelta -= iLengthPrefix;

			end # if first frame or subsequent with prefix

			iLengthSub = (iDelta > SBSerialMaxDataLengthPerFrame) ? SBSerialMaxDataLengthPerFrame : iDelta;
			SssSf16.addByte(iLengthSub);
			aFrame << iLengthSub;

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

			# now write to serial
			aFrame.each { |iByte| @oPort.putc(iByte); }
			iCountSend += aFrame.length();

			# store a copy in history (only what is unique)
			self.historyAddFrame(iFrameID, aFrame.drop(iLengthSpace + 1))
			#@hFrameHistory[iFrameID] = aFrame.drop(iLengthSpace + 1);

			# get next frame ID
			iFrameID = self.nextFrameID();

		end # for loop frames

		return iCountSend

	end # writeFramed
	public :writeFramed

	# write a string of bytes over serial without modification or envelopement
	# returns byte-count (mData.bytesize)
	def writeRawBytes(mData = nil)

		if (self.disconnected?)
			return nil;
		end # if not connected

		# TODO: allow arrays too
		if (String != mData.class)
			return nil;
		end # if invalid dada format

		iCountSent = 0;

		mData.each_byte do |iByte|

			@oPort.putc(iByte);

			iCountSent += 1;

		end # loop each byte

		iCountSent;

	end # writeRawBytes
	public :writeRawBytes

	# write contents of a file byte-by-byte as-is
	# returns byte-count
	def writeRawFile(sPathFile = nil)

		if nil == sPathFile
			return nil;
		end

		iCount = 0;

		begin

			oF = File.new(sPathFile);
			while(nil != (iChar = oF.getbyte())) do

puts 'byte # 0x' << "%02X" % iCount << ' hex: 0x' << "%02X" % iChar << ' binary: ' << iChar.to_s(2);

				@oPort.putc(iChar);

				iCount += 1;

			end

		rescue Exception => e

			# anything ?

		ensure

			if (nil != oF)
				oF.close();
			end

		end

		return iCount;

	end # writeRawFile
	public :writeRawFile

	def executeFrame(oFrame)

		# analyze command
		# the first command byte
		iCommand = oFrame.command #self.incomingCommand();
		# who is it from
		iSender = oFrame.senderID #self.incomingSenderID();
		iFrameID = oFrame.frameID #self.incomingFrameID();

		iFirstDataByte = oFrame.resetPointer().nextByte() #@aFrameBuffer[iDataPos];

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
			@iStatus = self.bitClear(@iStatus, iSender);

			# respond delayed according to our ID to avoid a pile-up
	# TODO: maybe we should not use delay() especially if we are currently in a race
			sleep(@iMySerialID * @@fDelayBetweenFrames);

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
			SssSapp.tellSkyTabStop(iFirstDataByte)

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
				SssSapp.tellSkyTabDurationForBIKE(ulDuration, iBike)

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
			SssSapp.tellSkyTabReset(iFirstDataByte)

		elsif (0x73 == iCommand)

			# - 115 -  s - start stopwatch
			SssSapp.tellSkyTabStart(iFirstDataByte)

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

		# now send the frame
		aFrame.each { |iByte| @oPort.putc(iByte) }

		aFrame.count

	end # historyResendFrame

end # SssSserialClass
