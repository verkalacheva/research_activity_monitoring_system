# frozen_string_literal: true

module Achievements
  class ImportCommand < BaseCommand
    def call(file_path:)
      parsed = Imports::ParseCsvFileInteractor.call(file_path: file_path)
      return parsed if parsed.failure?

      csv = parsed.value!
      results = { success: 0, failure: 0, errors: [] }

      csv.each_with_index do |row, index|
        next if row.to_h.values.all?(&:blank?)

        row_pairs = row.to_a
        result = Achievements::ImportRowInteractor.call(row_pairs: row_pairs)
        if result.success?
          results[:success] += 1
        else
          results[:failure] += 1
          results[:errors] << "Row #{index + 2}: #{import_failure_message(result)}"
        end
      end

      success(results)
    rescue StandardError => e
      msg = e.message.to_s.force_encoding('UTF-8')
      Rails.logger.error "Import error: #{msg}"
      Rails.logger.error e.backtrace.join("\n")
      failure(:import_error, "Import failed: #{msg}")
    end

    private

    def import_failure_message(result)
      f = result.failure
      return f.to_s unless f.is_a?(Hash)

      f[:errors] || f[:message] || f[:type]
    end
  end
end
