module Shared
  # Keyset (cursor) pagination over an ordered pair of columns, the last being the unique id.
  # Stable under inserts, and no OFFSET scans.
  class Pagination
    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    Page = Data.define(:records, :next_cursor)

    def self.call(...) = new(...).call

    # order: e.g. { submitted_at: :asc, id: :asc } (id must be last)
    def initialize(scope, order:, cursor: nil, limit: nil)
      @scope = scope
      @order = order
      @cursor = cursor
      @limit = (limit.presence || DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
    end

    def call
      relation = @scope.reorder(@order)
      relation = relation.where(*after_clause) if @cursor.present?
      rows = relation.limit(@limit + 1).to_a
      more = rows.size > @limit
      rows = rows.first(@limit)
      Page.new(records: rows, next_cursor: more ? encode(rows.last) : nil)
    end

    private

    def encode(record)
      Base64.urlsafe_encode64(@order.keys.map { |c| serialize(record.public_send(c)) }.to_json, padding: false)
    end

    def serialize(value) = value.respond_to?(:iso8601) ? value.iso8601(6) : value

    def decode
      values = JSON.parse(Base64.urlsafe_decode64(@cursor))
      raise ArgumentError unless values.is_a?(Array) && values.size == @order.size

      values
    rescue ArgumentError, JSON::ParserError
      raise ApplicationError.new(:invalid_cursor, status: :bad_request)
    end

    # Row-value comparison, e.g. (submitted_at, id) > (?, ?). Mixed directions are not supported.
    def after_clause
      directions = @order.values.uniq
      raise ArgumentError, "mixed sort directions" if directions.size > 1

      table = @scope.klass.quoted_table_name
      cols = @order.keys.map { |c| "#{table}.#{@scope.klass.connection.quote_column_name(c)}" }.join(", ")
      op = directions.first == :desc ? "<" : ">"
      [ "(#{cols}) #{op} (#{([ '?' ] * @order.size).join(', ')})", *decode ]
    end
  end
end
