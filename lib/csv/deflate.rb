require "csv"
require "zlib"
require "zstd-ruby"
require_relative "deflate/version"

class CSV
  module Deflate
    class Error < StandardError; end

    class ZstdStreamWriter
      def initialize(file, level: nil)
        @file = file
        @writer = level ? Zstd::StreamWriter.new(file, level: level) : Zstd::StreamWriter.new(file)
        @closed = false
      end

      def write(data)
        @writer.write(data)
      end

      def <<(data)
        write(data)
        self
      end

      def closed?
        @closed
      end

      def close
        @writer.close
        @closed = true
      end
    end

    class ZstdStreamReader
      CHUNK_SIZE = 128 * 1024  # zstd default block size

      def initialize(file)
        @file = file
        @reader = Zstd::StreamReader.new(file)
        @buffer = ""
        @eof = false
        @closed = false
      end

      def gets(sep = $/, limit = nil)
        return nil if @eof && @buffer.empty?

        # When sep is nil, read entire content
        if sep.nil?
          while (chunk = read_chunk)
            @buffer << chunk
          end
          @eof = true
          return @buffer.empty? ? nil : @buffer.slice!(0, @buffer.length)
        end

        while (idx = @buffer.index(sep)).nil? && !@eof
          chunk = read_chunk
          if chunk.nil? || chunk.empty?
            @eof = true
          else
            @buffer << chunk
          end
        end

        if (idx = @buffer.index(sep))
          line = @buffer.slice!(0, idx + sep.length)
          limit ? line[0, limit] : line
        elsif @eof && !@buffer.empty?
          @buffer.slice!(0, @buffer.length)
        end
      end

      def read(length = nil, outbuf = nil)
        result = if length.nil?
          while (chunk = read_chunk)
            @buffer << chunk
          end
          @buffer.slice!(0, @buffer.length)
        else
          while @buffer.length < length
            chunk = read_chunk
            break if chunk.nil? || chunk.empty?
            @buffer << chunk
          end
          @buffer.slice!(0, length)
        end

        if outbuf
          outbuf.replace(result || "")
          outbuf.empty? ? nil : outbuf
        else
          result.nil? || result.empty? ? nil : result
        end
      end

      def close
        @file.close unless @file.closed?
        @closed = true
      end

      def closed?
        @closed
      end

      private

      def read_chunk
        @reader.read(CHUNK_SIZE)
      rescue StandardError => e
        raise unless e.message == "EOF"
        nil
      end
    end

    def self.open(path, mode = "w", level: nil, **csv_options, &block)
      ext = File.extname(path)

      io = case mode
      when "w"
        case ext
        when ".gz"
          Zlib::GzipWriter.open(path, level || Zlib::DEFAULT_COMPRESSION)
        when ".zst"
          ZstdStreamWriter.new(File.open(path, "wb"), level: level)
        else
          raise Error, "unsupported file extension: #{ext.inspect} (expected .gz or .zst)"
        end
      when "r"
        case ext
        when ".gz"
          Zlib::GzipReader.open(path)
        when ".zst"
          ZstdStreamReader.new(File.open(path, "rb"))
        else
          raise Error, "unsupported file extension: #{ext.inspect} (expected .gz or .zst)"
        end
      else
        raise Error, "unsupported mode: #{mode.inspect} (expected r or w)"
      end

      csv = CSV.new(io, **csv_options)

      if block
        begin
          yield csv
        ensure
          csv.close
          io.close unless io.closed?
        end
      else
        csv
      end
    end

    def self.foreach(path, **csv_options, &block)
      return to_enum(__method__, path, **csv_options) unless block

      open(path, "r", **csv_options) do |csv|
        csv.each(&block)
      end
    end
  end
end
