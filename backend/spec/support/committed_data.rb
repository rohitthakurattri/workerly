# For specs that commit for real (use_transactional_tests = false, e.g. thread races): empties
# every table afterwards. Append-only tables refuse TRUNCATE, so this uses the operator escape
# hatch (AppendOnly.rewriting), which is what it exists for.
module CommittedData
  def truncate_committed_data!
    conn = ActiveRecord::Base.connection
    AppendOnly.rewriting { conn.truncate_tables(*(conn.tables - %w[schema_migrations ar_internal_metadata])) }
  end
end

RSpec.configure { |c| c.include CommittedData }
