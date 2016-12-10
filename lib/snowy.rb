#!ruby

require_relative "snowy/common"

module Snowy
  using Extentions

  module DefaultDriver
    def self.render(size, triangles, background, color, outline, angle)
      img = Canvas.new(size, size, 0, 1, plt = [background, color])
      plt << outline if outline

      img.instance_exec do
        translate(width / 2.0, height / 2.0)
        scale(width / 32.0, height / 32.0)
        rotate_deg(angle)
        sqrt3 = Math.sqrt(3)
        [30, 90, 150, 210, 270, 330].each do |deg|
          push_matrix do
            rotate_deg(deg)
            scale(1, sqrt3)
            triangles.each do |t|
              triangle(*t)
            end
          end
        end

        # plot outline
        if outline
          w = width
          h = height
          pix = pixels
          (1 ... (h - 1)).step(1) do |py|
            py0 = py * w
            py1 = (py + 1) * w
            py2 = (py - 1) * w
            (1 ... (w - 1)).step(1) do |px|
              px1 = px + 1
              px2 = px - 1
              if pix.getbyte(py0 + px) == 0
                if pix.getbyte(py0 + px1) == 1 ||
                   pix.getbyte(py0 + px2) == 1 ||
                   pix.getbyte(py1 + px ) == 1 ||
                   pix.getbyte(py2 + px ) == 1
                  pix.setbyte(py0 + px, 2)
                end
              end
            end
          end
        end
        export_to_png
      end
    end
  end

  @@driver = DefaultDriver


  BLACK = rgba(0, 0, 0)
  WHITE = rgba(255, 255, 255)

  #
  # 256 indexed canvas
  #
  class Canvas
    attr_reader :width, :height, :pixels, :matrix, :palette, :color

    MIN_PIXEL = 1
    MAX_PIXEL = 4096

    def initialize(width, height, background = 0, color = 1, palette = [WHITE, BLACK])
      @width = width.to_i
      @height = height.to_i
      if @width < MIN_PIXEL || @width > MAX_PIXEL ||
         @height < MIN_PIXEL || @height > MAX_PIXEL
        raise ArgumentError,
              "width and height are too small or large (given %d x %d, expect %d..%d)" %
                [@width, @height, MIN_PIXEL, MAX_PIXEL]
      end

      @pixels = [background].pack("C") * (@width * @height)
      @matrix = Matrix.new
      @palette = palette
      @color = color
    end

    ## primitive operators
    ;

    def getpixel(x, y)
      x = x.to_i
      y = y.to_i
      if validate_point(x, y)
        getpixel!(x, y)
      else
        nil
      end
    end

    alias [] getpixel

    def setpixel(x, y, level)
      x = x.to_i
      y = y.to_i
      validate_point(x, y) and setpixel!(x, y, level)
      self
    end

    alias []= setpixel

    ## lowlevel operations
    ;

    def fill(color = @color)
      @pixels.bytesize.times do |i|
        @pixels.setbyte(i, color)
      end
      self
    end

    def validate_point(x, y)
      if x < 0 || x >= @width || y < 0 || y >= @height
        false
      else
        true
      end
    end

    def test_point(x, y)
      unless validate_point(x, y)
        raise ArgumentError,
              "x and y are out of canvas (given (%d, %d), expect (0, 0) .. (%d, %d))" %
                [x, y, @width - 1, @height - 1]
      end

      nil
    end

    def getpixel!(x, y)
      @pixels.getbyte(x + y * @width)
    end

    def setpixel!(x, y, color)
      @pixels.setbyte(x + y * @width, color)
    end

    def plotscanline!(y, x0, x1)
      w = width
      px = pixels
      i = color
      x0.upto(x1 - 1) { |x| px.setbyte(x + y * w, i) }
      self
    end

    ## primitive figures
    ;

    def plotscanline(y, x0, x1)
      y = y.round
      x0 = x0.round
      x1 = x1.round

      if y >= 0 && y < height
        (x0, x1) = x1, x0 if x0 > x1
        if x0 < width && x1 >= 0
          x0 = [0, x0].max
          x1 = [x1, width].min
          plotscanline! y, x0, x1
        end
      end

      self
    end

    ## additional operators
    ;

    #
    # plot dot by char
    #
    # example:
    #     # plot dot "Error(TIMEDOUT)"
    #     canv.dot_by_char(5, 5, <<-CODE, { "*" => 3 })
    #   ***                  * *** *** *   * *** **  *** * * *** *
    #   *                   *   *   *  ** ** *   * * * * * *  *   *
    #   *** *** *** *** *** *   *   *  * * * *** * * * * * *  *   *
    #   *   *   *   * * *   *   *   *  * * * *   * * * * * *  *   *
    #   *** *   *   *** *    *  *  *** *   * *** **  *** ***  *  *
    #     CODE
    #
    def dot_by_char(x, y, seq, colormap = { "*" => 2 })
      x0 = x
      seq.each_char do |ch|
        case ch
        when "\n"
          x = x0
          y += 1
        when " "
          x += 1
        else
          if color = colormap[ch]
            setpixel(x, y, color)
          end
          x += 1
        end
      end

      self
    end

    ## transform operators
    ;

    def init_matrix
      matrix.init
      self
    end

    def push_matrix
      save = matrix.dup
      return save unless block_given?

      begin
        yield
      ensure
        matrix.load(save)
      end
    end

    def pop_matrix(saved_matrix)
      matrix.load(saved_matrix)
      self
    end

    def mult_matrix(matrix1)
      matrix.mult(matrix1)
      self
    end

    def transform(x, y, w = 1)
      matrix.transform(x, y, w)
    end

    def translate(dx, dy, dw = 1)
      matrix.translate(dx, dy, dw)
      self
    end

    def scale(ax, ay, aw = 1)
      matrix.scale(ax, ay, aw)
      self
    end

    def rotate(rad)
      matrix.rotate(rad)
      self
    end

    def rotate_deg(deg)
      matrix.rotate(Math::PI * deg / 180)
      self
    end

    ## transformed figures
    ;

    def triangle(x0, y0, x1, y1, x2, y2)
      (x0, y0) = transform(x0, y0)
      (x1, y1) = transform(x1, y1)
      (x2, y2) = transform(x2, y2)

      x0 = x0.round
      x1 = x1.round
      x2 = x2.round
      y0 = y0.round
      y1 = y1.round
      y2 = y2.round

      (x0, y0, x1, y1) = x1, y1, x0, y0 if y0 > y1
      (x1, y1, x2, y2) = x2, y2, x1, y1 if y1 > y2
      (x0, y0, x1, y1) = x1, y1, x0, y0 if y0 > y1

      if y0 == y2
        (a, *, b) = [x0, x1, x2].sort
        plotscanline(y0, a, b)
      else
        d1 = (x1 - x0) / (y1 - y0).to_f
        d2 = (x2 - x0) / (y2 - y0).to_f
        (y0 ... y1).step(1) do |py|
          dy = py - y0
          plotscanline(py, x0 + dy * d1, x0 + dy * d2)
        end

        if y1 == y2
          plotscanline(y1, x1, x2)
        else
          d0 = (x0 - x2) / (y0 - y2).to_f
          d1 = (x1 - x2) / (y1 - y2).to_f
          (y1 .. y2).step(1) do |py|
            dy = (py - y2)
            plotscanline(py, x2 + dy * d1, x2 + dy * d0)
          end
        end
      end

      self
    end

    ## extra
    ;

    def halfdown!
      pixels = @pixels
      height = @height
      width2 = width >> 1
      height2 = height >> 1
      height2.times do |y|
        width2.times do |x|
          xx = x * 2
          yy = y * 2
          xx1 = xx + 1
          yy1 = (yy + 1) * height
          yy = yy * height
          pixels.setbyte(x + y * width2,
                         (pixels.getbyte(xx + yy) +
                          pixels.getbyte(xx1 + yy) +
                          pixels.getbyte(xx + yy1) +
                          pixels.getbyte(xx1 + yy1)) / 4)
        end
      end

      @width = width2
      @height = height2
      @pixels[(width2 * height2) .. -1] = ""

      self
    end

    ## export to png
    ;

    def export_to_png(io = "".b, level: Zlib::DEFAULT_COMPRESSION)
      io << [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*")
      storechunk = ->(code, chunk) {
        crc = Zlib.crc32(chunk, Zlib.crc32(code))
        io << [chunk.bytesize].pack("N")
        io << code << chunk
        io << [crc].pack("N")
      }

      ## IDAT
      ##  color
      ##  type  bit depth
      ##  0     1,2,4,8,16  immediate grayscale sample
      ##  2     8,16        immediate RGB sample
      ##  3     1,2,4,8     palette sample (need PLTE chunk)
      ##  4     8,16        immediate grayscale sample with alpha
      ##  6     8,16        immediate RGB sample with alpha
      colorbits = 8
      colortype = 3
      storechunk["IHDR", [width, height, colorbits, colortype, 0, 0, 0].pack("NNCCCCC")]

      ## PLTE
      plte = palette.reduce("".b) { |a, e|
        a << e.pack_rgb
      }
      storechunk["PLTE", plte]

      ## tRNS
      ##    Alpha for palette index 0:  1 byte
      ##    Alpha for palette index 1:  1 byte
      ##    ...etc...
      trns = palette.reduce([]) { |a, e| a << e.get_alpha }
      storechunk["tRNS", trns.pack("C*")]

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
      storechunk["iTXt", ["snowy", 0, 0, <<-'SNOWY'].pack("a*xCCxxa*")]
This image is generated by snowy <https://rubygems.org/gems/snowy>
      SNOWY
      storechunk["iTXt", ["LICENSING", 0, 0, <<-'LICENSING'].pack("a*xCCxxa*")]
Creative Commons License Zero (CC0 / Public Domain)
See <https://creativecommons.org/publicdomain/zero/1.0/>
      LICENSING

      ## IDAT
      scanline = ->(lines, line) {
        lines << "\0" << line
      }
      scanline ||= ->(lines, line) {
        v = 0
        line.each_byte.with_index { |vv, i|
          line.setbyte(i, vv - v)
          v = vv
        }
        lines << "\1" << line
      }
      lines = height.times.reduce("".b) { |a, h|
        line = pixels.byteslice(h * width, width)
        scanline[a, line]
      }
      storechunk["IDAT", Zlib.deflate(lines, level)]

      storechunk["IEND", ""]

      io
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
end
