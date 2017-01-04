require "zlib"
require "digest/md5"

module Snowy
  module Extentions
    refine Numeric do
      unless 0.respond_to?(:clamp)
        def clamp(min, max)
          case
          when self < min
            return min
          when self > max
            return max
          else
            return self
          end
        end
      end
    end

    refine Integer do
      def get_red
        0xff & (self >> 24)
      end

      def get_green
        0xff & (self >> 16)
      end

      def get_blue
        0xff & (self >> 8)
      end

      def get_alpha
        0xff & self
      end

      def pack_rgb
        [self >> 24, self >> 16, self >> 8].pack("C3")
      end

      def pack_rgba
        [self].pack("N")
      end
    end
  end

  using Extentions


  def self.rgb(r, g, b, a = 1.0)
    Color.new(RGB.new(r, g, b), a)
  end

  def self.cmy(c, m, y, a = 1.0)
    Color.new(CMY.new(c, m, y), a)
  end

  def self.hsl(h, s, l, a = 1.0)
    Color.new(HSL.new(h, s, l), a)
  end

  def self.hsb(h, s, b, a = 1.0)
    Color.new(HSB.new(h, s, b), a)
  end

  class Color
    attr_reader :color, :alpha

    def initialize(color, alpha = 1.0)
      @color = color.to_rgb
      @alpha = alpha.to_f
    end

    def red
      color.red
    end

    def green
      color.green
    end

    def blue
      color.blue
    end

    def red8
      color.red8
    end

    def green8
      color.green8
    end

    def blue8
      color.blue8
    end

    def alpha8
      (alpha.clamp(0, 1) * 255).round
    end

    def to_hsl
      color.to_hsl
    end

    def pack_rgb
      color.to_a(8).pack("C*")
    end

    def pack_rgba
      [*color.to_a(8), (alpha.clamp(0, 1) * 255).round].pack("C*")
    end
  end

  class RGB
    attr_reader :r, :g, :b

    def initialize(r, g, b)
      @r = r.to_f
      @g = g.to_f
      @b = b.to_f
    end

    def r=(r)
      @r = r.to_f
    end

    def g=(g)
      @g = g.to_f
    end

    def b=(b)
      @b = b.to_f
    end

    #
    # @overload to_a
    # @overload to_a(true)
    # @overload to_a(8)
    # @overload to_a(16)
    #
    # @return [Array] color primitives as RGB
    #
    def to_a(norm = nil)
      return [r, g, b] unless norm

      case norm
      when true, 8
        max = (1 << 8) - 1
      when 16
        max = (1 << 16) - 1
      else
        raise ArgumentError
      end

      [(r.clamp(0, 1) * max).round,
       (g.clamp(0, 1) * max).round,
       (b.clamp(0, 1) * max).round]
    end

    alias red r
    alias red= r=
    alias green g
    alias green= g=
    alias blue b
    alias blue= b=

    def red8
      (r.clamp(0, 1) * 255).round
    end

    def green8
      (g.clamp(0, 1) * 255).round
    end

    def blue8
      (b.clamp(0, 1) * 255).round
    end

    def inspect
      %(#<#{self.class} red=#{r}, green=#{g}, blue=#{b}>)
    end

    def pretty_inspect(q)
      q.text inspect
    end

    def to_int8
      r = (@r.clamp(0, 1) * 255).round
      g = (@g.clamp(0, 1) * 255).round
      b = (@b.clamp(0, 1) * 255).round
      (r << 16) | (g << 8) | b
    end

    alias to_i to_int8

    def to_hex8
      "%06x" % to_int8
    end

    alias to_hex to_hex8

    alias to_rgb dup

    def to_cmy
      CMY.new(1 - r, 1 - g, 1 - b)
    end

    def to_hsb
      synthesis_for HSB
    end

    def to_hsl
      synthesis_for HSL
    end

    def synthesis_for(type)
      (min, *, max) = [r, g, b].sort
      case min
      when max
        hue = nil
      when b
        hue = 60 * (g - r) / (max - min) + 60
      when r
        hue = 60 * (b - g) / (max - min) + 180
      when g
        hue = 60 * (r - b) / (max - min) + 300
      end

      type.synthesis hue, max, min
    end

    def RGB.synthesis(hue, max, min)
      return new max, max, max unless hue

      hue %= 360
      delta = max - min
      hue1 = hue % 120
      hue1 = 120 - hue1 if hue1 > 60
      mid = min + delta * hue1 / 60.0
      case (hue / 60).to_i
      when 0; new max, mid, min
      when 1; new mid, max, min
      when 2; new min, max, mid
      when 3; new min, mid, max
      when 4; new mid, min, max
      else  ; new max, min, mid
      end
    end
  end

  class CMY
    attr_reader :c, :m, :y

    def initialize(c, m, y)
      @c = c.to_f
      @m = m.to_f
      @y = y.to_f
    end

    def c=(c)
      @c = c.to_f
    end

    def m=(m)
      @m = m.to_f
    end

    def y=(y)
      @y = y.to_f
    end

    alias cyan c
    alias cyan= c=
    alias mathenta m
    alias mathenta= m=
    alias yellow y
    alias yellow= y=

    def to_a
      [c, m, y]
    end

    def inspect
      %(#<#{self.class} cyan=#{c}, mathenta=#{m}, yellow=#{y}>)
    end

    def pretty_inspect(q)
      q.text inspect
    end

    def to_rgb
      RGB.new(1 - c, 1 - m, 1 - y)
    end

    alias to_cmy dup

    def to_hsb
      to_rgb.to_hsb
    end

    def to_hsl
      to_rgb.to_hsl
    end

    def synthesis_for(type)
      to_rgb.synthesis_for(type)
    end

    def self.synthesis(hue, max, min)
      RGB.synthesis(hue, max, min).to_cmy
    end
  end

  # 円錐モデル
  class HSB
    attr_reader :h, :s, :b

    def initialize(h, s, b)
      @h = h ? h.to_f : nil
      @s = s.to_f
      @b = b.to_f
    end

    def h=(h)
      @h = h ? h.to_f : nil
    end

    def s=(s)
      @s = s.to_f
    end

    def b=(b)
      @b = b.to_f
    end

    alias hue h
    alias hue= h=
    alias saturation s
    alias saturation= s=
    alias brightness b
    alias brightness= b=

    def to_a
      [h, s, b]
    end

    def inspect
      %(#<#{self.class} hue=#{h.inspect}, saturation=#{s}, brightness=#{b}>)
    end

    def pretty_inspect(q)
      q.text inspect
    end

    def to_rgb
      synthesis_for RGB
    end

    def to_cmy
      synthesis_for CMY
    end

    alias to_hsb dup

    def to_hsl
      synthesis_for HSL
    end

    def synthesis_for(type)
      type.synthesis h, b, b - s
    end

    def HSB.synthesis(hue, max, min)
      new hue, max - min, max
    end
  end

  # 双円錐モデル
  class HSL
    attr_reader :h, :s, :l

    def initialize(h, s, l)
      @h = h ? h.to_f : nil
      @s = s.to_f
      @l = l.to_f
    end

    def h=(h)
      @h = h ? h.to_f : nil
    end

    def s=(s)
      @s = s.to_f
    end

    def l=(l)
      @l = l.to_f
    end

    alias hue h
    alias hue= h=
    alias saturation s
    alias saturation= s=
    alias luminance l
    alias luminance= l=

    def to_a
      [h, s, l]
    end

    def inspect
      %(#<#{self.class} hue=#{h.inspect}, saturation=#{s}, luminance=#{l}>)
    end

    def pretty_inspect(q)
      q.text inspect
    end

    def to_rgb
      synthesis_for RGB
    end

    def to_cmy
      synthesis_for CMY
    end

    def to_hsb
      synthesis_for HSB
    end

    alias to_hsl dup

    def synthesis_for(type)
      ss = s / 2.0
      type.synthesis h, l + ss, l - ss
    end

    def HSL.synthesis(hue, max, min)
      new hue, max - min, (max + min) / 2
    end
  end

  class Matrix
    attr_reader :matrix

    def self.[](matrix)
      case matrix
      when self
        matrix
      else
        new matrix
      end
    end

    def initialize(mat = nil)
      @matrix = [[nil, nil, nil], [nil, nil, nil], [nil, nil, nil]]

      if mat
        load mat
      else
        reset
      end
    end

    def initialize_copy(mat)
      @matrix = [[nil, nil, nil], [nil, nil, nil], [nil, nil, nil]]
      load mat
    end

    def reset
      load [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    end

    def load(mat)
      case mat
      when Matrix
        matrix[0][0, 3] = mat.matrix[0]
        matrix[1][0, 3] = mat.matrix[1]
        matrix[2][0, 3] = mat.matrix[2]
      when Array
        if mat.size == 3 &&
            mat[0].kind_of?(Array) && mat[0].size == 3 &&
            mat[1].kind_of?(Array) && mat[1].size == 3 &&
            mat[2].kind_of?(Array) && mat[2].size == 3
          matrix[0][0, 3] = mat[0]
          matrix[1][0, 3] = mat[1]
          matrix[2][0, 3] = mat[2]
        else
          if mat.size == 9
            matrix[0][0, 3] = mat[0, 3]
            matrix[1][0, 3] = mat[3, 3]
            matrix[2][0, 3] = mat[6, 3]
          else
            raise ArgumentError, "wrong element number (given #{mat.size} elements, expect 9 elements)"
          end
        end
      else
        raise ArgumentError, "wrong argument type (expect Snowy::Matrix or Array)"
      end

      self
    end

    def mult(mat)
      mult! self.class[mat].matrix
    end

    def mult!(mat)
      3.times do |i|
        m0 = matrix[i]
        mm = m0.dup
        3.times do |j|
          m0[j] = mm[0] * mat[0][j] +
                  mm[1] * mat[1][j] +
                  mm[2] * mat[2][j]
        end
      end

      self
    end

    def transform2(x, y, w = 1)
      mx = matrix[0]
      my = matrix[1]
      [x * mx[0] + y * mx[1] + w * mx[2],
       x * my[0] + y * my[1] + w * my[2]]
    end

    alias transform transform2

    def transform3(x, y, w = 1)
      mx = matrix[0]
      my = matrix[1]
      mw = matrix[2]
      [x * mx[0] + y * mx[1] + w * mx[2],
       x * my[0] + y * my[1] + w * my[2],
       x * mw[0] + y * mw[1] + w * mw[2]]
    end

    def translate(dx, dy, dw = 1)
      mult!([[1, 0, dx], [0, 1, dy], [0, 0, dw]])
    end

    def scale(ax, ay, aw = 1)
      mult!([[ax, 0, 0], [0, ay, 0], [0, 0, aw]])
    end

    def rotate(rad)
      cos = Math.cos(rad)
      sin = Math.sin(rad)
      mult!([[cos, -sin, 0], [sin, cos, 0], [0, 0, 1]])
    end
  end

  module PNG
    TYPE_GRAYSCALE = 0
    TYPE_RGB = 2
    TYPE_PALETTE = 3
    TYPE_GRAYSCALE_ALPHA = 4
    TYPE_RGBA = 6

    def self.export(out = "".b)
      Exporter.new(out)
    end

    class Exporter < Struct.new(:out, :width, :height)
      BasicStruct = superclass

      def initialize(out = "".b)
        super
        out << [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].pack("C*")
        self
      end

      def header(width, height, colorbits, colortype)
        self.width = width
        self.height = height

        ##  0     1,2,4,8,16  immediate grayscale sample
        ##  2     8,16        immediate RGB sample
        ##  3     1,2,4,8     palette sample (need PLTE chunk)
        ##  4     8,16        immediate grayscale sample with alpha
        ##  6     8,16        immediate RGB sample with alpha
        Chunk.pack_to(out, "IHDR", [width, height, colorbits, colortype, 0, 0, 0].pack("NNCCCCC"))
        self
      end

      def palette(palette, alpha: false)
        rgb = palette.reduce("".b) { |a, e|
          a << e.pack_rgb
        }
        PNG::Chunk.pack_to(out, "PLTE", rgb)

        if alpha
          trns = palette.reduce([]) { |a, e| a << e.alpha8 }
          PNG::Chunk.pack_to(out, "tRNS", trns.pack("C*"))
        end

        self
      end

      def text(keyword, text)
        ## iTXt
        ##    Keyword:             1-79 bytes (character string)
        ##    Null separator:      1 byte
        ##    Compression flag:    1 byte
        ##    Compression method:  1 byte
        ##    Language tag:        0 or more bytes (character string)
        ##    Null separator:      1 byte
        ##    Translated keyword:  0 or more bytes
        ##    Null separator:      1 byte
        ##    Text:                0 or more bytes
        PNG::Chunk.pack_to(out, "iTXt", [keyword, 0, 0, text].pack("a*xCCxxa*"))
        self
      end

      def idat(pixels, level: Zlib::DEFAULT_COMPRESSION)
        scanline = ->(lines, line) {
          lines << "\0" << line
        }
        lines = height.times.reduce("".b) { |a, h|
          line = pixels.byteslice(h * width, width)
          scanline[a, line]
        }
        PNG::Chunk.pack_to(out, "IDAT", Zlib.deflate(lines, level))
        self
      end

      def iend
        PNG::Chunk.pack_to(out, "IEND", "")
        self
      end
    end

    module Chunk
      def self.pack_to(io, code, chunk)
        crc = Zlib.crc32(chunk, Zlib.crc32(code))
        io << [chunk.bytesize].pack("N")
        io << code << chunk
        io << [crc].pack("N")
        io
      end
    end
  end

  module Aux
    def self.build_shape_from_triangle(triangles)
      shapes = [triangles.map { |t| t.each_slice(2).to_a }]
      m = Snowy::Matrix.new([[0.5, -1.5, 0], [0.5, 0.5, 0], [0, 0, 1]])
      5.times do
        shapes << shapes[-1].map { |sh|
          sh.map { |v|
            (x, y) = m.transform(*v)
            [x.round, y.round]
          }
        }
      end
      shapes.flatten!(1)
      Aux.compose_shapes(shapes)
    end

    # 同じ辺を持つ多角形を合成する。
    # ただし、多角形の辺の向きは同一である必要がある。
    # (右回りの図形であればそれのみ)
    def self.compose_shapes(shapes)
      i = 0
      while i < shapes.size
        p = shapes[i]
        j = i + 1
        while j < shapes.size
          q = shapes[j]
          if ss = compose_shape(p, q)
            shapes.delete_at(j)
            shapes.concat ss
            j = i + 1 # j を最初から繰り返す
          else
            j += 1
          end
        end
        i += 1
      end

      shapes.delete_if(&:empty?)

      shapes
    end

    # 穴が空いた場合、新しく出来たその多角形を返す。
    # 穴開きの図形は引数で与えた図形とは逆回りのものとなる。
    def self.compose_shape(p, q)
      p.each_with_index do |p2, i|
        p1 = p[i - 1]
        q.each_with_index do |q2, j|
          q1 = q[j - 1]
          if p1 == q2 && p2 == q1
            # p と q を合成する
            sub = q.slice(0, j - 1)
            p[i, 0] = sub if sub
            sub = q.slice(j + 1, q.size - (sub || []).size - 2)
            p[i, 0] = sub if sub
            return cleanup_shape(p, i, i + q.size - 1)
          end
        end
      end

      nil
    end

    def self.cleanup_shape(p, j0, jj)
      holes = []
      i = jj
      # i と j の値は増減するため、each などのイテレータは使えない
      while i < p.size
        (p1, p2) = p.values_at(i - 1, i)
        j = j0
        while j < jj
          (q1, q2) = p.values_at(j - 1, j)
          if p1 == q2 && p2 == q1
            hole = p.slice!(j .. i)
            if hole.size >= 5
              hole[-2, 2] = []
              holes << hole
            end
            i = j
            jj = j - 1
          else
            j += 1
          end
        end
        i += 1
      end
      holes
    end
  end


  #
  # @overload generate_to_png(code, options = {})
  #
  # @return
  #   string object as png stream
  # @param [Integer] code
  #   any bit integer (more than 40 bit recommended)
  # @param [String] code
  #   any length string (to hashing by md5 in this method)
  # @param options
  # @option options [Integer] :size (128) image size (width and height)
  # @option options [bool] :cap (true) add bit pattern to outside
  # @option options [bool] :extendcap (true) add bit pattern layer to outside
  # @option options [integer] :angle (0) rotation graph in degree
  # @option options :color (nil) set fill color
  # @option options :outline (nil) set outline color
  # @option options :driver (Snowy.driver) set rendering driver
  #
  def self.generate_to_png(code, size: 128, cap: true, extendcap: true, angle: 0, color: nil, outline: nil, driver: self.driver)
    if code.kind_of?(String)
      code = Digest::MD5.hexdigest(code).hex
    else
      code = code.to_i
    end

    driver ||= self.driver
    case driver
    when :ruby, nil
      require_relative "../snowy"
      driver = DefaultDriver
    when :cairo
      require_relative "cairo"
      driver = CairoDriver
    end

    case color
    when nil
      d = 360 * 10 * 6 # H * S * L
      r = code % d
      h = r / (10 * 6)
      s = (r / 6 % 10 + 1) / 16.0
      l = (r % 6 + 10) / 15.0
      hsl = HSL.new(h, s, l)
      color = Color.new(hsl, 1)
    when Integer
      rgb = RGB.new(color.get_red / 255.0, color.get_green / 255.0, color.get_blue / 255.0)
      color = Color.new(rgb, color.get_alpha / 255.0)
      hsl = rgb.to_hsl
    else
      hsl = color.to_hsl
    end

    if outline.nil?
      outline = Color.new(HSL.new(hsl.h, hsl.s * 4 / 5, hsl.l * 4 / 5), color.alpha)
    end

    depth = extendcap ? 7 : 6

    # NOTE: 全てのビットが0、または1とならないようにするため、その2パターンを除去する
    code = code % ((1 << (depth * (depth + 1) / 2)) - 2) + 1

    if cap
      # 外周部を追加
      code |= (extendcap ? 3 << 33 : 3 << 25)
      depth += 1
    end

    triangles = [] # [[x1, y1, x2, y2, x3, y3], ...]
    depth.times do |level|
      # level # 現在の階層
      # total # 現在の階層までの総要素数
      # layer # 現在の階層の要素数
      level_1 = level + 1
      total = level_1 ** 2
      layer = level * 2 + 1
      offbase = (level * level_1) / 2
      offpivot = (layer + 1) / 2 - 1
      layer.times do |i|
        if i > offpivot
          # mirror
          off = offbase + (layer - i - 1)
        else
          off = offbase + i
        end

        next if code[off] == 0

        m_level_i = -level + i
        if i.even?
          triangles << [m_level_i, level, m_level_i + 1, level_1, m_level_i - 1, level_1]
        else
          triangles << [m_level_i, level_1, m_level_i - 1, level, m_level_i + 1, level]
        end
      end
    end

    driver.render(size, triangles, rgb(1, 1, 1, 0), color, outline, angle)
  end

  @@driver = nil

  def self.driver
    @@driver
  end
end
