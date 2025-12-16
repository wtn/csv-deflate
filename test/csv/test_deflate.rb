require "test_helper"
require "tempfile"
require "zlib"
require "zstd-ruby"

class CSV::TestDeflate < Minitest::Test
  FIXTURES = File.expand_path("../fixtures", __dir__)

  def test_that_it_has_a_version_number
    refute_nil ::CSV::Deflate::VERSION
  end

  # Write tests

  def test_write_gzip_file
    Tempfile.create(["test", ".csv.gz"]) do |f|
      path = f.path
      CSV::Deflate.open(path, "w", headers: %w[name age], write_headers: true) do |csv|
        csv << ["Alice", 30]
        csv << ["Bob", 25]
      end

      content = Zlib::GzipReader.open(path, &:read)
      assert_equal "name,age\nAlice,30\nBob,25\n", content
    end
  end

  def test_write_zstd_file
    Tempfile.create(["test", ".csv.zst"]) do |f|
      path = f.path
      CSV::Deflate.open(path, "w", headers: %w[name age], write_headers: true) do |csv|
        csv << ["Alice", 30]
        csv << ["Bob", 25]
      end

      compressed = File.binread(path)
      content = Zstd.decompress(compressed)
      assert_equal "name,age\nAlice,30\nBob,25\n", content
    end
  end

  def test_write_passes_csv_options
    Tempfile.create(["test", ".csv.gz"]) do |f|
      path = f.path
      CSV::Deflate.open(path, "w", headers: %w[name age], write_headers: true, col_sep: "\t") do |csv|
        csv << ["Alice", 30]
      end

      content = Zlib::GzipReader.open(path, &:read)
      assert_equal "name\tage\nAlice\t30\n", content
    end
  end

  def test_write_without_block_returns_csv
    Tempfile.create(["test", ".csv.gz"]) do |f|
      path = f.path
      csv = CSV::Deflate.open(path, "w", headers: %w[header], write_headers: true)
      assert_instance_of CSV, csv
      csv.close

      content = Zlib::GzipReader.open(path, &:read)
      assert_equal "header\n", content
    end
  end

  def test_write_defaults_to_write_mode
    Tempfile.create(["test", ".csv.gz"]) do |f|
      path = f.path
      CSV::Deflate.open(path, headers: %w[name], write_headers: true) do |csv|
        csv << ["Alice"]
      end

      content = Zlib::GzipReader.open(path, &:read)
      assert_equal "name\nAlice\n", content
    end
  end

  # Read tests

  def test_read_gzip_file
    rows = []
    CSV::Deflate.open("#{FIXTURES}/simple.csv.gz", "r", headers: true) do |csv|
      csv.each { |row| rows << row.to_h }
    end

    assert_equal 2, rows.size
    assert_equal({"name" => "Alice", "age" => "30", "city" => "New York"}, rows[0])
    assert_equal({"name" => "Bob", "age" => "25", "city" => "Los Angeles"}, rows[1])
  end

  def test_read_zstd_file
    rows = []
    CSV::Deflate.open("#{FIXTURES}/simple.csv.zst", "r", headers: true) do |csv|
      csv.each { |row| rows << row.to_h }
    end

    assert_equal 2, rows.size
    assert_equal({"name" => "Alice", "age" => "30", "city" => "New York"}, rows[0])
    assert_equal({"name" => "Bob", "age" => "25", "city" => "Los Angeles"}, rows[1])
  end

  def test_read_without_block_returns_csv
    csv = CSV::Deflate.open("#{FIXTURES}/simple.csv.gz", "r", headers: true)
    assert_instance_of CSV, csv
    row = csv.first
    assert_equal "Alice", row["name"]
    csv.close
  end

  def test_read_with_csv_options
    rows = []
    CSV::Deflate.open("#{FIXTURES}/tabs.tsv.gz", "r", headers: true, col_sep: "\t") do |csv|
      csv.each { |row| rows << row.to_h }
    end

    assert_equal 2, rows.size
    assert_equal({"name" => "Alice", "age" => "30"}, rows[0])
  end

  def test_read_zstd_with_csv_options
    rows = []
    CSV::Deflate.open("#{FIXTURES}/tabs.tsv.zst", "r", headers: true, col_sep: "\t") do |csv|
      csv.each { |row| rows << row.to_h }
    end

    assert_equal 2, rows.size
    assert_equal({"name" => "Bob", "age" => "25"}, rows[1])
  end

  # Quoted fields / edge cases

  def test_read_quoted_fields_gzip
    rows = []
    CSV::Deflate.open("#{FIXTURES}/quoted.csv.gz", "r", headers: true) do |csv|
      csv.each { |row| rows << row.to_h }
    end

    assert_equal 2, rows.size
    assert_equal 'Alice "The Great"', rows[0]["name"]
    assert_equal "Loves coding, testing, and Ruby", rows[0]["bio"]
    assert_includes rows[1]["bio"], "\n"
  end

  def test_read_quoted_fields_zstd
    rows = []
    CSV::Deflate.open("#{FIXTURES}/quoted.csv.zst", "r", headers: true) do |csv|
      csv.each { |row| rows << row.to_h }
    end

    assert_equal 2, rows.size
    assert_equal 'Alice "The Great"', rows[0]["name"]
    assert_includes rows[1]["bio"], "\n"
  end

  # Large file streaming

  def test_read_large_file_gzip
    count = 0
    CSV::Deflate.open("#{FIXTURES}/large.csv.gz", "r", headers: true) do |csv|
      csv.each { |_row| count += 1 }
    end
    assert_equal 1000, count
  end

  def test_read_large_file_zstd
    count = 0
    CSV::Deflate.open("#{FIXTURES}/large.csv.zst", "r", headers: true) do |csv|
      csv.each { |_row| count += 1 }
    end
    assert_equal 1000, count
  end

  # Headers only (empty data)

  def test_read_headers_only_gzip
    rows = []
    CSV::Deflate.open("#{FIXTURES}/headers_only.csv.gz", "r", headers: true) do |csv|
      csv.each { |row| rows << row }
    end
    assert_empty rows
  end

  def test_read_headers_only_zstd
    rows = []
    CSV::Deflate.open("#{FIXTURES}/headers_only.csv.zst", "r", headers: true) do |csv|
      csv.each { |row| rows << row }
    end
    assert_empty rows
  end

  # foreach tests

  def test_foreach_gzip_file
    rows = []
    CSV::Deflate.foreach("#{FIXTURES}/simple.csv.gz", headers: true) { |row| rows << row.to_h }

    assert_equal 2, rows.size
    assert_equal "Alice", rows[0]["name"]
  end

  def test_foreach_zstd_file
    rows = []
    CSV::Deflate.foreach("#{FIXTURES}/simple.csv.zst", headers: true) { |row| rows << row.to_h }

    assert_equal 2, rows.size
    assert_equal "Bob", rows[1]["name"]
  end

  def test_foreach_returns_enumerator_without_block
    enum = CSV::Deflate.foreach("#{FIXTURES}/simple.csv.gz", headers: true)
    assert_instance_of Enumerator, enum
    assert_equal 2, enum.count
  end

  # Round-trip tests

  def test_round_trip_gzip
    Tempfile.create(["test", ".csv.gz"]) do |f|
      path = f.path

      # Write
      CSV::Deflate.open(path, "w", headers: %w[id name score], write_headers: true) do |csv|
        csv << [1, "Alice", 95]
        csv << [2, "Bob", 87]
      end

      # Read back
      rows = []
      CSV::Deflate.open(path, "r", headers: true) do |csv|
        csv.each { |row| rows << row.to_h }
      end

      assert_equal 2, rows.size
      assert_equal({"id" => "1", "name" => "Alice", "score" => "95"}, rows[0])
      assert_equal({"id" => "2", "name" => "Bob", "score" => "87"}, rows[1])
    end
  end

  def test_round_trip_zstd
    Tempfile.create(["test", ".csv.zst"]) do |f|
      path = f.path

      # Write
      CSV::Deflate.open(path, "w", headers: %w[id name score], write_headers: true) do |csv|
        csv << [1, "Alice", 95]
        csv << [2, "Bob", 87]
      end

      # Read back
      rows = []
      CSV::Deflate.open(path, "r", headers: true) do |csv|
        csv.each { |row| rows << row.to_h }
      end

      assert_equal 2, rows.size
      assert_equal({"id" => "1", "name" => "Alice", "score" => "95"}, rows[0])
      assert_equal({"id" => "2", "name" => "Bob", "score" => "87"}, rows[1])
    end
  end

  # Compression level tests

  def test_write_gzip_with_compression_level
    Tempfile.create(["test", ".csv.gz"]) do |f|
      path = f.path
      CSV::Deflate.open(path, "w", level: 9, headers: %w[name], write_headers: true) do |csv|
        csv << ["Alice"]
      end

      # Verify it's valid gzip
      content = Zlib::GzipReader.open(path, &:read)
      assert_equal "name\nAlice\n", content
    end
  end

  def test_write_zstd_with_compression_level
    Tempfile.create(["test", ".csv.zst"]) do |f|
      path = f.path
      CSV::Deflate.open(path, "w", level: 19, headers: %w[name], write_headers: true) do |csv|
        csv << ["Alice"]
      end

      # Verify it's valid zstd
      content = Zstd.decompress(File.binread(path))
      assert_equal "name\nAlice\n", content
    end
  end

  def test_compression_level_affects_output_size
    data = ["x" * 1000] * 100  # repetitive data compresses well

    sizes = {}
    [1, 19].each do |level|
      Tempfile.create(["test", ".csv.zst"]) do |f|
        CSV::Deflate.open(f.path, "w", level: level, headers: %w[data], write_headers: true) do |csv|
          data.each { |d| csv << [d] }
        end
        sizes[level] = File.size(f.path)
      end
    end

    # Higher compression level should produce smaller (or equal) file
    assert_operator sizes[19], :<=, sizes[1]
  end

  # Error tests

  def test_open_raises_for_unsupported_extension
    Tempfile.create(["test", ".csv"]) do |f|
      error = assert_raises(CSV::Deflate::Error) do
        CSV::Deflate.open(f.path, "w") { |csv| csv << ["data"] }
      end
      assert_match(/unsupported file extension/, error.message)
    end
  end

  def test_open_raises_for_unknown_extension
    Tempfile.create(["test", ".csv.bz2"]) do |f|
      error = assert_raises(CSV::Deflate::Error) do
        CSV::Deflate.open(f.path, "w") { |csv| csv << ["data"] }
      end
      assert_match(/unsupported file extension/, error.message)
    end
  end

  def test_open_raises_for_invalid_mode
    Tempfile.create(["test", ".csv.gz"]) do |f|
      error = assert_raises(CSV::Deflate::Error) do
        CSV::Deflate.open(f.path, "x") { |csv| csv << ["data"] }
      end
      assert_match(/unsupported mode/, error.message)
    end
  end
end
