require 'socket';
require 'SssSapp.rb'
require 'SssSEventManager.rb'
require 'SssSIOframeHandler.rb'

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

		oUDPSock = UDPsocket.new
		oUDPSock.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
		oUDPSock.send(sData, sIP, iPort)
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

		rescue Exception => e

			@oUDPsocketBroadcast = nil
p 'error when binding to ' << @mPortOptions[:ethernetIPbroadcast] << ':' << @mPortOptions[:ethernetPort].to_s
			raise e

		ensure;

		end

		begin

			@oUDPsocketToMe = UDPSocket.new
			@oUDPsocketToMe.bind(@mPortOptions[:ethernetIP], @mPortOptions[:ethernetPort])

		rescue Exception => e

			@oUDPsocketToMe = nil
p 'error when binding to ' << @mPortOptions[:ethernetIP] << ':' << @mPortOptions[:ethernetPort].to_s
			raise e

		ensure;

		end

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
#puts 'readEthernetBroadcast'
		# if not connected
		return [nil, nil] if @oUDPsocketBroadcast.nil?

		begin

			sRead, aRemote = @oUDPsocketBroadcast.recvfrom_nonblock(1024); # @@bufferMaxLen);

			return [SssSNullSpacer << sRead, aRemote[3]];

		rescue Exception => e #IO::WaitReadable # this is raised when there's no data in the stream
p e if ![ EOFError, Errno::EAGAIN ].member? e.class
			# don't wait for data
			return [nil, nil];

		end # try

	end # readEthernetBroadcast
	def readEthernetToMe()
#puts 'readEthernetToMe'
		# if not connected
		return [nil, nil] if @oUDPsocketToMe.nil?

		begin

			sRead, aRemote = @oUDPsocketToMe.recvfrom_nonblock(1024); # @@bufferMaxLen);

			return [SssSNullSpacer << sRead, aRemote[3]];

		rescue Exception => e #IO::WaitReadable # this is raised when there's no data in the stream
p e if ![ EOFError, Errno::EAGAIN ].member? e.class
			# don't wait for data
			return [nil, nil];

		end # try

	end # readEthernetToMe


	def sendTo(sIP, sData)

		if (self.disconnected?)
			return nil;
		end # if not connected

		return self.broadcastTo(sIP, sData)

	end # sendTo


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
		iTargetID = nil
		bHeaderFound = NO
		sData = ''

		mData.each_byte do |iByte|

			if (bHeaderFound)
				if (iTargetID.nil?)
					iTargetID = iByte.chr
				end # if not yet read target ID
			else

				continue if 0x00 == iByte.chr

				bHeaderFound = YES if 0xFF == iByte.chr

			end # if no header found yet

			sData << iByte

			iCountSent += 1

		end # loop each byte

		sIP = $oSssSapp.oIOframeHandler.getIPstringForID(iTargetID)
p 'sending to IP: ' << sIP
		# send the payload
		self.sendTo(sIP, sData)

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

					continue if 0x00 == iByte.chr

					bHeaderFound = YES if 0xFF == iByte.chr

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
		sIP = @mPortOptions[:ethernetIPbroadcast] if sIP.nil?

		self.sendTo(sIP, sData)

		return iCountSent;

	end # writeRawFile
	public :writeRawFile

end # SssSethernetClass
