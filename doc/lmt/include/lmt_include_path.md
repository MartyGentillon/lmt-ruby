# Include Path

This is the basic algorithm to look up an include on the include path.  If the file exists relative to the current file, it includes it.  If, not, it goes through the include path looking for the file.  When it finds it, it also calculates a relative path for the file from the current file.

###### Code Block: Includes

``` ruby
require 'pathname'
```

###### Code Block: Resolve Include

``` ruby
def resolve_include(file, current_file)
  include_file_loc = File.join(File.dirname(current_file), file)
  if File.exist?(include_file_loc)
    return [include_file_loc, file]
  end
  @include_path.each do |include_dir|
    include_file_loc = File.join(include_dir, file)
    if File.exist? (include_file_loc)
      relative_path = Pathname.new(include_file_loc).relative_path_from(File.dirname(current_file)).to_s
      return [include_file_loc, relative_path]
    end
  end
  throw "include file: #{file} not found from #{current_file} or in #{@include_path}"
end
```
