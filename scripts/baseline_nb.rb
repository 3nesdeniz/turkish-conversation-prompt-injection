#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

ROOT = File.expand_path("..", __dir__)
CLASSES = [0, 1].freeze
ALPHA = 1.0

def load_split(name)
  path = File.join(ROOT, "data", "#{name}.jsonl")
  File.readlines(path, chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
end

def features(text)
  words = text.downcase.scan(/[[:alnum:]_çğıöşü]+/u)
  (words + words.each_cons(2).map { |first, second| "#{first}__#{second}" }).uniq
end

def predict(row, counts, totals, documents, vocabulary)
  document_total = documents.values.inject(0, :+).to_f
  scores = {}

  CLASSES.each do |label|
    score = Math.log(documents.fetch(label) / document_total)
    denominator = totals.fetch(label) + ALPHA * vocabulary.size
    features(row.fetch("text")).each do |feature|
      score += Math.log((counts.fetch(label)[feature] + ALPHA) / denominator)
    end
    scores[label] = score
  end

  scores.max_by { |_label, score| score }.first
end

def evaluate(rows, counts, totals, documents, vocabulary)
  predictions = rows.map do |row|
    [row, predict(row, counts, totals, documents, vocabulary)]
  end

  tp = predictions.count { |row, predicted| row["label"] == 1 && predicted == 1 }
  fp = predictions.count { |row, predicted| row["label"] == 0 && predicted == 1 }
  tn = predictions.count { |row, predicted| row["label"] == 0 && predicted == 0 }
  fn = predictions.count { |row, predicted| row["label"] == 1 && predicted == 0 }

  precision = tp.to_f / [tp + fp, 1].max
  recall = tp.to_f / [tp + fn, 1].max
  f1 = 2 * precision * recall / [precision + recall, 1e-9].max
  specificity = tn.to_f / [tn + fp, 1].max
  balanced_accuracy = 0.5 * (recall + specificity)

  {
    predictions: predictions,
    tp: tp,
    fp: fp,
    tn: tn,
    fn: fn,
    precision: precision,
    recall: recall,
    f1: f1,
    balanced_accuracy: balanced_accuracy
  }
end

train = load_split("train")
counts = { 0 => Hash.new(0), 1 => Hash.new(0) }
totals = { 0 => 0, 1 => 0 }
documents = { 0 => 0, 1 => 0 }
vocabulary = {}

train.each do |row|
  label = row.fetch("label")
  documents[label] += 1
  features(row.fetch("text")).each do |feature|
    counts[label][feature] += 1
    totals[label] += 1
    vocabulary[feature] = true
  end
end

%w[validation test].each do |split|
  result = evaluate(load_split(split), counts, totals, documents, vocabulary)
  puts "#{split}:"
  puts "  confusion: TP=#{result[:tp]} FP=#{result[:fp]} TN=#{result[:tn]} FN=#{result[:fn]}"
  puts format("  precision=%.3f recall=%.3f f1=%.3f balanced_accuracy=%.3f",
              result[:precision], result[:recall], result[:f1], result[:balanced_accuracy])

  next unless split == "test"

  puts "  errors by category:"
  result[:predictions].group_by { |row, _prediction| row.fetch("category") }.sort.each do |category, items|
    errors = items.count { |row, prediction| row.fetch("label") != prediction }
    puts "    #{category}: #{errors}/#{items.size}"
  end

  puts "  attack recall by family:"
  result[:predictions]
        .select { |row, _prediction| row.fetch("label") == 1 }
        .group_by { |row, _prediction| row.fetch("attack_family") }
        .sort
        .each do |family, items|
    detected = items.count { |_row, prediction| prediction == 1 }
    puts "    #{family}: #{detected}/#{items.size}"
  end
end
