
require 'SssSIOframeHandler.rb'
require 'SssSserial.rb'
require 'SssSethernet.rb'
require 'SssStriggerCommandMe.rb'
require 'SssStriggerCurrentTime.rb'
require 'SssStriggerDemoID.rb'
require 'SssStriggerRaw.rb'
require 'SssStriggerReset.rb'
require 'SssStriggerRiderInfo.rb'
require 'SssStriggerStart.rb'
require 'SssStriggerStop.rb'
require 'SssStriggerTimer.rb'

YES = true if !defined? YES
NO = false if !defined? NO

##
# Main application class<br>
# Use global *SssSapp* to access the singleton
# It reads ports list, if exists, from config/ports. One port per line.<br>
# Then reads from config/settings.yaml or uses hard-coded defaults
# To create your own instance, and provide a non-default path for the config file:
#  -> SssSappClass.new('path/to/your/config.yaml').run()
#
#
class SssSappClass

  private

	@@_defaultPathFilePID = '/var/tmp/SRParSBinoRuby.pid'; # :doc: really? how can I force an attribute to be included?

	@@_defaultPathFileConfig = 'config/settings.yaml';

	@@_sharedInstance = nil

	@aCurrentRideIDs = [ 0, 0 ]; attr_reader :aCurrentRideIDs

	@sPathSkyTabBin = '/gitSwissalpS/SkyTab/SkyTab/bin/SkyTab'

	@_initialized = nil

	# path to the configuration file
	@_sPathFileConfigYAML;

	# hash holding config settings
	@hS = {}; attr_reader :hS

	##
	# SssStriggerClass objects listening to files
	@aPipes = nil; attr_reader :aPipes

  protected

	# shared SssSethernetClass object
	@oEthernet = nil; attr_reader :oEthernet

	# shared SssSIOframeHandlerClass object
	@oIOframeHandler = nil; attr_reader :oIOframeHandler

	# shared SssSserialClass object
	@oSerial = nil; attr_reader :oSerial

	#
	@bUseEthernet = YES; attr_accessor :bUseEthernet
	@bUseSerial = NO; attr_accessor :bUseSerial
	
  public

   attr_reader :oSerial

	# create and read config settings from yaml-file.<br>
	# writes PID to file defined in settings as :pathFilePID or if not available
	# uses /var/tmp/SRParSBinoRuby.pid
	def initialize(sPathFileConfigYAML = nil)

		@_initialized = NO

		@aPipes = []
		@aCurrentRideIDs = [ 0, 0 ]

		@oEthernet = nil
		@oIOframeHandler = nil
		@oSerial = nil

		# fetch settings
		self.readConfig(sPathFileConfigYAML)

		# write pid to file
		sPathFilePID = self.get(:pathFilePID, @@_defaultPathFilePID)
		File.open(sPathFilePID, 'wb') { |oF| oF.write($$.to_s) }

		@sPathSkyTabBin = self.get(:pathSkyTabBin, '/gitSwissalpS/SkyTab/SkyTab/bin/SkyTab')
		if File.exists? @sPathSkyTabBin

			puts 'OK:SkyTab.bin exists'

		else

			puts 'ERROR:SkyTab.bin not found at ' << @sPathSkyTabBin

			@sPathSkyTabBin = nil

		end # if SkyTab bin exists

		@bUseEthernet = self.get(:useEthernet, YES)

		@bUseSerial = self.get(:useSerial, NO)

		@_initialized = YES;

		self

	end # initialize


	def initEthernet()

		if (!@bUseEthernet)
			puts 'SKIP:Ethernet'
			return YES
		end # if use Ethernet

		@oEthernet = SssSethernetClass.new()
		
		if (NO)
			puts 'FAIL:Ethernet BAD'
			return nil
		else
			puts 'OK:Ethernet OK'
			return YES
		end # if init Ethernet ok

	end # initEthernet
	protected :initEthernet


	def initIOframeHandler()

		@oIOframeHandler = SssSIOframeHandlerClass.new()

		self

	end # initIOframeHandler
	protected :initIOframeHandler


	# start serial connection
	# colled by #run() before entering #loop()
	def initSerial()

		if (!@bUseSerial)
			puts 'SKIP:Serial'
			return YES
		end # if use serial

		# if connected, disconnect
		if !@oSerial.nil?
			@oSerial.disconnect() if @oSerial.connected?
		end # if serial has been initiated previously

		aPorts = self.get(:serialPortsToTry, [])

		iRetryCount = aPorts.count();

		begin

			iRetryCount -= 1;
			@oSerial = SssSserialClass.new(aPorts[iRetryCount]);

			puts 'OK: connected to ' << aPorts[iRetryCount];

		rescue Exception => e

			puts e.message
			puts e.backtrace.inspect

			if 0 < iRetryCount

				puts 'RE: will retry on other port in 5';
				sleep(5);

				retry;

			end # if retry

			raise 'KO: failed to connect to any serial port';

			return nil;

		end # catch connection errors

		puts 'OK:Serial OK'

		return YES;

	end # initSerial
	protected :initSerial


	# start watching for activity from SkyTab and other
	# called by #run() before entering #loop()
	def initTriggers()

		@aPipes = []

		begin

			# these raise on error

			# command me
			@aPipes << SssStriggerCommandMe::new(self.get(:pathFileTriggerCommandMe, nil), self.get(:pathFileTriggerCommandCron, nil))

			# main triggers
			@aPipes << SssStriggerReset::new(self.get(:pathFileTriggerReset, nil))
			@aPipes << SssStriggerStart::new(self.get(:pathFileTriggerStart, nil))
			@aPipes << SssStriggerStop::new(self.get(:pathFileTriggerStop, nil))

			# raw write access
			@aPipes << SssStriggerRaw::new(self.get(:pathFileTriggerRaw, nil))

			for iBike in (0...self.get(:numberOfBIKEs, 1)) do

			  sPath = self.get(:pathFileTriggerRiderInfoBaseName, 'triggers/rider')  + iBike.to_s + '.info'
			  @aPipes << SssStriggerRiderInfo::new(sPath, iBike)

			end # for loop

			# time set and display
			@aPipes << SssStriggerCurrentTime::new(self.get(:pathFileTriggerCurrentTime, nil))

			# broadcast all to start/stop demo loop
			@aPipes << SssStriggerDemoID::new(self.get(:pathFileTriggerDemoID, nil))

			# timer
			@aPipes << SssStriggerTimer::new(self.get(:pathFileTriggerTimer, nil))

		rescue Exception => e

			puts 'ERROR: ' << e.to_s

			return nil

		end # catch errors

		puts 'OK: Primed ' << @aPipes.count.to_s << ' triggers'

		return YES;

	end # initTriggers
	protected :initTriggers


	# close all ports and remove pid
	def dealloc()

		# and disconnect
		@oSerial.dealloc() if !@oSerial.nil?
		@oSerial = nil

		puts 'OK:Serial disconnected'

		@oEthernet.dealloc() if !@oEthernet.nil?
		@oEthernet = nil

		@oIOframeHandler.dealloc() if !@oIOframeHandler.nil?
		@oIOframeHandler = nil

		puts 'OK:Ethernet disconnected'

		@aPipes.each { |oPipe| oPipe.dealloc() } if !@aPipes.nil?
		@aPipes = nil

		puts 'OK:Triggers halted'

		# remove pid file
		sPathFilePID = self.get(:pathFilePID, @@_defaultPathFilePID)
		File.delete(sPathFilePID) if File.exists? sPathFilePID

		puts 'OK:PID file removed from ' << sPathFilePID

		puts 'Good Bye - Enjoy Life'

		# and quit
		exit! true

		nil

	end # dealloc

	def tellSkyTab(sInvocationPath, iBike)

		if @sPathSkyTabBin.nil?

			puts 'ERROR: SkyTab bin was not present at init'
			return nil

		end # if no SkyTab

		sCommand = @sPathSkyTabBin
		sCommand += iBike.to_s if !iBike.nil?

		sCommand += ' '  + sInvocationPath + '?o=SRParSBinoCLIrelayArduino'

		begin

			# TODO: make this detectable if failed or not
			`#{sCommand}`

			# this does not really work
			#puts 'OK: told SkyTab ' << sInvocationPath
			return true

		rescue Exception => e

			puts 'ERROR: could not tell SkyTab ' << sInvocationPath
			puts e.to_s

		end # catch

		return nil

	end # tellSkyTab


	def tellSkyTabDurationForBIKE(ulDuration, iBike)

p 'got duration in millisecondos: ' << ulDuration.to_s
p 'for bike: ' << iBike.to_s

		if !(0..1).member? iBike

			puts 'ERROR: invalid BIKE ID'
			return nil

		end # if invalid iBike

		sInvocationPath = '/cgi/hpi/end/' + ulDuration.to_s
		sInvocationPath += '/' + @aCurrentRideIDs[iBike].to_s

		return self.tellSkyTab(sInvocationPath, iBike)

	end # tellSkyTabDurationForBIKE


	def tellSkyTabReset(iBike)

		if !(0..1).member? iBike

			puts 'ERROR: invalid BIKE ID'
			return nil

		end # if invalid iBike

		sInvocationPath = '/cgi/hpi/reset' + iBike.to_s

		return self.tellSkyTab(sInvocationPath, iBike)

	end # tellSkyTabReset


	def tellSkyTabStart(iBike)

		if !(0..1).member? iBike

			puts 'ERROR: invalid BIKE ID'
			return nil

		end # if invalid iBike

		sInvocationPath = '/cgi/hpi/start' + iBike.to_s

		return self.tellSkyTab(sInvocationPath, iBike)

	end # tellSkyTabStart


	def tellSkyTabStop(iBike)

		if !(0..1).member? iBike

			puts 'ERROR: invalid BIKE ID'
			return nil

		end # if invalid iBike

		sInvocationPath = '/cgi/hpi/stop' + iBike.to_s

		return self.tellSkyTab(sInvocationPath, iBike)

	end # tellSkyTabStop


	# main run loop
	def loop()
		#return nil if @oSerial.nil?

#		iByteCount = @oSerial.writeRawFile('/Volumes/Users/luke/Documents/Arduino/SBmobitecSender/commands/nameSetPeter.bin');#
#puts 'wrote ' << iByteCount.to_s << ' byte(s) to serial'

#	  iCount = 122;
		fSleepFor = self.get(:loopSleepDuration, 0.002)
		while (YES) do

			#sleep(0.00002) # 85%
			#sleep(0.0002) # 47%
			sleep(fSleepFor) # 10% cpu usage on OSX MBP 8 core

			# TODO: use a system select function or something else that uses less cpu
#			# references may have changed due to truncation
#			# so we need to rebuild array each loop
#			aPipeIOs = [@oSerial.oPort]
#			@aPipes.each { |oPipe| aPipeIOs << oPipe.oFile }
#
#			# unfortunately 1: this always returns three even if they don't have new data (at least on OS X)
#			aReadPipes = IO.select(aPipeIOs)
#
#p aReadPipes.count
#
#			aReadPipes.each do |oFile|
#
#				# now is this serial or other?
#				if @oSerial.oPort == oFile
#p 'is serial port' # <<-- this never matched
#					@oSerial.checkIncoming()
#				else
#					# hmm, loop again to find whose this is!
#					@aPipes.each do |oPipe|
#
#						if oPipe.oFile == oFile
#							oPipe.process if oPipe.hasData?
#p 'match found' # <<-- this never matched
#							break
#						end # if found object
##p 'comparing', oPipe
#					end # foreach pipe check if this one is meant
#
#				end # if serial port or trigger file ready for reading
#
#			end # loop all with incomming




			# listen to serial if it's up
			if (!@oSerial.nil?)
				nilOrNumberOfBytesReceived = @oSerial.checkIncoming()
			end # if serial up

			# listen to Ethernet if it's up
			if (!@oEthernet.nil?)
				nilOrNumberOfBytesReceived = @oEthernet.checkIncoming()
			end # if Ethernet up

			# check incomming commands from SkyTab or other scripts
			@aPipes.each { |oPipe| oPipe.process if oPipe.hasData? }




#
#			iCount -= 1
#
#			@oSerial.writeFramed(1, 'hahaha')
#
#			mRead = @oSerial.checkIncoming()
#if (nil != mRead)
#	puts 'serial in: ' . mRead.to_s;
#end
#
#			mRead = @oPipe.checkIncoming();
#if (nil != mRead)
#	puts mRead;
#end
#
#			if (0 == iCount)
#
#				return;
#
#			end # if counted down

		end # while forever

		fSleepFor = nilOrNumberOfBytesReceived = nil

		self

	end # loop
	protected :loop


	# fetch a value from the app-settings providing a default value
	def get(mKey, mDefaultValue = nil)

		# TODO: make it possible to traverse the tree
		if @hS[mKey].nil?
			puts 'US:unknown setting key: ' << mKey.to_s
			mDefaultValue
		else
			@hS[mKey]
		end # if got value or not

	end # get


	# print some debugging info or welcome message
	def printInfo()

		puts 'My PID: '.concat($$.to_s);
		puts 'Myself: '.concat($0);
		puts 'Arguments: '.concat($*.join(', '));

	end # printInfo


	# read configuration file from given location.<br>
	# is called on creation by ::new()
	def readConfig(sPathFileConfigYAML = nil)

		# read list of ports to try from canfig/ports
		aPorts = nil;
		sFilePorts = 'canfig/ports';
		if (File.exists?(sFilePorts))
			aPorts = File.readlines(sFilePorts);
		end # if exists

		# fallback to some default ports to try
		aPorts ||= [
			'/dev/ttys0', '/dev/ttys000', '/dev/ttys001', '/dev/ttys002',
			'/dev/ttys003', '/dev/tty.Bluetooth-Modem', '/dev/tty.Bluetooth-PDA-Sync', '/dev/ttyAMA0'
		];

		# use default config file location
		if (nil == sPathFileConfigYAML)
			sPathFileConfigYAML = @@_defaultPathFileConfig
		end # if use default config location

		# other settings in yaml format
		if (File.exists?(sPathFileConfigYAML))

			@hS = YAML.load_file(sPathFileConfigYAML)

			@hS[:serialPortsToTry] ||= aPorts

		else

			# no settings file, use all default values
			@hS = {
				:serialPortsToTry => aPorts
			}

		end # if exists

		@_sPathFileConfigYAML = sPathFileConfigYAML;

	end # readConfig

	##
	# +run the app+ with settings passed at creation
	def run()

		# output welcome
		printInfo()

		#
		self.initIOframeHandler()
		
		# open serial port (first one that works)
		#self.dealloc() if self.initSerial().nil?
		self.initSerial()

		# start listening to Ethernet messages
		self.initEthernet()

		# start File watcher(s)
		self.dealloc() if self.initTriggers().nil?
		puts 'OK:trigger files initiated'

		if (@oSerial.nil? && @oEthernet.nil?)
			puts 'Have neither Serial nor Ethernet connection!'
			self.dealloc()
		end # if have no connection

		puts 'OK:entering run-loop'
		begin

			# do whatever
			self.loop();

		rescue Exception => e

			puts e.to_s
			puts e.backtrace.to_s

		ensure

			# and quit
			self.dealloc()

		end # catch runtime errors

	end # run

	# run shared instance with settings from default location. -> #run()
	def self.run()
		SssSappClass::sharedInstance().run();
	end # run


	# save current config to location specified
	def saveConfig(sPathFileConfigYAML = nil)

		sPathFileConfigYAML ||= @_sPathFileConfigYAML

		File.open(sPathFileConfigYAML, 'wb+') { |f| f.write(@hS.to_yaml); }

	end # saveConfig


	def serialIDofDisplay(iBike)

		return self.get(:idSBAMFDDbike0, 1) if 0 == iBike

		return self.get(:idSBAMFDDbike1, 2) if 1 == iBike

		return self.get(:idSBAMFDDbike2, 3)

	end # serialIDofDisplay


	# set a value in the config
	def set(mKey, mValue)

		@hS[mKey] = mValue

		self

	end # set


	def setCurrentRiderInfo(sName, sCategory, iID, iBike, ulDuration)

		return if !(0..2).member? iBike
		iFDD = self.serialIDofDisplay(iBike)

		@aCurrentRideIDs[iBike] = iID

		sData = 'n' << sName
		@oIOframeHandler.writeFramed(iFDD, sData)

		sData = 'c' << sCategory
		@oIOframeHandler.writeFramed(iFDD, sData)

		sleep(0.1)

		@oIOframeHandler.writeFramed(iFDD, 'M')

		sleep(0.1)

		if 0 <= ulDuration

			sData = 'd' << ((ulDuration >> 24) & 0xFF).chr
			sData += ((ulDuration >> 16) & 0xFF).chr
			sData += ((ulDuration >> 8) & 0xFF).chr
			sData += (ulDuration & 0xFF).chr
			sData += iBike.chr

			@oIOframeHandler.writeFramed(iFDD, sData)

			sleep(0.1)

		end # if got duration

	end # setCurrentRiderInfo


	# shared instance of SssSapp with settings from default location
	def self.sharedInstance

		@@_sharedInstance ||= SssSappClass.new();
		return @@_sharedInstance;

	end # sharedInstance

end # SssSappClass


# Global singleton instance of SssSapp
$oSssSapp = SssSappClass::sharedInstance() if $oSssSapp.nil?
