# Option Verification

Sadly neither Methadone nor Optparser offer mandatory option verification, so we have to add it ourselves.  (In the future, we will probably want to move this to a support library)  Doing so requires two methods, required and check_arguments

###### Code Block: Option Verification

``` ruby
def self.required(*options)
  @required_options = options
end

def self.check_arguments
  missing = @required_options.select{ |p| options[p].nil?}
  unless missing.empty?
    message = "Missing Required Argument(s): #{missing.join(', ')}"

    abort("#{message}\n\n#{opts.help()}")
  end
end
```
