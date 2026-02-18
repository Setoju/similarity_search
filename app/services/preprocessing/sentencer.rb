require "pragmatic_segmenter"
require "whatlanguage"

module Preprocessing
  class Sentencer
    LANGUAGE_MAP = {
      english: "en",
      spanish: "es",
      french: "fr",
      german: "de",
      italian: "it",
      portuguese: "pt",
      russian: "ru",
      dutch: "nl",
      swedish: "sv",
      danish: "da",
      norwegian: "no",
      polish: "pl",
      arabic: "ar",
      persian: "fa",
      japanese: "ja",
      chinese: "zh",
      hindi: "hi",
      greek: "el",
      bulgarian: "bg",
      kazakh: "kk",
      catalan: "ca",
      burmese: "my",
      amharic: "am"
    }.freeze

    def initialize(text, offset: 0)
      @text = text
      @offset = offset
    end

    def call
      return [] if @text.blank?

      language = detect_language(@text)
      segmenter = PragmaticSegmenter::Segmenter.new(text: @text, language: language)
      raw_sentences = segmenter.segment

      sentences = []
      current_position = 0

      raw_sentences.each do |sentence|
        # Find where this sentence starts in the original text
        start_in_text = @text.index(sentence, current_position)
        next if start_in_text.nil?

        end_in_text = start_in_text + sentence.length

        sentences << {
          start_char: @offset + start_in_text,
          end_char: @offset + end_in_text,
          content: sentence.strip
        }

        current_position = end_in_text
      end

      sentences
    end

    def self.call(text, **options)
      new(text, **options).call
    end

    private

    def detect_language(text)
      wl = WhatLanguage.new(:all)
      detected = wl.language(text)
      LANGUAGE_MAP[detected] || "en"
    end
  end
end
