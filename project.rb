PACKAGE_FOO = {
  :name => "Foo", # must match a CMake Find*.cmake
  :components => "ComponentA ComponentB",
  :required => true,
  :optional_cmake => ""
};

PROJECT = 
{
  :name => "my_project", 
  :cmake_version => "2.6",

  :targets => 
  [{
    :name => "my_lib",
    :type => :shared, # (:static, :shared, :executable)
    :install => true, 
    :sources => "src_path", # Source root

    :common => 
    {
      :packages => [PACKAGE_FOO], # list of package dictionaries
      :definitions => [], # string-list of extra compiler definitions
      :include_dirs => [], # string-list of extra include dirs
      :link_dirs => [], # string-list of extra link-dirs
      :libs => [] # string-list of extra libs
    },
    # :apple, :linux and :windows platforms are optional 
    :apple => 
    {
      :packages => [], 
      :definitions => [], 
      :include_dirs => [],
      :link_dirs => [] 
    },
    :linux => 
    {
      :packages => [],
      :definitions => [],
      :include_dirs => [],
      :link_dirs => [] 
    }
  }]
}

