
require 'SssSEMframeHandler.rb'
#require 'SssSserial.rb'
require 'SssSEMethernet.rb'
require 'SssSEMtriggerCommandMe.rb'
require 'SssSEMtriggerCurrentTime.rb'
require 'SssSEMtriggerDemoID.rb'
require 'SssSEMtriggerRaw.rb'
require 'SssSEMtriggerReset.rb'
require 'SssSEMtriggerRiderInfo.rb'
require 'SssSEMtriggerStart.rb'
require 'SssSEMtriggerStop.rb'
require 'SssSEMtriggerTimer.rb'
# now handled by SssSgems.rb included by SssSEMethernet.rb
#require 'eventmachine'

YES = true if !defined? YES
NO = false if !defined? NO

# interval in seconds..
SBbroadcastDateIntervalDefault = 51 * 60
SBbroadcastTimeIntervalDefault = 5 * 60
SBidleIntervalDefault = 0.02

module SssSEMbroadcastDate
	def call
		SssSEMapp.broadcastDate()
	end # call
end # SssSEMbroadcastDate


module SssSEMbroadcastTime
	def call
		SssSEMapp.broadcastTime()
	end # call
end # SssSEMbroadcastTime


module SssSEMcheckPipes
	def call
		SssSEMapp.checkPipes()
	end # call
end # SssSEMcheckPipes

##
# Main application class<br>
# Use global *SssSEMapp* to access the singleton
# It reads ports list, if exists, from config/ports. One port per line.<br>
# Then reads from config/settings.yaml or uses hard-coded defaults
# To create your own instance, and provide a non-default path for the config file:
#  -> SssSEMappClass.new('path/to/your/config.yaml').run()
#
#
class SssSEMappClass

  private

	@@_defaultPathFilePID = '/var/tmp/SRParSBinoRuby.pid' # :doc: really? how can I force an attribute to be included?

	@@_defaultPathFileConfig = 'config/settings.yaml'

	@@_defaultPathResponseBase = '/gitSwissalpS/SRParSBinoRuby/notificationsFromArduinos/'

	@aCurrentRideIDs = [ 0, 0, 0 ]; attr_reader :aCurrentRideIDs

	@sPathSkyTabBin = '/gitSwissalpS/SkyTab/SkyTab/bin/SkyTab'

	@_initialized = nil

	# path to the configuration file
	@_sPathFileConfigYAML;

	# hash holding config settings
	@hS = {}; attr_reader :hS

	##
	# SssSEMtriggerClass objects listening to files
	@aPipes = nil; attr_reader :aPipes

  protected

  public

	# shared SssSethernetClass object
	@oEthernet = nil; attr_reader :oEthernet

	# shared SssSIOframeHandlerClass object
	@oIOframeHandler = nil; attr_reader :oIOframeHandler

	# shared SssSserialClass object
	@oSerial = nil; attr_reader :oSerial

	#
	@bUseEthernet = YES; attr_accessor :bUseEthernet
	@bUseSerial = NO; attr_accessor :bUseSerial

	# create and read config settings from yaml-file.<br>
	# writes PID to file defined in settings as :pathFilePID or if not available
	# uses /var/tmp/SRParSBinoRuby.pid
	def initialize(sPathFileConfigYAML = nil)

		@_initialized = NO

		@aPipes = []
		@aCurrentRideIDs = [ 0, 0, 0 ]

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

			puts 'KO:SkyTab.bin not found at ' << @sPathSkyTabBin

			@sPathSkyTabBin = nil

		end # if SkyTab bin exists

		self.initDirs()

		@bUseEthernet = self.get(:useEthernet, YES)

		@bUseSerial = self.get(:useSerial, NO)

		@_initialized = YES;

		if (0 < ARGV.length())
			self.saveConfig() if ($*.member?('-w'))
		end # if requested to write config

		self

	end # initialize


	def idle()

		# listen to file events
		self.checkPipes()
		
		@oIOframeHandler.oEventManager.executeNextStep();

	end # idle
	protected :idle


	def initDirs()

		aPaths = []

		sPathBase = self.get(:pathFileResponseBase, @@_defaultPathResponseBase) + 'durations'

		aPaths << sPathBase + '0'
		aPaths << sPathBase + '1'
		aPaths << sPathBase + '2'

		for sPath in aPaths
			`mkdir -p #{sPath}`
		end # loop all dirs

		self

	end # initDirs


	def initEthernet()

		if (!@bUseEthernet)
			puts 'OK:SKIP Ethernet'
			return YES
		end # if use Ethernet

		@oEthernet = SssSEMethernetClass.new()
		
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

		@oIOframeHandler = SssSEMframeHandlerClass.new()

		self

	end # initIOframeHandler
	protected :initIOframeHandler


	# start serial connection
	# colled by #run() before entering #loop()
	def initSerial()

		if (!@bUseSerial)
			puts 'OK:SKIP Serial'
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
			@aPipes << SssSEMtriggerCommandMe::new(self.get(:pathFileTriggerCommandMe, nil), self.get(:pathFileTriggerCommandCron, nil))

			# main triggers
			@aPipes << SssSEMtriggerReset::new(self.get(:pathFileTriggerReset, nil))
			@aPipes << SssSEMtriggerStart::new(self.get(:pathFileTriggerStart, nil))
			@aPipes << SssSEMtriggerStop::new(self.get(:pathFileTriggerStop, nil))

			# raw write access
			@aPipes << SssSEMtriggerRaw::new(self.get(:pathFileTriggerRaw, nil))

			for iBike in (0...self.get(:numberOfBIKEs, 1)) do

			  sPath = self.get(:pathFileTriggerRiderInfoBaseName, 'triggers/rider')  + iBike.to_s + '.info'
			  @aPipes << SssSEMtriggerRiderInfo::new(sPath, iBike)

			end # for loop

			# time set and display
			@aPipes << SssSEMtriggerCurrentTime::new(self.get(:pathFileTriggerCurrentTime, nil))

			# broadcast all to start/stop demo loop
			@aPipes << SssSEMtriggerDemoID::new(self.get(:pathFileTriggerDemoID, nil))

			# timer
			@aPipes << SssSEMtriggerTimer::new(self.get(:pathFileTriggerTimer, nil))

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

		# remove output log?

		# shutdown EventMachine
		EM::stop_event_loop()

		# remove pid file
		sPathFilePID = self.get(:pathFilePID, @@_defaultPathFilePID)
		File.delete(sPathFilePID) if File.exists? sPathFilePID

		puts 'OK:PID file removed from ' << sPathFilePID

		puts 'Good Bye - Enjoy Life'

		# and quit
		exit! true

		nil

	end # dealloc


	def broadcastDate()

		oT = Time.now.utc
puts '   broadcasting date ' << oT.to_s

		sData = 0x5C.chr << (((oT.day() - 1) << 2) + 0).chr << (oT.month() - 1).chr << (oT.year() - 2000).chr

		@oIOframeHandler.writeFramed(SBSerialBroadcastID, sData)

	end # broadcastDate


	def broadcastTime()

		iMillisSinceMidnight = iMSM = ((Time.now.to_f % 86400) * 1000).to_i

puts '   broadcasting milliseconds since midnight ' << iMillisSinceMidnight.to_s

		sData = 0x74.chr << ((iMSM >> 24) & 0xFF).chr
		sData << ((iMSM >> 16) & 0xFF).chr
		sData << ((iMSM >> 8)  & 0xFF).chr
		sData << (iMSM  & 0xFF).chr

		@oIOframeHandler.writeFramed(SBSerialBroadcastID, sData)

	end # broadcastDate


	def checkPipes()

		# check incomming commands from SkyTab or other scripts
		@aPipes.each { |oPipe| oPipe.process if oPipe.hasData? }

	end # checkPipes


	def tellSkyTab(sInvocationPath, iBike)

		if @sPathSkyTabBin.nil?

			puts 'KO: SkyTab bin was not present at init'
			return nil

		end # if no SkyTab

		sCommand = @sPathSkyTabBin
		#sCommand += iBike.to_s if !iBike.nil?

		sCommand += ' '  + sInvocationPath + '?o=SRParSBinoCLIrelayArduino'

		begin

			bOK = NO
			# since we use EventMachine anyway
			EM.system(sCommand) { |sOut,oRes|
				puts sOut
				if (oRes.exitstatus == 0)
					puts 'OK: told SkyTab ' << sInvocationPath
					bOK = YES
				else
					puts 'KO: told SkyTab ' << sInvocationPath
				end # if run OK or not
			} # run system

		rescue Exception => e

			puts 'ERROR: could not tell SkyTab ' << sInvocationPath
			puts e.to_s

			return nil

		end # catch
p bOK
		return bOK

	end # tellSkyTab


	def tellSkyTabDurationForBIKE(ulDuration, iBike)

p 'got duration in milliseconds: ' << ulDuration.to_s
p 'for bike: ' << iBike.to_s

		if !(0..2).member? iBike

			puts 'KO: invalid BIKE ID'
			return nil

		end # if invalid iBike

		self.writeDuration(ulDuration, iBike)

		sInvocationPath = '/cgi/hpi/end/' + ulDuration.to_s
		sInvocationPath += '/' + @aCurrentRideIDs[iBike].to_s
		sInvocationPath += '/' + iBike.to_s

		return self.tellSkyTab(sInvocationPath, iBike)

	end # tellSkyTabDurationForBIKE


	def tellSkyTabReset(iBike)

		if !(0..2).member? iBike

			puts 'ERROR: invalid BIKE ID'
			return nil

		end # if invalid iBike

		self.writeReset(iBike)

		sInvocationPath = '/cgi/hpi/reset/' + iBike.to_s

		return self.tellSkyTab(sInvocationPath, iBike)

	end # tellSkyTabReset


	def tellSkyTabStart(iBike)

		if !(0..2).member? iBike

			puts 'ERROR: invalid BIKE ID'
			return nil

		end # if invalid iBike

		self.writeStart(iBike)

		sInvocationPath = '/cgi/hpi/start/' + iBike.to_s

		return self.tellSkyTab(sInvocationPath, iBike)

	end # tellSkyTabStart


	def tellSkyTabStop(iBike)

		if !(0..2).member? iBike

			puts 'ERROR: invalid BIKE ID'
			return nil

		end # if invalid iBike

		self.writeStop(iBike)

		sInvocationPath = '/cgi/hpi/stop/' + iBike.to_s

		return self.tellSkyTab(sInvocationPath, iBike)

	end # tellSkyTabStop


	# fetch a value from the app-settings providing a default value
	def get(mKey, mDefaultValue = nil)

		# TODO: make it possible to traverse the tree
		if @hS[mKey].nil?
			puts 'US:unknown setting key: ' << mKey.to_s
			@hS[mKey] = mDefaultValue
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
		#self.initSerial()

		# start listening to Ethernet messages
		self.initEthernet()

		# start File watcher(s)
		self.dealloc() if self.initTriggers().nil?
		puts 'OK:trigger files initiated'

		if (@oSerial.nil? && @oEthernet.nil?)
			puts 'Have neither Serial nor Ethernet connection!'
			self.dealloc()
		end # if have no connection

		EM::add_periodic_timer(
				get(:iBroadcastDateInterval, SBbroadcastDateIntervalDefault)) { SssSEMapp.broadcastDate() }

		EM::add_periodic_timer(
				get(:iBroadcastTimeInterval, SBbroadcastTimeIntervalDefault)) {
					self.broadcastTime() }

		EM::add_periodic_timer(
				get(:iIdleInterval, SBidleIntervalDefault)) {
					self.idle() }

		# broadcast something to tickle responses and synchronize date & time
		EM::add_timer(0.5) { self.broadcastTime() }
		EM::add_timer(2) { self.broadcastDate() }

		puts 'OK:entering run-loop'

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


	# called by trigger CommandMe upon e
	def updateEEPROMcaches()

		# loop all known devices requesting checksums
		# or just ask all and find out which are online
		@oIOframeHandler.oEventManager.addInitialSyncEvents()

	end # updateEEPROMcaches


	def writeDuration(ulDuration, iBike)

		sPathBase = self.get(:pathFileResponseBase, @@_defaultPathResponseBase)
		sPathBase += '/' if '/' != sPathBase[sPathBase.length() -1].chr

		sPathFile = sPathBase + 'durations' + iBike.to_s + '/' + @aCurrentRideIDs[iBike].to_s

		self.writeTimeToFile(sPathFile)

	end # writeDuration


	def writeReset(iBike)

		sPathBase = self.get(:pathFileResponseBase, @@_defaultPathResponseBase)
		sPathBase += '/' if '/' != sPathBase[sPathBase.length() -1].chr

		sPathFile = sPathBase + 'reset' + iBike.to_s

		self.writeTimeToFile(sPathFile)

	end # writeReset


	def writeStart(iBike)

		sPathBase = self.get(:pathFileResponseBase, @@_defaultPathResponseBase)
		sPathBase += '/' if '/' != sPathBase[sPathBase.length() -1].chr

		sPathFile = sPathBase + 'start' + iBike.to_s

		self.writeTimeToFile(sPathFile)

	end # writeStart


	def writeStop(iBike)

		sPathBase = self.get(:pathFileResponseBase, @@_defaultPathResponseBase)
		sPathBase += '/' if '/' != sPathBase[sPathBase.length() -1].chr

		sPathFile = sPathBase + 'stop' + iBike.to_s

		self.writeTimeToFile(sPathFile)

	end # writeStop


	def writeTimeToFile(sPathFile, ulDuration = nil)

		# delete if exists
		if (File.exists?(sPathFile))

			# remove it first
			File.delete(sPathFile);

			if (File.exists?(sPathFile))
				raise 'KO:Can not delete file: ' << sPathFile
			end # if file still exists

		end # if trigger-file already exists

		if ulDuration.nil?
			sTime = Time.now.utc.to_f().to_s()
		else
			sTime = ulDuration.to_s()
		end # if custom time or current

		# attempt to create it and write current time
		oF = File.new(sPathFile, 'wb')
		oF.write(sTime)
		oF.close()

		if (!File.exists?(sPathFile))
			raise 'KO:Can not create file: ' << sPathFile
		end # if failed to create

		# make it writeable for all
		File.chmod(0666, sPathFile)

		self

	end # writeTimeToFile

end # SssSEMappClass


if !defined? SssSEMapp

	# Global singleton instance of SssSEMapp
	SssSEMapp = SssSEMappClass.new()

	# and launch
	EventMachine::run do

		SssSEMapp.run();

	end # EventMachine::run

	exit();

end # if first time file is read, just in case
