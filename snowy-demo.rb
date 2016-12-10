#!ruby

require "sinatra"
require "haml"
require_relative "lib/snowy.rb"
#require_relative "lib/snowy/cairo.rb"

if $-d
  require "sinatra/reloader"
  also_reload "lib/snowy/common.rb"
  also_reload "lib/snowy.rb"
  #also_reload "lib/snowy/cairo.rb"
end

get "/" do
  haml <<-HAML
!!! 5
%title Demonstration for snowy
:css
  body
  {
    background: url("snowy/#{"%08X" % (0xeef00000 | rand(0x100000))}.png?size=256&angle=-10&extendcap=true"); 
  }

%div{style: "text-align: center"}
  %div{style: "padding: 1em; font-size: 200%"}
    "snowy" is an identicon implements with the snow crystal motif.
  %div
    #{20.times.map { %(<img src="snowy/%08X.png?size=131&angle=5&extendcap=true" alt="">) % [rand(0xffffffff)] }.join}
  %div
    #{20.times.map { %(<img src="snowy/%08X.png?size=131&angle=0&extendcap=true" alt="">) % [rand(0x00100000) | 0x69f00000] }.join}
  HAML
end

get "/snowy/*.png" do |id|
  id = id.hex
  size = (params["size"] || 128).to_i
  size = [32, size, 4096].sort[1]
  cap = (params["nocap"]) ? false : true
  angle = (params["angle"] || 0).to_i
  if params["monotone"]
    id = (id & 0x000fffff) | 0x9cf00000
  end
  extendcap = (params["extendcap"] || "false") == "false" ? false : true
  bin = Snowy.generate_to_png(id, size: size, cap: cap, extendcap: extendcap, angle: -angle)

  status 200
  headers "Content-Type" => "image/png"
  body bin
end
