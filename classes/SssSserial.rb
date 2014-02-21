require 'rubygems';
require 'serialport';
require 'SssSapp.rb'
require 'SssSfletcher16.rb'
require 'SssSserialFrame.rb'
require 'SssSEventManager.rb'
require 'SssSIOframeHandler.rb'

##
# Listen to serial connected to SBAMM and notifies SkyTab<br>
# Also message SBAMM and SBAMFDDDs
# Instantiated and controlled by SssSapp

class SssSserialClass

  protected

	@mPort;

 public

	@mPortOptions; attr_accessor :mPortOptions

	@oPort; attr_reader :oPort


	# create a serial connection on mPort with options<br>
	# raises on failure<br>
	# mPort may be a natural number (0 => com1:) or a POSIX path ('/dev/ttyS0')
	def initialize(mPort = 0, *options)

		@mPort = mPort;
		# TODO: @mPortOptions = options;
		@mPortOptions = {
				'baud' => SssSapp.get(:serialBaud, 115200),
				'data_bits' => SssSapp.get(:serialDataBits, 8),
				'stop_bits' => SssSapp.get(:serialStopBits, 1),
				'parity' => SssSapp.get(:serialParity, SerialPort::NONE)
			};

		@oPort = nil;

		self.connect();

		# make sure broadcast ID is marked online
		# TODO: get serial broadcast ID
		$oSssSapp.oIOframeHandler.markOnline(SBSerialBroadcastID)

	end # initialize


	# check if we have bytes comming in on serial<br>
	# if not returns nil otherwise the count of bytes received after having
	# filtered and loaded the bytes to the correct buffer
	def checkIncoming()

		mRead = self.readSerial();
		return nil if mRead.nil?

		return $oSssSapp.oIOframeHandler.parseIncoming(mRead)

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


	def disconnect()

		puts 'OK: disconnecting serial'

		@oPort.close() if self.connected?

		@oPort = nil;

	end # disconnect


	def disconnected?()

		return @oPort.nil?

	end # disconnected?

  protected

	# read nonblocking from serial port. Returns nil or a string of bytes<br>
	# called by #checkIncoming()
	def readSerial()

		# if not connected
		return nil if self.disconnected?

		begin

			sRead = @oPort.read_nonblock(@@bufferMaxLen);

		rescue Exception => e #IO::WaitReadable # this is raised when there's no data in the stream
p e if ![ EOFError, Errno::EAGAIN ].member? e.class
			# don't wait for data
			return nil;

		end

		return sRead;

	end # readSerial


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

end # SssSserialClass
