require "zlib"

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


  def self.rgba(r, g, b, a = 255)
    return (r.to_i.clamp(0, 255) << 24) |
           (g.to_i.clamp(0, 255) << 16) |
           (b.to_i.clamp(0, 255) <<  8) |
           (a.to_i.clamp(0, 255)      )
  end


  #
  # call-seq:
  #   generate_to_png(code, size = 128)
  #
  # @return
  #   string object
  #
  # @param [Integer] code
  #   32 bits integer
  #
  # @param [Integer] size
  #   output png image size
  #
  def self.generate_to_png(code, size: 128, cap: true, extendcap: true, angle: 0, color: nil, outline: nil)
    if code.kind_of?(String)
      code = Zlib.crc32(code)
    end

    if color
      if outline.nil?
        r = color.get_red
        g = color.get_green
        b = color.get_blue
        a = color.get_alpha
      end
    else
      r = (code >> 28) & 0x0f
      g = (code >> 24) & 0x0f
      b = (code >> 20) & 0x0f
      r = (r << 3) | 0x80
      g = (g << 3) | 0x80
      b = (b << 3) | 0x80
      color = rgba(r, g, b)
    end

    if outline.nil?
      outline = rgba(r * 7 / 8, g * 7 / 8, b * 7 / 8, a || 0xff)
    end

    code = code ^ (code >> 16) ^ ((code & 0xffff) << 16) if extendcap

    depth = extendcap ? 7 : 6
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
        if !extendcap && level_1 == depth
          i += 1
          break if (i + 1) == layer
          #break if i > layer
        end

        #if (i + 1) > (layer + 1) / 2
        if i > offpivot
          # mirror
          off = offbase + (layer - i - 1)
        else
          off = offbase + i
        end

        off -= 1 if !extendcap && level_1 == depth
        next if code[off] == 0

        m_level_i = -level + i
        if i.even?
          triangles << [m_level_i, level, m_level_i + 1, level_1, m_level_i - 1, level_1]
        else
          triangles << [m_level_i, level_1, m_level_i + 1, level, m_level_i - 1, level]
        end
      end
    end

    # 一番外側に三角形を配置する
    if cap
      if extendcap
        triangles << [-5, 7, -3, 7, -4, 8]
        triangles << [5, 7, 4, 8, 3, 7]
      else
        triangles << [-4, 6, -2, 6, -3, 7]
        triangles << [4, 6, 3, 7, 2, 6]
      end
    end

    driver.render(size, triangles, rgba(255, 255, 255, 0), color, outline, angle)
  end

  def self.driver
    @@driver
  end
end
