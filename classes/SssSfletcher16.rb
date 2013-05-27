
YES = true if !defined? YES
NO = false if !defined? NO

SssSf16firstByte = 0;
SssSf16secondByte = 1;


# this class takes care of calculating checksums
# if you only need one instance at a time, use the shared instance
# SssSf16 is a Global access to it.
# This checksum method is somewhat sensitive to swapped bytes.
class SssSfletcher16Class


	# holds the 2 checksum elements
	@aChecksum = [ 0xFF, 0xFF ]; attr_reader :aChecksum


	def initialize()

		self.reset();

	end # initialize


	# start with a new calculation
	def reset()

		@aChecksum = [ 0xFF, 0xFF ];

	end # reset


	# add a byte to the checksums
	def addByte(iByte)

		iSum1 = @aChecksum[SssSf16firstByte];
		iSum2 = @aChecksum[SssSf16secondByte];

		# add the byte to sum1 and add sum1 to sum2
		iSum1 += iByte;
		iSum2 += iSum1;

		# make sure neither is greater than 255 and add upper byte to lower
		iSum1 = ((iSum1 & 0xFF) + (iSum1 >> 8)) & 0xFF;
		iSum2 = ((iSum2 & 0xFF) + (iSum2 >> 8)) & 0xFF;

		@aChecksum[SssSf16firstByte] = iSum1;
		@aChecksum[SssSf16secondByte] = iSum2;

	end # addByte


	# fetch the current value of individual checksum.
	# iFirstOrSecond can be either 0 or 1 for first and second respectively
	def checksum(iFirstOrSecond)

		# if invalid index
		return 0xFF if (1 < iFirstOrSecond)

		return @aChecksum[iFirstOrSecond];

	end # checksum


	# if you only need one at a time, this one will do
	def self.sharedInstance()

		@@_sharedInstance ||= SssSfletcher16Class.new();
		return @@_sharedInstance;

	end # sharedInstance

end # SssSfletcher16Class

# :doc: if you only need one at a time, this one will do
SssSf16 = SssSfletcher16Class::sharedInstance()
