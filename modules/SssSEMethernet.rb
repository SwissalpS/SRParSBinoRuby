require 'socket'
require 'eventmachine'
require 'SssSEMapp.rb'
require 'SssSEMeventManager.rb'
require 'SssSEMframeHandler.rb'


module SssSEMServer

	# the IP I'm bound to
	@sIP = nil

	# the IPs I ignore
	@aIPignore = []

	def initialize(sIP = nil, aIPignore = nil)
		@sIP = sIP
		@aIPignore = (Array == aIPignore.class) ? aIPignore : []
	end # initialize


	def post_init
		puts 'OK:Ethernet bound to ' << @sIP
	end # post_init


	def receive_data(sData)

		# or with Socket method
		iPort, sIP = Socket.unpack_sockaddr_in(self.get_peername)
		return if sData.nil?

		puts 'OK:()<-[]- ' << sData.length.to_s << ' bytes from: ' << sIP # << ':' << iPort.to_s
		
		# filter out broadcasts we made as proxy for trigger files
		# or time broadcasts etc.
		if @aIPignore.member?(sIP)
			puts 'OK:ignore'
			return
		end # if ignore

		SssSEMapp.oIOframeHandler.parseIncoming(SssSNullSpacer + sData, sIP)
		sData = ''

	end # receive_data

end # SssSEMServer

##
# Listen to Ethernet messages and notifies SkyTab<br>
# Also message SBAMM and SBAMFDDDs
# Instantiated and controlled by SssSEMapp
class SssSEMethernetClass

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
				:ethernetIP => SssSEMapp.get(:ethernetIP, sIPdefault),
				:ethernetIPbroadcast => SssSEMapp.get(:ethernetIPbroadcast, SBethernetDefaultIPbroadcast),
				:ethernetIPgateway => SssSEMapp.get(:ethernetIPgateway, SBethernetDefaultIPgateway),
				:ethernetIPsubnet => SssSEMapp.get(:ethernetIPsubnet, SBethernetDefaultIPsubnet),
				:ethernetPort => SssSEMapp.get(:ethernetPort, SBethernetDefaultPort)
			};

		@oPort = nil;

		self.connect();

		# make sure we can broadcast as long as we are connected
		# TODO: get serial broadcast ID
		SssSEMapp.oIOframeHandler.markOnline(SBSerialBroadcastID, @mPortOptions[:ethernetIPbroadcast])

		self

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

		puts 'OK:()-[]-> ' << sData.length.to_s << ' bytes to: ' << sIP

		self

	end # broadcastTo


	# called by ::new()<br>
	# raises on error causing SssSEMapp to exit
	def connect()

		# if already connected
		return nil if self.connected?

		iPort = @mPortOptions[:ethernetPort]

		sIP = @mPortOptions[:ethernetIPbroadcast]
		sIPme = @mPortOptions[:ethernetIP]
		aIPignore = [sIPme]

		begin

			@oUDPsocketBroadcast = EM::open_datagram_socket(sIP, iPort, SssSEMServer, sIP, aIPignore)

		rescue Exception => e

			@oUDPsocketBroadcast = nil
			p 'error when binding to ' << sIP << ':' << iPort.to_s
			raise e

		ensure

		end # try, catch binding broadcast

		begin

			@oUDPsocketToMe = EM::open_datagram_socket(sIPme, iPort, SssSEMServer, sIPme, aIPignore)

		rescue Exception => e

			@oUDPsocketToMe = nil
			p 'error when binding to ' << sIPme << ':' << iPort.to_s
			raise e

		ensure;

		end # try, catch binding self

		return YES

		# TODO: start settings synchronizer, event manager? We need to read or at least write settings to Arduinos and provide information to SkyTab
		puts 'TODO: settings synchronizer'

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

		# TODO: shutdown cleanly
		#@oUDPsocketBroadcast.close() if !@oUDPsocketBroadcast.nil?
		@oUDPsocketBroadcast = nil

		#@oUDPsocketToMe.close() if !@oUDPsocketToMe.nil?
		@oUDPsocketToMe = nil

	end # disconnect


	def disconnected?()

		return (@oUDPsocketToMe.nil? && @oUDPsocketBroadcast.nil?)

	end # disconnected?

  protected

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
#p 'writeRawBytes'
		if (self.disconnected?)
			return nil;
		end # if not connected
#p 'am connected'
		# TODO: allow arrays too
		if (String != mData.class)
			return nil;
		end # if invalid dada format
#p 'got string data'
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
p ' writeRawBytes to ID: ' << iTargetID.to_s
		sIP = SssSEMapp.oIOframeHandler.getIPstringForID(iTargetID)
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
p ' writeRawFile to ID: ' << iTargetID.to_s
		sIP = SssSEMapp.oIOframeHandler.getIPstringForID(iTargetID)

		# if no IP
		if (sIP.nil?)
			self.sendTo(iTargetID, sData)
		else
			self.sendTo(sIP, sData)
		end # if target has been 'seen' on Ethernet or not

		return iCountSent;

	end # writeRawFile
	public :writeRawFile

end # SssSEMethernetClass
