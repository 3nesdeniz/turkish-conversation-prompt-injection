#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

ROOT = File.expand_path("..", __dir__)
SEED = 20_260_709
VERSION = "1.0.1"

BASE_PATH = File.join(ROOT, "source", "base_benign.jsonl")
PAIRS_PATH = File.join(ROOT, "source", "paired_cases.jsonl")
DATA_DIR = File.join(ROOT, "data")
METADATA_DIR = File.join(ROOT, "metadata")

def read_jsonl(path)
  rows = []
  File.readlines(path, chomp: true).each_with_index do |line, index|
    next if line.strip.empty?

    rows << JSON.parse(line)
  rescue JSON::ParserError => e
    abort "Invalid JSON in #{path}:#{index + 1}: #{e.message}"
  end
  rows
end

def write_jsonl(path, rows)
  File.open(path, "w") do |file|
    rows.each { |row| file.puts(JSON.generate(row)) }
  end
end

def dataset_row(id:, text:, label:, category:, attack_family:, source_context:, pair_id:)
  {
    "id" => id,
    "text" => text,
    "label" => label,
    "category" => category,
    "attack_family" => attack_family,
    "source_context" => source_context,
    "pair_id" => pair_id,
    "source_type" => "synthetic_curated"
  }
end

base_rows = read_jsonl(BASE_PATH)
pair_sources = read_jsonl(PAIRS_PATH)

abort "Expected 450 base benign rows, found #{base_rows.size}" unless base_rows.size == 450
abort "Expected 150 paired cases, found #{pair_sources.size}" unless pair_sources.size == 150

family_counts = pair_sources.group_by { |row| row.fetch("family") }.transform_values(&:size)
unless family_counts.size == 10 && family_counts.values.all? { |count| count == 15 }
  abort "Expected 10 attack families with 15 pairs each, found #{family_counts.inspect}"
end

base = base_rows.each_with_index.map do |row, index|
  old_category = row.fetch("category")
  category = case old_category
             when "daily" then "benign_daily"
             when "technical" then "benign_technical"
             else abort "Unexpected base category: #{old_category}"
             end

  dataset_row(
    id: format("tcpi_b%04d", index + 1),
    text: row.fetch("text"),
    label: 0,
    category: category,
    attack_family: "none",
    source_context: "direct_user",
    pair_id: nil
  )
end

pair_groups = pair_sources.each_with_index.map do |source, index|
  pair_number = index + 1
  pair_id = source.fetch("pair_id")
  family = source.fetch("family")
  context = source.fetch("source_context")

  benign = dataset_row(
    id: format("tcpi_p%04d_b", pair_number),
    text: source.fetch("benign"),
    label: 0,
    category: "benign_boundary",
    attack_family: "none",
    source_context: context,
    pair_id: pair_id
  )

  attack = dataset_row(
    id: format("tcpi_p%04d_a", pair_number),
    text: source.fetch("attack"),
    label: 1,
    category: "prompt_injection",
    attack_family: family,
    source_context: context,
    pair_id: pair_id
  )

  { "family" => family, "rows" => [benign, attack] }
end

rng = Random.new(SEED)
base_shuffled = base.shuffle(random: rng)

splits = {
  "train" => base_shuffled.first(330),
  "validation" => base_shuffled.slice(330, 60),
  "test" => base_shuffled.last(60)
}

pair_groups.group_by { |group| group.fetch("family") }.sort.each do |_family, groups|
  shuffled = groups.shuffle(random: rng)
  allocations = {
    "train" => shuffled.first(10),
    "validation" => shuffled.slice(10, 2),
    "test" => shuffled.last(3)
  }

  allocations.each do |split, assigned_groups|
    assigned_groups.each { |group| splits.fetch(split).concat(group.fetch("rows")) }
  end
end

FileUtils.mkdir_p(DATA_DIR)
FileUtils.mkdir_p(METADATA_DIR)

splits.each do |split, rows|
  rows.each { |row| row["split"] = split }
  rows.shuffle!(random: rng)
  write_jsonl(File.join(DATA_DIR, "#{split}.jsonl"), rows)
end

all_rows = splits.values.flatten
stats = {
  "dataset" => "Turkish Conversation Prompt-Injection Dataset",
  "version" => VERSION,
  "schema_version" => "1.0",
  "language" => "tr",
  "total_rows" => all_rows.size,
  "pair_count" => pair_groups.size,
  "split_counts" => splits.transform_values(&:size),
  "label_counts" => all_rows.group_by { |row| row.fetch("label").to_s }.transform_values(&:size).sort.to_h,
  "category_counts" => all_rows.group_by { |row| row.fetch("category") }.transform_values(&:size).sort.to_h,
  "attack_family_counts" => all_rows.select { |row| row.fetch("label") == 1 }
                                    .group_by { |row| row.fetch("attack_family") }
                                    .transform_values(&:size)
                                    .sort.to_h,
  "source_context_counts" => all_rows.group_by { |row| row.fetch("source_context") }
                                     .transform_values(&:size)
                                     .sort.to_h,
  "build_seed" => SEED
}

File.write(File.join(METADATA_DIR, "stats.json"), JSON.pretty_generate(stats) + "\n")

checksums = %w[train validation test].map do |split|
  relative_path = "data/#{split}.jsonl"
  digest = Digest::SHA256.file(File.join(ROOT, relative_path)).hexdigest
  "#{digest}  #{relative_path}"
end
File.write(File.join(METADATA_DIR, "checksums.sha256"), checksums.join("\n") + "\n")

puts JSON.pretty_generate(stats)
