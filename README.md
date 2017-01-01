# snowy

"snowy" is an identicon implements with the snow crystal motif.

  * package name: snowy
  * version: 0.2
  * software quality: EXPERIMENTAL
  * license: BSD-2-clause License
  * author: dearblue <dearblue@users.noreply.github.com>
  * report issue to: <https://github.com/dearblue/ruby-snowy/issues/>
  * dependency ruby: ruby-2.1+
  * dependency ruby gems: (none)
  * dependency library: (none)
  * bundled external C library: (none)

![snowy demonstration](snowy-demo.png)



## How to usage

``` ruby:ruby
require "snowy"
require "zlib"

str = "abcdefg"
driver = :ruby # or :cairo (when installed ``cairo'' gem)
angle = 5 # by any degree number
pngdata = Snowy.generate_to_png(str, size: 256, angle: angle, driver: driver)
File.binwrite("snowy.png", pngdata)
```


## Demonstration with web browser

``` shell
$ ruby snowy-demo.rb -p 4567
```

And, access to http://localhost:4567/ on web browser.
