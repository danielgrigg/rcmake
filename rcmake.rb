require_relative 'project'
require 'find'
require 'fileutils'

SCHEMES = ['Debug', 'Release']#, 'MinSizeRel']
PLATFORMS = [:common, :linux, :apple, :windows]

PROJECT_SYMBOLS = [:name, :cmake_version, :targets]
TARGET_SYMBOLS = [:name, :type, :install, :sources].concat(PLATFORMS)
PLATFORM_SYMBOLS = [:packages, :definitions, :include_dirs, :link_dirs, :libs]
PACKAGE_SYMBOLS = [:name, :components, :version, :required, :optional_cmake]

def findFiles(dir, pattern)
  Enumerator.new do |yielder|
    Find.find(dir) do |path|
      if (!File.directory?(path) && 
          !%w{. ..}.include?(path) &&
          path =~ pattern)
        yielder.yield path
      end
    end
  end
end

def generatePlatform(platform, targetName)
platform[:include_dirs].map {|d| "include_directories(#{d})" }
.concat platform[:link_dirs].map {|d| "link_directories(#{d})" }
.concat platform[:definitions].map {|d| "add_definitions(-D#{d})" }
end

def generatePackages(platform, targetName)
  #TODO - properly support optional packages, this is half-arsed.
platform[:packages].map {|p| 
  result = "FIND_PACKAGE(#{p[:name]} "
  result << (p[:required] ?  "REQUIRED" : "OPTIONAL")
  result << " COMPONENTS #{p[:components]})\n"
  result << "include_directories(${#{p[:name]}_INCLUDE_DIRS})\n"
  result << "target_link_libraries(#{targetName} ${#{p[:name]}_LIBRARIES})"
}
.concat (platform[:libs] ? platform[:libs].map {|lib| 
  #todo general/release/debug libs
  "target_link_libraries(#{targetName} #{lib})" 
} : [])

end

def generateSources(sourceRoot)
  sources = ["set(SOURCES)"]
  sources.concat findFiles(sourceRoot, %r{\.cpp$}).map {|s|
    "set(SOURCES $\{SOURCES\} #{s})"
  }
  sources
end

def generateTarget(name, type)
  targetRules = {
    :shared => ->(name){"add_library(#{name} SHARED ${SOURCES})"},
    :static => ->(name){"add_library(#{name} STATIC ${SOURCES})"},
    :executable => ->(name){"add_executable(#{name} ${SOURCES})"}
  }
  installRules = {
    :shared => "lib",
    :static => "lib",
    :executable => "bin"
  }
  target = targetRules[type].call(name)
  target << "\ninstall (TARGETS #{name} DESTINATION #{installRules[type]})"
end

def generateDepends(name, dependsOn)
  "add_dependencies(#{name} #{dependsOn})" if dependsOn
end

def generateInstalls(sourceRoot, projectName)
  headers = []
  headers.concat findFiles(sourceRoot, %r{\.(h|hpp)$}).map {|h|
    "install (FILES #{h} DESTINATION include/#{projectName})"
  }
  
end

def generateSourceGroups(sourceRoot)
  findFiles(sourceRoot, %r{\.(cpp|h|hpp)$}).
    group_by {|s| File.dirname(s) }.
    map {|group,files| "source_group(#{group} FILES #{files.join ' '})" }
end

def generateCMake(project, platform, scheme)
  contents = []
  contents << "cmake_minimum_required(VERSION #{project[:cmake_version]})"
  contents << "project(#{project[:name]})"
  project[:targets].each {|x|
    contents.concat generatePlatform(x[:common], x[:name])
    contents.concat generatePlatform(x[platform], x[:name]) if x[platform]
    contents.concat generateSources(x[:sources])
    contents.concat generateSourceGroups(x[:sources])
    contents << generateTarget(x[:name], x[:type])
    contents << generateDepends(x[:name], x[:depends])
    contents.concat generatePackages(x[:common], x[:name])
    contents.concat generatePackages(x[platform], x[:name]) if x[platform]
    contents.concat generateInstalls(x[:sources], project[:name]) if x[:install]
  }
  contents
end

def hostPlatform
  :unknown_platform unless RUBY_PLATFORM.downcase =~ /(darwin|mswin|linux)/
    {'darwin' => :apple, 'mswin' => :windows, 'linux' => :linux}[$1]
end

cmd = ARGV.shift # get the subcommand
case cmd
when "--help"
  banner = "Usage: #{__FILE__} [cmake_options]"
  abort banner
when "clean" 
  FileUtils.rm_rf 'build'
else
  platform = hostPlatform
  unless PLATFORMS.include? platform
    abort("Unknown platform: #{platform} [#{PLATFORMS}]") 
  end
  ARGV.unshift cmd
  cmakeArgs = ARGV
  puts cmakeArgs

  rootDir = Dir.pwd
  SCHEMES.each {|scheme|
    buildPath = "build/#{platform}-#{scheme.downcase}"
    cmakeContents = generateCMake(PROJECT, hostPlatform, scheme)
    FileUtils.rm "#{buildPath}/CMakeCache.txt", :force=>true
    FileUtils.mkdir_p buildPath unless Dir.exists? buildPath
    File.open("CMakeLists.txt", "w") {|f| f.puts cmakeContents }
    FileUtils.cd buildPath
    system("cmake -DCMAKE_BUILD_TYPE=#{scheme} #{cmakeArgs.join ' '} ../..")
    FileUtils.cd rootDir
  }
end

# dependencies
