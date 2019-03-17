# Error Reporting

A simple method to make sure that errors get reported.

###### Code Block: Report Self Test Failure

``` ruby
def self.report_self_test_failure(message)
  if @dev
    p message
  else
    throw message
  end
end
```
