# Lmt

Lmt is a literate markdown tangle and weave program for [literate programing](https://en.wikipedia.org/wiki/Literate_programming) in a slightly extended [Markdown](http://daringfireball.net/projects/markdown/syntax) syntax that is written in Ruby.

In literate programming, a program is contained within a prose essay describing the thinking which goes into the program.  The source code is then extracted from the essay using a program called tangle (this application).  The essay can also be formatted into a document for human consumption using a program called "weave".

For a more detailed description and example, see the tangle program in [src/lmt.lmd](./src/lmt.lmd) and the weave program in [src/lmw.lmd](./src/lmw.lmd).

The weaved output may be found in [doc/lmt.md](./doc/lmt.md) and [doc/lmw.md](./doc/lmw.md)

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

The tangle program takes input files and produces tangled output files.  It is used as follows:

``` bash
bin/lmt --file {input file} --output {tangled destination}
```

The weave program is similar but produces weaved output files.  It does not recurse down include statements, and so will need to be run independently for each included file.  An example usage:

``` bash
bin/lmw --file {input file} --output [weaved destination]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

Remember, this is a bundler app, and to rum it without installing, you must use the `bundle exec` command. As an example, the self-tangling command for development is:

``` bash
bundle exec ruby bin/lmt --file src/lmt.lmd --output bin/lmt
```

To test the weave you can use the following command which will weave the weaver and write it to the doc directory.

``` bash
bundle exec ruby bin/lmt --file src/lmt.lmd --output bin/lmt; bundle exec ruby bin/lmw --file src/lmw.lmd --output doc/lmw.md
```

## Prior Art

Some related and similar tools that the reader might find interesting:

* <<https://github.com/driusan/lmt>>
* <<https://github.com/rebcabin/tangledown>>
* <<https://github.com/vlead/literate-tools>>
* <<https://github.com/zyedidia/Literate>>
* <<https://github.com/mqsoh/knot>>
* <<https://fsprojects.github.io/FSharp.Formatting/sidemarkdown.html>>
* <<https://github.com/richorama/literate>>

## Contributing

Bug reports and pull requests are welcome on GitHub at <<https://github.com/MartyGentillon/lmt-ruby>>.
