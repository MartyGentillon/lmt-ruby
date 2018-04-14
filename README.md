# Lmt

Lmt is a literate markdown tangle program for [literate programing](https://en.wikipedia.org/wiki/Literate_programming) in a slightly extended [Markdown](http://daringfireball.net/projects/markdown/syntax) syntax that is written in Ruby.

In literate programming, a program is contained within a prose essay describing the thinking which goes into the program.  The source code is then extracted from the essay using a program called tangle (this application).  The essay can also be formatted into a document for human consumption using a program called "weave".

For a more detailed description and example, see the program in [src/lmt.md](./src/lmt.md).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lmt'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install lmt

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/lmt.
