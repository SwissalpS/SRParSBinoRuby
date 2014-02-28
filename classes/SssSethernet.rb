require 'socket'
require 'SssSapp.rb'
require 'SssSEventManager.rb'
require 'SssSIOframeHandler.rb'
require 'eventmachine'


module SssSEMServer

	def post_init
		puts 'client connected'
	end # post_init

	def receive_data(data)
		puts data
		#send_data('haha')
	end # receive_data
end # SssSEMServer

EventMachine::run do

	EventMachine::open_datagram_socket('192.168.123.40', 12345, SssSEMServer)
	EventMachine::add_periodic_timer(1) { puts 'periodic timer' }

end # EventMachine::run


##
# Listen to Ethernet messages and notifies SkyTab<br>
# Also message SBAMM and SBAMFDDDs
# Instantiated and controlled by SssSapp
class SssSethernetClass

  protected

	@oUDPsocketBroadcast = nil;
	@oUDPsocketToMe = nil;

 public

	@mPortOptions; attr_accessor :mPortOptions

	# raises on failure<br>
	def initialize(*options)

		# not all ruby versions support ip_address_list
		begin

			sIPdefault = (Socket.methods.member? :ip_address_list) ? Socket.ip_address_list.detect{ |intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private? }.ip_address() : SBethernetDefaultIP
		rescue
			sIPdefault = SBethernetDefaultIP
		end # try catch my own IP address

		# TODO: @mPortOptions = options;
		@mPortOptions = {
				:ethernetIP => $oSssSapp.get(:ethernetIP, sIPdefault),
				:ethernetIPbroadcast => $oSssSapp.get(:ethernetIPbroadcast, SBethernetDefaultIPbroadcast),
				:ethernetIPgateway => $oSssSapp.get(:ethernetIPgateway, SBethernetDefaultIPgateway),
				:ethernetIPsubnet => $oSssSapp.get(:ethernetIPsubnet, SBethernetDefaultIPsubnet),
				:ethernetPort => $oSssSapp.get(:ethernetPort, SBethernetDefaultPort)
			};

		@oPort = nil;

		self.connect();

		# make sure we can broadcast as long as we are connected
		# TODO: get serial broadcast ID
		$oSssSapp.oIOframeHandler.markOnline(SBSerialBroadcastID, @mPortOptions[:ethernetIPbroadcast])

	end # initialize


	def broadcastTo(sIP = nil, sData)

		if (self.disconnected?)
			return nil;
		end # if not connected

		sIP = @mPortOptions[:ethernetIPbroadcast] if sIP.nil?
		iPort = @mPortOptions[:ethernetPort]

		oUDPSock = UDPSocket.new
		oUDPSock.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
		oUDPSock.send(sData, 0, sIP, iPort)
		oUDPSock.close()

		self

	end # broadcastTo


	# check if we have bytes comming in on ethernet<br>
	# if not returns nil otherwise the count of bytes received after having
	# filtered and loaded the bytes to the correct buffer
	def checkIncoming()
#puts 'ethernet::checkIncoming'
		iCount = 0

		sData, sIP = self.readEthernetBroadcast()
		iCount += $oSssSapp.oIOframeHandler.parseIncoming(sData, sIP) if !sData.nil?

		sData, sIP = self.readEthernetToMe()
		iCount += $oSssSapp.oIOframeHandler.parseIncoming(sData, sIP) if !sData.nil?

		return iCount

	end # checkIncoming


	# called by ::new()<br>
	# raises on error causing SssSapp to exit
	def connect()

		# if already connected
		return nil if self.connected?

		# TODO: start settings synchronizer, event manager? We need to read or at least write settings to Arduinos and provide information to SkyTab
		puts 'TODO: settings synchronizer'

		begin

			@oUDPsocketBroadcast = UDPSocket.new
			@oUDPsocketBroadcast.bind(@mPortOptions[:ethernetIPbroadcast], @mPortOptions[:ethernetPort])

			puts 'OK:Ethernet bound to ' << @mPortOptions[:ethernetIPbroadcast]

		rescue Exception => e

			@oUDPsocketBroadcast = nil
			p 'error when binding to ' << @mPortOptions[:ethernetIPbroadcast] << ':' << @mPortOptions[:ethernetPort].to_s
			raise e

		ensure;

		end

		#begin
		#
		#	@oUDPsocketToMe = UDPSocket.new
		#	@oUDPsocketToMe.bind(@mPortOptions[:ethernetIP], @mPortOptions[:ethernetPort])
		#	@oUDPsocketToMe.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
		#
		#	puts 'OK:Ethernet bound to ' << @mPortOptions[:ethernetIP]
		#
		#rescue Exception => e
		#
		#	@oUDPsocketToMe = nil
		#	p 'error when binding to ' << @mPortOptions[:ethernetIP] << ':' << @mPortOptions[:ethernetPort].to_s
		#	raise e
		#
		#ensure;
		#
		#end

	end # connect


	def connected?()

		return (!@oUDPsocketToMe.nil? && !@oUDPsocketBroadcast.nil?)

	end # connected?


	# destroy this object cleanly
	def dealloc()

		self.disconnect();

		@mPortOptions = nil;

		nil;

	end # dealloc


	def disconnect()

		puts 'OK: disconnecting Ethernet'

		@oUDPsocketBroadcast.close() if !@oUDPsocketBroadcast.nil?
		@oUDPsocketBroadcast = nil

		@oUDPsocketToMe.close() if !@oUDPsocketToMe.nil?
		@oUDPsocketToMe = nil

	end # disconnect


	def disconnected?()

		return (@oUDPsocketToMe.nil? && @oUDPsocketBroadcast.nil?)

	end # disconnected?

  protected

	# read nonblocking from Ethernet. Returns nil or a string of bytes<br>
	# called by #checkIncoming()
	def readEthernetBroadcast()
		# if not connected
		return [nil, nil] if @oUDPsocketBroadcast.nil?

		begin

			sRead, aRemote = @oUDPsocketBroadcast.recvfrom_nonblock(1024) # @@bufferMaxLen);
			#@oUDPsocketBroadcast.flush()
			# filter out any from own IP (may be sent by other daemon or itself)
			return [nil, nil] if aRemote[3] == @mPortOptions[:ethernetIP]

			return [SssSNullSpacer << sRead, aRemote[3]]

		rescue Exception => e #IO::WaitReadable # this is raised when there's no data in the stream
			p e if ![ EOFError, Errno::EAGAIN ].member? e.class
			# don't wait for data
			return [nil, nil]

		end # try

	end # readEthernetBroadcast
	def readEthernetToMe()

		# if not connected
		return [nil, nil] if @oUDPsocketToMe.nil?

		begin
			sRead = ''; aRemote = []
			sRead, aRemote = @oUDPsocketToMe.recvfrom_nonblock(SBSerialMaxFrameLength + SBSerialSpaceLength, Socket::MSG_OOB) #1024) # @@bufferMaxLen);
			@oUDPsocketBroadcast.flush()

			return [nil, nil] if aRemote[3] == @mPortOptions[:ethernetIP]

			return [SssSNullSpacer << sRead, aRemote[3]]

		rescue Exception => e #IO::WaitReadable # this is raised when there's no data in the stream
			p e if ![ EOFError, Errno::EAGAIN ].member? e.class
			# don't wait for data
			return [nil, nil]

		end # try

	end # readEthernetToMe


	def sendTo(mIPorID = nil, sData)

		if (self.disconnected?)
			return nil;
		end # if not connected
		sIP = nil

		if (Fixnum == mIPorID.class)
			if (0xFF > mIPorID)
				# probably ID given
				if (0 == mIPorID)
					# SBAMM
					sIP = '192.168.123.1'
				elsif (4 > mIPorID)
					# an FDD
					sIP = '192.168.123.' << (10 * mIPorID).to_s(10)
				elsif (SBSerialBroadcastID == mIPorID)
					# broadcast -> sIP.nil?
				elsif (SBSerialRaspberryPiID == mIPorID)
					# to self! -> ignore
					return nil
				end # switch ID
			else
				# probably IP given as number
				sIP = ((mIPorID >> 24) & 0xFF).to_s(10) << '.'
				sIP << ((mIPorID >> 16) & 0xFF).to_s(10) << '.'
				sIP << ((mIPorID >> 8) & 0xFF).to_s(10) << '.'
				sIP << (mIPorID & 0xFF).to_s(10)
			end # if ID or IP(as number)

		end # if number given for target

		sIP = @mPortOptions[:ethernetIPbroadcast] if mIPorID.nil?

		return self.broadcastTo(sIP, sData)

	end # sendTo
	public :sendTo


	# write a string of bytes over serial without modification or envelopement
	# returns byte-count (mData.bytesize)
	def writeRawBytes(mData = nil)
p 'writeRawBytes'
		if (self.disconnected?)
			return nil;
		end # if not connected
p 'am connected'
		# TODO: allow arrays too
		if (String != mData.class)
			return nil;
		end # if invalid dada format
p 'got string data'
		iCountSent = 0
		iDataLength = nil
		iFrameID = nil
		iCountExpected = -1
		iSenderID = nil
		iTargetID = nil
		bHeaderFound = NO
		sData = ''

		begin
			mData.each_byte do |iByte|

				if (bHeaderFound)
					if (iTargetID.nil?)
						iTargetID = iByte.chr
					elsif (iSenderID.nil?)
						iSenderID = iByte
					elsif (iFrameID.nil?)
						iFrameID = iByte
					elsif (iDataLength.nil?)
						iDataLength = iByte
						iCountExpected = 5 + iDataLength + 2
					end # if not yet read target ID
				else

					# ruby respects perl (next) over C (continue), and pearls are found under the sea ;)
					next if 0x00 == iByte

					bHeaderFound = YES if 0xFF == iByte

				end # if no header found yet

				sData << iByte.chr

				iCountSent += 1

				break if (iCountSent == iCountExpected)

			end # loop each byte

		rescue Exception => e

			p 'KO: error in frame'
p e
			return 0

		end # try catch
p 'got passed with id: ' << iTargetID.to_s
		sIP = $oSssSapp.oIOframeHandler.getIPstringForID(iTargetID)
		# sIP could be nil at this point
		# send the payload
		if (sIP.nil?)
			self.sendTo(iTargetID, sData)
		else
			self.sendTo(sIP, sData)
		end # if target has been 'seen' on Ethernet or not

		iCountSent

	end # writeRawBytes
	public :writeRawBytes

	# write contents of a file byte-by-byte as-is
	# returns byte-count
	def writeRawFile(sPathFile = nil)

		if nil == sPathFile
			return nil;
		end

		iCountSent = 0
		iTargetID = nil
		bHeaderFound = NO
		sData = ''

		begin

			oF = File.new(sPathFile);
			while(nil != (iChar = oF.getbyte())) do

puts 'byte # 0x' << "%02X" % iCount << ' hex: 0x' << "%02X" % iChar << ' binary: ' << iChar.to_s(2);

				if (bHeaderFound)
					if (iTargetID.nil?)
						iTargetID = iByte.chr
					end # if not yet read target ID
				else

					next if 0x00 == iByte

					bHeaderFound = YES if 0xFF == iByte

				end # if no header found yet

				sData << iByte

				iCountSent += 1

			end # loop all bytes in file

		rescue Exception => e

			# anything ?

		ensure

			if (nil != oF)
				oF.close();
			end

		end

		sIP = $oSssSapp.oIOframeHandler.getIPstringForID(iTargetID)

		# if no IP
		if (sIP.nil?)
			self.sendTo(iTargetID, sData)
		else
			self.sendTo(sIP, sData)
		end # if target has been 'seen' on Ethernet or not

		return iCountSent;

	end # writeRawFile
	public :writeRawFile

end # SssSethernetClass
