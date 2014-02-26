
YES = true if !defined? YES
NO = false if !defined? NO

##
# Baseclass for online-marker-file.

class SssSonlineMarkerFile

	# path and filename to the Ethernet-online-marker-file
	@sEthernetPathFile; attr_reader :sEthernetPathFile

	# path and filename to the Ethernet-online-marker-file
	@sSerialPathFile; attr_reader :sSerialPathFile

	# create a new marker object
	def initialize(iID, sIP = nil)

		@sEthernetPathFile = $oSssSapp.get(:pathFileOnlineEthernetBase, '/gitSwissalpS/SRParSBinoRuby/onlineIDs/eth/') << iID.to_s
		@sSerialPathFile = $oSssSapp.get(:pathFileOnlineEthernetBase, '/gitSwissalpS/SRParSBinoRuby/onlineIDs/com/') << iID.to_s

		if (sIP.nil?)
			# no IP, must be serial message
			self.goOnlineSerial()
		else
			# got IP, must be UDP message
			self.goOnlineEthernet(sIP)
		end # if serial or Ethernet message

	end # initialize


	# clean destruction
	def dealloc()

		self.truncateEthernet();

		self.truncateSerial(NO);

		nil;

	end # dealloc


	def isOnlineEthernet?()

		File.exists?(@sEthernetPathFile)

	end # isOnlineEthernet?


	def isOnlineSerial?()

		File.exists?(@sSerialPathFile)

	end # isOnlineSerial?


	def goOfflineEthernet()

		self.truncateEthernet()

	end # goOfflineEthernet


	def goOfflineSerial()

		self.truncateSerial(NO)

	end # goOfflineSerial


	def goOnlineEthernet(sIP)

		self.truncateEthernet(sIP)

	end # goOnlineEthernet
	public :goOnlineEthernet


	def goOnlineSerial()

		self.truncateSerial()

	end # goOnlineSerial
	public :goOnlineSerial


	# delete marker file and recreate it<br>
	def truncateEthernet(sIP = nil)

		# delete if exists
		if (File.exists?(@sEthernetPathFile))

			# remove it first
			File.delete(@sEthernetPathFile);

			if (File.exists?(@sEthernetPathFile))
				raise 'Can not delete file: ' << @sEthernetPathFile;
			end # if file still exists

		end # if trigger-file already exists

		# if only need to delete (dealloc/go offline)
		return self if sIP.nil?

		# attempt to create it
		oF = File.new(@sEthernetPathFile, 'wb'); oF.close;

		if (!File.exists?(@sEthernetPathFile))
			raise 'Can not create file: ' << @sEthernetPathFile;
		end # if failed to create

		# make it writeable for only owner, all may read)
		File.chmod(0644, @sEthernetPathFile)

		# and open for writing
		oF = File.new(@sEthernetPathFile, 'wb');
		oF.write(sIP); oF.close;

		self

	end # truncate
	protected :truncateEthernet


	# delete marker file and recreate it<br>
	def truncateSerial(bRemake = YES)

		# delete if exists
		if (File.exists?(@sSerialPathFile))

			# remove it first
			File.delete(@sSerialPathFile);

			if (File.exists?(@sSerialPathFile))
				raise 'Can not delete file: ' << @sSerialPathFile;
			end # if file still exists

		end # if trigger-file already exists

		# if only need to delete (dealloc/go offline)
		return self if !bRemake

		# attempt to create it
		oF = File.new(@sSerialPathFile, 'wb'); oF.close;

		if (!File.exists?(@sSerialPathFile))
			raise 'Can not create file: ' << @sSerialPathFile;
		end # if failed to create

		# make it writeable for only owner, all may read)
		File.chmod(0644, @sSerialPathFile)

		self

	end # truncate
	protected :truncateSerial

end # SssSonlineMarkerFile
