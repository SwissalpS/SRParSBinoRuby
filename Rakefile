require 'rubygems'
require 'rdoc'
require 'rdoc/task'

SssSdocDirAlt = 'doc_rake'
SssSdocDir = 'doc'
SssSdocAssetsDir = 'docAssets'
SssSdebianDocInstallDir = '/var/www/doc/SRParSBinoRuby'

task :default => [:SssSrebuildDoc, :SssSgoodbye]

task :SssSrebuildDoc => [:SssSremoveDoc, :SssSbuildDoc]

task :SssSremoveDoc do |t|
#	puts 'about to remove ' << SssSdocDir
	FileUtils.rm_rf(SssSdocDir)
	puts 'deleted HTML-docs in ' << SssSdocDir
end;

task :SssSbuildDoc do |t|
	`rdoc --all -E rbs=rb -t SRParSBinoRuby -m README -o #{SssSdocDir} -x #{SssSdocDirAlt} -x Rakefile -x created.rid -x #{SssSdocAssetsDir} -x triggers -x onlineIDs -x frameBin`
	
	#FileUtils::cp(SssSdocAssetsDir + '/', SssSdocDir + '/')
	`cp #{SssSdocAssetsDir}/* #{SssSdocDir}/;`
end

task :SssSbuildAndUpload => [:SssSrebuildDoc, :SssSupload, :SssSgoodbye]

task :SssSupload do |t|
	puts `rsync -avvxz --del #{SssSdocDir}/ swissnet@digialp.com:/home/swissnet/public_html/SkyBIKE/SRParSBinoRubyDoc/;`
	puts `rsync -avvxz --del .git/ swissnet@digialp.com:/home/swissnet/public_html/SkyBIKE/SRParSBinoRuby.git/;`
end

task :installDocDebian => [:SssSrebuildDoc, :SssSinstallDocDebian]

task :SssSinstallDocDebian do |t|
	FileUtils::rm_rf(SssSdebianDocInstallDir)
	`mkdir -p #{SssSdebianDocInstallDir};`
	`cp -r #{SssSdocDir}/* #{SssSdebianDocInstallDir};`
end

task :SssSgoodbye do |t|
	puts 'Done.'
end


# looks promising, but does not yet work on OSX
RDoc::Task.new(:buildDoc) do |t|
	t.rdoc_dir = SssSdocDirAlt
	t.title = "SRParSBinoRuby"
	t.main = "README.md"
#       t.rdoc_files.include('README*')
#       t.rdoc_files.include('lib/**/*.rb')
#       t.rdoc_files.include('**/*.rbs')
        t.rdoc_files = FileList['*.rbs', 'lib/**/*.rb', '*.rb']
# rdoc_options is unknown
#	t.rdoc_options << '-x' << SssSdocDir
# these don't seem to work either
	t.rdoc_files.exclude(SssSdocDir) # + '/*')
#	t.rdoc_files.exclude('**/*.html')
end
