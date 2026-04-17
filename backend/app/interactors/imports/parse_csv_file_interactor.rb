# frozen_string_literal: true

require 'csv'

module Imports
  # Читает файл, нормализует кодировку и возвращает CSV::Table (headers: true).
  class ParseCsvFileInteractor < BaseInteractor
    def call(file_path:)
      content = read_utf8_content(file_path)
      bom = "\xEF\xBB\xBF".force_encoding('UTF-8')
      content.sub!(bom, '') if content.start_with?(bom)
      content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

      separator = detect_separator(content)
      csv = parse_csv_table(content, separator)
      success(csv)
    rescue StandardError => e
      msg = e.message.to_s.force_encoding('UTF-8')
      Rails.logger.error "CSV parse error: #{msg}\n#{e.backtrace&.join("\n")}"
      failure(:import_error, "CSV read/parse failed: #{msg}")
    end

    private

    def read_utf8_content(file_path)
      content = File.read(file_path).force_encoding('UTF-8')
      unless content.valid_encoding?
        content = File.read(file_path).force_encoding('Windows-1251').encode('UTF-8')
      end
      content
    rescue StandardError
      File.read(file_path)
    end

    def detect_separator(content)
      first_line = content.each_line.first
      return ',' if first_line.blank?

      if first_line.include?(';')
        ';'
      elsif first_line.include?("\t")
        "\t"
      else
        ','
      end
    end

    def parse_csv_table(content, separator)
      CSV.parse(content, headers: true, col_sep: separator, quote_char: '"', liberal_parsing: true)
    rescue CSV::MalformedCSVError
      CSV.parse(content, headers: true, col_sep: separator, quote_char: nil)
    end
  end
end
