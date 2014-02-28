
YES = true if !defined? YES
NO = false if !defined? NO

require 'eventmachine'

##
# Baseclass for trigger-file-observers.
# Needs to be subclassed to be usefull
#
# Usage:
# 	oTrigger = SssStriggerSubclass::new('path/to/file')
# 	while(bLoop) do
#		oTrigger.process() if oTrigger.hasData?()
# 	end
# 	oTrigger.dealloc()

module SssSEMfileWatch

	def file_modified
		puts "#{path} modified"
	end

	def file_moved
		puts "#{path} moved"
	end

	def file_deleted
		puts "#{path} deleted"
	end

	def unbind
		puts "#{path} monitoring ceased"
	end

end # SssSEMfileWatch

module SssSEMfileWatchIO

	def notify_readable
		begin
			header = @io.readline
		rescue EOFError
			detach
		end
	end

	def unbind
		puts "monitoring ceased"
		data = @io.read
		puts 'last spurt:  '
		puts data
	end

end # SssSEMfileWatchIO


class SssSEMtriggerBase < EventMachine::Connection
#	include SssSEMfileWatch
#	include SssSEMfileWatchIO

	# count incoming bytes
	@iCountIncoming; attr_reader :iCountIncoming

	@iTruncateAtSize; attr_reader :iTruncateAtSize

	# IO-object of trigger-File
	@oFile; attr_reader :oFile
	# corresponding EventMachine:: object
	@oEMwatcher; attr_reader  :oEMwatcher

	# buffer holding incoming bytes
	@sBuffer; attr_reader :sBuffer

	# path and filename to the trigger-file
	@sPathFile; attr_reader :sPathFile


	# create a new watcher for file sPathFile
	def initialize(sPathFile)

		@iTruncateAtSize = 1024

		@oFile = nil

		@sBuffer = ''

		@sPathFile = sPathFile

		self.truncate()

	end # initialize


	# clean destruction
	def dealloc()

		self.truncate(NO);

		nil;

	end # dealloc


	# reads new bytes into @sBuffer.<br>
	# returns bool<br>
	# calls #observeSize()
	def hasData?()
#puts 'hasData?'
		begin

			sRead = @oFile.read_nonblock(1024);

		rescue Exception => e

			sRead = nil;

		end

		if (nil == sRead)

			return NO;

		else

			@sBuffer.concat(sRead);

			self.observeSize(sRead.length());

			return YES;

		end # if got data

	end # hasData?

	# EventMachine callback
	def notify_readable

		self.process() if self.hasData?

	end # notify_readable

	# EventMachine callback
	def unbind
		puts 'monitoring ceased'
		sRead = @oFile.read()
		puts 'last spurt:  '
		puts sRead
	end # unbind

	# make sure file size stays limited<br>
	# called by #hasData?()
	def observeSize(iLen)

		@iCountIncoming += iLen;

		# if time to truncate file
		self.truncate() if (@iCountIncoming > @iTruncateAtSize)

	end # observeSize
	protected :observeSize


	# subclass specific
	# controller calls hasData? if yes controller calls process
	def process()

		# clear buffer
		@sBuffer = ''

		# return self for chainable syntax
		self

	end # process


	# define the maximal byte-size the trigger file may reach (approx.)
	def setTruncateAtSize(iNewSize = 1024)

		if (nil == iNewSize)
			iNewSize = 1024;
		end # if nil passed

		iNewSize = iNewSize.abs;

		@iTruncateAtSize = iNewSize;

		self

	end # setTruncateAtSize


	# delete trigger file and recreate it<br>
	# called by ::new(), #observeSize() and #dealloc
	def truncate(bRecreate = YES)

		if !@oFile.nil?
			@oEMwatcher.detach() if !@oEMwatcher.nil?
			@oEMwatcher = nil

			@oFile.close()
		end # if 'connected'

		@iCountIncoming = 0;

		# delete if exists
		if (File.exists?(@sPathFile))

			# remove it first
			File.delete(@sPathFile);

			if (File.exists?(@sPathFile))
				raise 'Can not delete file: ' << @sPathFile;
			end # if file still exists

		end # if trigger-file already exists

		# if only need to delete (dealloc)
		return self if (NO == bRecreate)

		# attempt to create it
		oF = File.new(@sPathFile, 'wb'); oF.close;

		if (!File.exists?(@sPathFile))
			raise 'Can not create file: ' << @sPathFile;
		end # if failed to create

		# make it writeable for all (only owner may read)
		File.chmod(0622, @sPathFile)

		# and open for reading
		rF = IO.sysopen(@sPathFile, 'rb');
		@oFile = IO.new(rF, 'rb');

		# attach to EventMachine
		# Expects a class-name or module-name, not an object even if it does inherit
		#@oEMwatcher = EventMachine.watch(@oFile, self)
		#@oEMwatcher.notify_readable = true

		self

	end # truncate
	protected :truncate


	alias truncateAtSize :iTruncateAtSize
	alias truncateAtSize= :setTruncateAtSize

end # SssSEMtriggerBase
