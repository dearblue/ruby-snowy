#!ruby

require "optparse"

port = 4567
OptionParser.new(nil, 12, " ").instance_exec do
  on("-p port", "declare for http binding port (DEFAULT: #{port})") { |x| port = x.to_i }
  parse!
end

require "webrick"
require_relative "lib/snowy"
begin
  require "cairo"
  require_relative "lib/snowy/cairo"
  NOCAIRO = false
rescue LoadError
  NOCAIRO = true
end

RANDMAX = 1 << 48

def notfound(req, res)
  res.body = <<-HTML
<!DOCTYPE html>
<title>404 NOT FOUND</title>
<p>Requested resource is not found</p>
<pre>#{req.path}
  HTML
  res.status = 404
  res.content_type = "text/html; charset=utf-8"

  nil
end

s = WEBrick::HTTPServer.new(BindAddress: "0.0.0.0", Port: port)

s.mount_proc("/snowy/") do |req, res|
  next notfound(req, res) unless req.path =~ %r(^/snowy/([0-9a-f]+)(?:\.png)?$)i

  id = $1
  params = req.query

  id = id.hex
  size = (params["size"] || 128).to_i
  size = [32, size, 4096].sort[1]
  cap = (params["nocap"]) ? false : true
  angle = (params["angle"] || 0).to_i
  color = params["color"]
  if color.nil? || color.empty?
    color = nil
  else
    color = ((Integer(color) & 0x00ffffff) << 8) | 0xff
  end
  outline = params["outline"]
  if outline.nil? || outline.empty?
    outline = nil
  else
    outline = ((Integer(outline) & 0x00ffffff) << 8) | 0xff
  end
  if params["monotone"]
    id = (id & 0x000fffff) | 0x9cf00000
  end
  case params["driver"]
  when "cairo"
    driver = NOCAIRO ? :ruby : :cairo
  else
    driver = :ruby
  end
  extendcap = (params["extendcap"] || "false") == "false" ? false : true
  bin = Snowy.generate_to_png(id, size: size, cap: cap, extendcap: extendcap,
                              angle: -angle, color: color, outline: outline,
                              driver: driver)

  res.status = 200
  res.content_type = "image/png"
  res.body = bin
end

s.mount_proc("/") do |req, res|
  next notfound(req, res) unless req.path == "/"

  params = req.query
  if String(params["driver"]).casecmp("cairo") == 0
    driver = "cairo"
  else
    driver = "ruby"
  end

  res.body = <<-HTML
<!DOCTYPE html>
<title>Demonstration for snowy</title>
<style type=text/css>
body
{
  background: url("snowy/#{"%08X" % rand(RANDMAX)}.png?size=256&angle=-10&extendcap=true&color=0xf0f0f8&driver=cairo");
}
</style>

<div style=text-align:center>
  <div style=padding:1em;font-size:200%>
    "snowy" is an identicon implements with the snow crystal motif.
  </div>
  <div>
    #{20.times.map { %(<img src="snowy/%08X.png?size=131&angle=5&extendcap=true&driver=#{driver}" alt="">) % rand(RANDMAX) }.join}
  </div>
  <div>
    #{20.times.map { %(<img src="snowy/%08X.png?size=131&angle=0&extendcap=true&color=0xb0c8f8&driver=#{driver}" alt="">) % rand(RANDMAX) }.join}
  </div>
</div>
  HTML
end

trap("INT"){ s.shutdown }
s.start
