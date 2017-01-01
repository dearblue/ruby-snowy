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
      rgb = code % (15 * 15 * 15)
      r = ((rgb / 15 / 15 + 1) << 3) | 0x87
      g = ((rgb / 15 % 15 + 1) << 3) | 0x87
      b = ((rgb % 15      + 1) << 3) | 0x87
      color = rgba(r, g, b)
    end

    if outline.nil?
      outline = rgba(r * 7 / 8, g * 7 / 8, b * 7 / 8, a || 0xff)
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

    driver.render(size, triangles, rgba(255, 255, 255, 0), color, outline, angle)
  end

  def self.driver
    @@driver
  end
end
