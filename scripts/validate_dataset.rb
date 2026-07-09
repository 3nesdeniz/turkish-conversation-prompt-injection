#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "set"

ROOT = File.expand_path("..", __dir__)
SPLITS = %w[train validation test].freeze
EXPECTED_SPLIT_COUNTS = { "train" => 530, "validation" => 100, "test" => 120 }.freeze
EXPECTED_LABEL_COUNTS = { 0 => 600, 1 => 150 }.freeze
EXPECTED_CATEGORY_COUNTS = {
  "benign_daily" => 410,
  "benign_technical" => 40,
  "benign_boundary" => 150,
  "prompt_injection" => 150
}.freeze
EXPECTED_PAIR_ALLOCATION = { "train" => 10, "validation" => 2, "test" => 3 }.freeze
REQUIRED_FIELDS = %w[
  id text label category attack_family source_context pair_id source_type split
].freeze

errors = []
warnings = []

def read_split(root, split, errors)
  path = File.join(root, "data", "#{split}.jsonl")
  unless File.file?(path)
    errors << "Missing split file: #{path}"
    return []
  end

  rows = []
  File.readlines(path, chomp: true).each_with_index do |line, index|
    if line.strip.empty?
      errors << "Blank line in #{split}:#{index + 1}"
      next
    end

    begin
      row = JSON.parse(line)
      row["_line"] = index + 1
      row["_file_split"] = split
      rows << row
    rescue JSON::ParserError => e
      errors << "Invalid JSON in #{split}:#{index + 1}: #{e.message}"
    end
  end
  rows
end

def normalized_text(text)
  text.unicode_normalize(:nfkc).downcase.gsub(/[[:punct:]\s]+/u, " ").strip
end

def tokens(text)
  Set.new(text.downcase.scan(/[[:alnum:]_çğıöşü]+/u).reject { |token| token.length < 2 })
end

rows_by_split = {}
SPLITS.each { |split| rows_by_split[split] = read_split(ROOT, split, errors) }
all_rows = rows_by_split.values.flatten

EXPECTED_SPLIT_COUNTS.each do |split, expected|
  actual = rows_by_split.fetch(split).size
  errors << "#{split} count: expected #{expected}, found #{actual}" unless actual == expected
end

all_rows.each do |row|
  location = "#{row['_file_split']}:#{row['_line']}"
  missing = REQUIRED_FIELDS.reject { |field| row.key?(field) }
  errors << "#{location} missing fields: #{missing.join(', ')}" unless missing.empty?
  next unless missing.empty?

  extra = row.keys.reject { |field| REQUIRED_FIELDS.include?(field) || field.start_with?("_") }
  errors << "#{location} unexpected fields: #{extra.join(', ')}" unless extra.empty?

  errors << "#{location} empty id" if row["id"].to_s.strip.empty?
  errors << "#{location} empty text" if row["text"].to_s.strip.empty?
  errors << "#{location} invalid label #{row['label'].inspect}" unless [0, 1].include?(row["label"])
  errors << "#{location} split field mismatch" unless row["split"] == row["_file_split"]
  errors << "#{location} invalid source_type" unless row["source_type"] == "synthetic_curated"
  errors << "#{location} contains control characters" if row["text"].match?(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/)

  if row["label"] == 1
    errors << "#{location} attack category mismatch" unless row["category"] == "prompt_injection"
    errors << "#{location} attack_family cannot be none" if row["attack_family"] == "none"
    errors << "#{location} attack row requires pair_id" if row["pair_id"].nil?
  elsif row["label"] == 0
    errors << "#{location} benign attack_family must be none" unless row["attack_family"] == "none"
    unless %w[benign_daily benign_technical benign_boundary].include?(row["category"])
      errors << "#{location} invalid benign category #{row['category'].inspect}"
    end
    if row["category"] == "benign_boundary" && row["pair_id"].nil?
      errors << "#{location} boundary row requires pair_id"
    end
  end
end

ids = all_rows.group_by { |row| row["id"] }
ids.each { |id, matches| errors << "Duplicate id #{id}" if matches.size > 1 }

texts = all_rows.group_by { |row| normalized_text(row["text"]) }
texts.each do |text, matches|
  errors << "Duplicate normalized text in IDs #{matches.map { |row| row['id'] }.join(', ')}" if matches.size > 1
end

label_counts = all_rows.group_by { |row| row["label"] }.transform_values(&:size)
errors << "Label counts mismatch: #{label_counts.inspect}" unless label_counts == EXPECTED_LABEL_COUNTS

category_counts = all_rows.group_by { |row| row["category"] }.transform_values(&:size)
unless category_counts == EXPECTED_CATEGORY_COUNTS
  errors << "Category counts mismatch: #{category_counts.inspect}"
end

pairs = all_rows.reject { |row| row["pair_id"].nil? }.group_by { |row| row["pair_id"] }
errors << "Expected 150 pair groups, found #{pairs.size}" unless pairs.size == 150

pairs.each do |pair_id, pair_rows|
  errors << "#{pair_id} must contain 2 rows" unless pair_rows.size == 2
  next unless pair_rows.size == 2

  labels = pair_rows.map { |row| row["label"] }.sort
  errors << "#{pair_id} must contain labels 0 and 1" unless labels == [0, 1]

  splits = pair_rows.map { |row| row["split"] }.uniq
  errors << "#{pair_id} crosses splits: #{splits.join(', ')}" unless splits.size == 1

  contexts = pair_rows.map { |row| row["source_context"] }.uniq
  errors << "#{pair_id} has mismatched source_context" unless contexts.size == 1

  benign = pair_rows.find { |row| row["label"] == 0 }
  attack = pair_rows.find { |row| row["label"] == 1 }
  next unless benign && attack

  overlap = tokens(benign["text"]) & tokens(attack["text"])
  warnings << "#{pair_id} has no lexical overlap" if overlap.empty?
end

attack_rows = all_rows.select { |row| row["label"] == 1 }
family_counts = attack_rows.group_by { |row| row["attack_family"] }.transform_values(&:size)
errors << "Expected 10 attack families, found #{family_counts.size}" unless family_counts.size == 10
family_counts.each do |family, count|
  errors << "#{family} count: expected 15, found #{count}" unless count == 15
end

family_counts.keys.each do |family|
  EXPECTED_PAIR_ALLOCATION.each do |split, expected|
    actual = rows_by_split.fetch(split).count do |row|
      row["label"] == 1 && row["attack_family"] == family
    end
    errors << "#{family}/#{split}: expected #{expected}, found #{actual}" unless actual == expected
  end
end

sensitive_patterns = {
  "email" => /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,
  "turkish_iban" => /\bTR\d{24}\b/i,
  "long_numeric_identifier" => /\b\d{10,19}\b/,
  "phone_number" => /(?:\+?90\s*)?0?5\d{2}[\s.-]?\d{3}[\s.-]?\d{2}[\s.-]?\d{2}/
}
sensitive_patterns.each do |name, pattern|
  matches = all_rows.select { |row| row["text"].match?(pattern) }
  errors << "Potential #{name} in IDs: #{matches.map { |row| row['id'] }.join(', ')}" unless matches.empty?
end

checksums_path = File.join(ROOT, "metadata", "checksums.sha256")
if File.file?(checksums_path)
  File.readlines(checksums_path, chomp: true).reject(&:empty?).each do |line|
    expected, relative_path = line.split(/\s+/, 2)
    full_path = File.join(ROOT, relative_path)
    if !File.file?(full_path)
      errors << "Checksum target missing: #{relative_path}"
    elsif Digest::SHA256.file(full_path).hexdigest != expected
      errors << "Checksum mismatch: #{relative_path}"
    end
  end
else
  errors << "Missing metadata/checksums.sha256"
end

puts "Validated #{all_rows.size} rows across #{SPLITS.size} splits."
puts "Labels: #{label_counts.sort.to_h.inspect}"
puts "Categories: #{category_counts.sort.to_h.inspect}"
puts "Attack families: #{family_counts.sort.to_h.inspect}"

unless warnings.empty?
  puts "Warnings (#{warnings.size}):"
  warnings.each { |warning| puts "  - #{warning}" }
end

unless errors.empty?
  warn "Validation failed with #{errors.size} error(s):"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

puts "Validation passed."
