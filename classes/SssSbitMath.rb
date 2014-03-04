##
# A collection of bitwise operations

class SssSbitMathClass

 public

	def initialize()

		self

	end # initialize


	# set n-th bit of iHash to 0
	def self.bitClear(iHash = 0, iShift = 0)

		iShift = iShift.abs

		# is set?
		if (SssSbitMathClass::bitRead(iHash, iShift))

			# it is, safe to simply subtract
			return (iHash - (1 << iShift));

		end # if set

		# not set, so safe to simply return given value
		return iHash;

	end # bitClear
	# set n-th bit of iHash to 0
	def bitClear(iHash = 0, iShift = 0) # :nodoc:

		return SssSbitMathClass::bitClear(iHash, iShift);

	end # bitClear

	# set n-th bit of iHash to 1
	def self.bitSet(iHash = 0, iShift = 0)

		iShift = iShift.abs

		# already set?
		if (SssSbitMathClass::bitRead(iHash, iShift))

			return iHash;

		end # if already set

		# not yet set, so safe to simply add
		return (iHash + (1 << iShift));

	end # bitSet
	# set n-th bit of iHash to 1
	def bitSet(iHash = 0, iShift = 0) # :nodoc:

		return SssSbitMathClass::bitSet(iHash, iShift);

	end # bitSet

	# return n-th bit of iHash
	def self.bitRead(iHash = 0, iShift = 0)

		iShift = iShift.abs

		return (1 == ((iHash >> iShift) & 1)) ? YES : NO;

	end # bitRead
	def bitRead(iHash = 0, iShift = 0) # :nodoc:

		return SssSbitMathClass::bitRead(iHash, iShift);

	end # bitRead

	# set n-th bit of iHash to bValue
	def self.bitWrite(iHash = 0, iShift = 0, bValue = YES)

		bValue = bValue.abs
		bValue = YES if (1 < bValue)

		# if set
		return SssSbitMathClass::bitSet(iHash, iShift) if (bValue)

		return SssSbitMathClass::bitClear(iHash, iShift);

	end # bitWrite
	# set n-th bit of iHash to bValue
	def bitWrite(iHash = 0, iShift = 0, bValue = YES) # :nodoc:

		return SssSbitMathClass::bitWrite(iHash, iShift, bValue);

	end # bitWrite


	# destroy this object cleanly
	def dealloc()

		nil;

	end # dealloc


	def self.ipArrayToULong(aubIP)

		ulIPtemp = aubIP[0];
		ulIP = ulIPtemp << 24;
		ulIPtemp = aubIP[1];
		ulIP += ulIPtemp << 16;
		ulIPtemp = aubIP[2];
		ulIP += ulIPtemp << 8;
		ulIPtemp = aubIP[3];
		ulIP += ulIPtemp;

		return ulIP;

	end # ipArrayToULong


	def ipArrayToULong(aubIP)

		return SssSbitMathClass::ipArrayToULong(aubIP)

	end # ipArrayToULong

end # SssSbitMathClass

SssSbitMath = SssSbitMathClass.new

YES = true if !defined? YES
NO = false if !defined? NO
