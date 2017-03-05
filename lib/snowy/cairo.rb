require_relative "common"
require "cairo"

module Snowy
  using Extentions

  module CairoDriver
    def self.render(size, triangles, background, color, outline, angle)
      deg2rad = Math::PI / 180
      sqrt3 = Math.sqrt(3)
      surface = Cairo::ImageSurface.new(Cairo::Format::ARGB32, size, size)
      Cairo::Context.new(surface) do |context|
        context.instance_eval do
          set_fill_rule Cairo::FillRule::EVEN_ODD
          set_line_join Cairo::LineJoin::ROUND
          set_source_color [background.red, background.green, background.blue, background.alpha]
          paint
          translate(size / 2.0, size / 2.0)
          scale(size / 32.0, size / 32.0)
          save do
            rotate(angle * deg2rad) unless angle == 0
            [30, 90, 150, 210, 270, 330].each do |deg|
              save do
                rotate deg * deg2rad
                scale 1, sqrt3
                triangles.each do |t|
                  triangle *t
                end
              end
            end
          end
          if outline
            set_line_width 0.5
            set_source_rgba outline.red, outline.green, outline.blue, outline.alpha
            stroke true
          end
          set_source_rgba color.red, color.green, color.blue, color.alpha
          fill
        end
      end

      buffer = "".b
      outport = Object.new
      outport.define_singleton_method(:write, ->(d) { buffer << d; d.bytesize })
      surface.write_to_png outport
      buffer
    end
  end

  @@driver = CairoDriver
end
