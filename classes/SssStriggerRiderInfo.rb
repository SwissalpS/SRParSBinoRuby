
require 'SssStriggerBase.rb'
require 'SssSapp.rb'

# Sets name 'n' and category 'c'.
# read SssStriggerBase for ruby-side-usage.
# instantiate seperate instance and filename for each BIKE
#
# Usage from cli :
# 	echo -e 'name\tcategory' >> triggers/rider.info
# Usage from php:
#	sString = "name\tcategory";
#	or
#	sString = 'name' . chr(9) . 'category'
#	file_put_contents('triggers/rider.info', sString, FILE_APPEND);

class SssStriggerRiderInfo < SssStriggerBase

	@iBike = 0; attr_accessor :iBike

	def initialize(sPathFile = nil, iBike = nil)

		sPathFile = 'triggers/rider.info' if sPathFile.nil?
		iBike = 0 if iBike.nil?

		super(sPathFile)

		@iBike = iBike

	end # initialize


	# send 'n' and 'c' commands to SBAMFDD
	# controller calls hasData? if yes controller calls process
	def process()

		# filter false alarm
		return super if @sBuffer.nil?

		# split by tab
		sName, sCategory, sID = @sBuffer.split("\t")
		sName = '' if sName.nil?
		sCategory = '' if sCategory.nil?
		sID = '0' if sID.nil?

		sName = self.translateName(sName)
		sCategory = self.translateCategory(sCategory)

		SssSapp.setCurrentRiderInfo(sName, sCategory, sID.to_i, @iBike)

		# clear buffer and return self
		super

	end # process


	def translateCategory(sCategory = nil)

		return nil if sCategory.nil?

		sOut = ''
		bMultibyte = false

		sCategory.each_byte do |iByte|

			if bMultibyte

				bMultibyte = false

				if (184 == iByte)

					sOut << self.translateCategory('o')

					next

				end # if diametre

				if (132 == iByte)

					sOut << self.translateCategory('AE')

					next

				end # if AE

				if (130 == iByte)

					sOut << self.translateCategory('A')

					next

				end # if A circumflex

				if ((136..138).member? iByte)

					sOut << self.translateCategory('E')

					next

				end # if E grave, circumflex and aigue

				if (150 == iByte)

					sOut << self.translateCategory('OE')

					next

				end # if OE

				if (156 == iByte)

					sOut << self.translateCategory('UE')

					next

				end # if UE

				if (164 == iByte)

					sOut << self.translateCategory('ae')

					next

				end # if ae

				if (167 == iByte)

					sOut << self.translateCategory('c')

					next

				end # if cedille

				if ((168..171).member? iByte)

					sOut << self.translateCategory('e')

					next

				end # if e grave, e aigue, ee, e circumflex

				if ((174..175).member? iByte)

					sOut << self.translateCategory('i')

					next

				end # if i circumflex, ie

				if (177 == iByte)

					sOut << self.translateCategory('n')

					next

				end # if n tilde

				if (182 == iByte)

					sOut << self.translateCategory('oe')

					next

				end # if oe

				if (180 == iByte)

					sOut << self.translateCategory('o')

					next

				end # if o circumflex

				if (188 == iByte)

					sOut << self.translateCategory('ue')

					next

				end # if ue

			else

				# single or first byte

				if (195 == iByte)

					bMultibyte = true
					next

				end # if multibyte char

				if ((48..57).member? iByte)

					sOut << (iByte - 48).chr

					next

				end # if number

				if ((65..90).member? iByte)

					sOut << (iByte - 55).chr

					next

				end # if uppercase

				if ((97..122).member? iByte)

					sOut << (iByte - 61).chr

					next

				end # if lowercase

				if (32 == iByte)

					sOut << 62.chr

					next

				end # if space

			end # if in multibyte or single byte character

		end # loop each byte

		return nil if 0 == sOut.length

		return sOut

	end # translateCategory


	def translateName(sName = nil)

		return nil if sName.nil?

		sOut = ''
		bMultibyte = false

		sName.each_byte do |iByte|

		# TODO: use a hash to map
		if bMultibyte

			bMultibyte = false

				if (184 == iByte)

					sOut << 68.chr

					next

				end # if diametre

				if (132 == iByte)

					sOut << 71.chr

					next

				end # if AE

				if (130 == iByte)

					sOut << 72.chr

					next

				end # if A circumflex

				if (137 == iByte)

					sOut << 73.chr

					next

				end # if E aigue

				if (136 == iByte)

					sOut << 74.chr

					next

				end # if E grave

				if (138 == iByte)

					sOut << 75.chr

					next

				end # if E circumflex

				if (150 == iByte)

					sOut << 76.chr

					next

				end # if OE

				if (156 == iByte)

					sOut << 77.chr

					next

				end # if UE

				if (164 == iByte)

					sOut << 78.chr

					next

				end # if ae

				if (167 == iByte)

					sOut << 79.chr

					next

				end # if cedille

				if (171 == iByte)

					sOut << 80.chr

					next

				end # ee

				if (169 == iByte)

					sOut << 81.chr

					next

				end # if e aigue


				if (168 == iByte)

					sOut << 82.chr

					next

				end # if e grave

				if (170 == iByte)

					sOut << 83.chr

					next

				end # if e circumflex

				if (175 == iByte)

					sOut << 84.chr

					next

				end # if ie

				if (174 == iByte)

					sOut << 85.chr

					next

				end # if i circumflex

				if (177 == iByte)

					sOut << 86.chr

					next

				end # if n tilde

				if (182 == iByte)

					sOut << 87.chr

					next

				end # if oe

				if (180 == iByte)

					sOut << 88.chr

					next

				end # if o circumflex

				if (188 == iByte)

					sOut << 89.chr

					next

				end # if ue

			else

				# single or first byte

				if (195 == iByte)

					bMultibyte = true
					next

				end # if multibyte char

				if ((48..57).member? iByte)

					sOut << (iByte - 48).chr

					next

				end # if number

				if ((65..90).member? iByte)

					sOut << (iByte - 55).chr

					next

				end # if uppercase

				if ((97..122).member? iByte)

					sOut << (iByte - 61).chr

					next

				end # if lowercase

				if ((40..41).member? iByte)

					sOut << (iByte + 22).chr

					next

				end # if ()

				if ((45..47).member? iByte)

					sOut << (iByte + 19).chr

					next

				end # if -./

				if (58 == iByte)

					sOut << 67.chr

					next

				end # if :

				if (60 == iByte)

					sOut << 69.chr

					next

				end # if <

				if (62 == iByte)

					sOut << 70.chr

					next

				end # if >

				if (91 == iByte)

					sOut << 90.chr

					next

				end # if [

				if (93 == iByte)

					sOut << 91.chr

					next

				end # if ]

				if (63 == iByte)

					sOut << 92.chr

					next

				end # if ?

				if (64 == iByte)

					sOut << 93.chr

					next

				end # if @

				if (32 == iByte)

					sOut << 94.chr

					next

				end # if space

			end # if in multibyte or single byte character

		end # if multibyte or single

		return nil if 0 == sOut.length

		return sOut

	end # translateName

end # SssStriggerStop
