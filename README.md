# CSV::Deflate

## Usage

```ruby
require "csv/deflate"

# Write (gzip or zstd based on extension)
CSV::Deflate.open("data.csv.gz", "w", headers: %w[name age], write_headers: true) do |csv|
  csv << ["Alice", 30]
  csv << ["Bob", 25]
end

# Read
CSV::Deflate.open("data.csv.gz", "r", headers: true) do |csv|
  csv.each { |row| puts row["name"] }
end

# Or use foreach
CSV::Deflate.foreach("data.csv.zst", headers: true) do |row|
  puts row["name"]
end

# Compression level (gzip: 0-9, zstd: 1-22)
CSV::Deflate.open("data.csv.zst", "w", level: 19, headers: %w[name], write_headers: true)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wtn/csv-deflate.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
