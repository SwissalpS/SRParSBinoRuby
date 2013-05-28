class SssSserialFrame

	@command = nil; attr_accessor :command
	@dataLength = nil; attr_accessor :dataLength
	@frameID = nil; attr_accessor :frameID
	@senderID = nil; attr_accessor :senderID
	@targetID = nil; attr_accessor :targetID
	@data = nil; attr_reader :data

	@checksumA = nil; attr_accessor :checksumA
	@checksumB = nil; attr_accessor :checksumB

	@pointer = 0; attr_reader :pointer

	def initialize(iTarget = nil, iSender = nil, iFrame = nil, iCommand = nil, iLen = nil, aData = nil, iChecksumA = nil, iChecksumB = nil)

		@command = iCommand
		@dataLength = iLen
		@frameID = iFrame
		@senderID = iSender
		@targetID = iTarget
		@data = (aData.nil?) ? [] : aData

		@checksumA = iChecksumA
		@checksumB = iChecksumB

		self.resetPointer()

		self

	end # initialize


	def addByte(iByte)

		@data << (iByte & 0xFF)

	end # addByte


	# is everything here apart from checksum?
	def filled?()

		# not possible if any is nil
		return nil if [@targetID, @senderID, @frameID, @dataLength, @command].member? nil

		# not filled if dataLength and data.count don't match (dataLength -1 because command is not in data)
		return nil if ((@dataLength -1) != @data.count)

		return YES

	end # filled?


	# returns the next byte or nil if no more bytes
	def nextByte()

		return nil if !self.filled?

		@pointer += 1

		# dataLength -1 because command is not in data!
		return nil if ((@dataLength - 1) <= @pointer)

		@data[@pointer]

	end # nextByte


	def recalculateChecksum()

		return nil if !self.filled?

		oFletcher = SssSfletcher16Class::new()

		oFletcher.addByte(@targetID)
		oFletcher.addByte(@senderID)
		oFletcher.addByte(@frameID)
		oFletcher.addByte(@dataLength)
		oFletcher.addByte(@command)

		@data.each do |iByte|
			oFletcher.addByte(iByte)
		end # loop each data-byte

		@checksumA, @checksumB = oFletcher.aChecksum

		oFletcher = nil

		[@checksumA, @checksumB]

	end # recalculateChecksum


	def resetPointer()

		@pointer = -1

		self

	end # resetPointer


	# output full frame (or data only) as array
	def to_a(bEnveloped = true)

		aOut = []

		if bEnveloped
		  aOut.concat [0xFF, @targetID, @senderID, @frameID, @dataLength, @command]
		end

		aOut.concat @data

		aOut.concat [@checksumA, @checksumB] if bEnveloped

	end # to_a

	# output full frame (or only data) as string
	def to_s(bEnveloped = true)

	  sOut = ''

	  if bEnveloped

		sOut << (0xFF).chr << @targetID.chr << @senderID.chr << @frameID.chr
		sOut << @dataLength.chr << @command.chr

	  end # if enveloped

	  @data.each { |iByte| sOut << iByte.chr }

	  if bEnveloped

		sOut << @checksumA.chr << @checksumB.chr

	  end # if enveloped

	  sOut

	end # to_s

end # SssSserialFrame
