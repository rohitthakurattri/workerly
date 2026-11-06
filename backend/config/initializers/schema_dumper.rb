# schema.rb can't express functions or triggers, so our own (named workerly_*) are appended to it
# as raw SQL. A database loaded from schema.rb (test, CI, a new machine) then has the same
# append-only triggers as a migrated one, without switching to structure.sql (which would need
# pg_dump/psql matching the server on every machine). PostGIS's functions are left out by the prefix.
module Workerly
  module SchemaDumperTriggers
    private

    def trailer(stream)
      functions = @connection.select_values(<<~SQL)
        SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname LIKE 'workerly\\_%' ORDER BY p.proname
      SQL
      triggers = @connection.select_values(<<~SQL)
        SELECT pg_get_triggerdef(t.oid) FROM pg_trigger t
        WHERE NOT t.tgisinternal AND t.tgname LIKE 'workerly\\_%' ORDER BY t.tgrelid::regclass::text, t.tgname
      SQL

      if functions.any? || triggers.any?
        stream.puts
        stream.puts "  # Functions and triggers (config/initializers/schema_dumper.rb)"
        (functions + triggers).each do |sql|
          stream.puts "  execute <<~'SQL'"
          sql.strip.each_line { |line| stream.puts line.strip.empty? ? "" : "    #{line.rstrip}" }
          stream.puts "  SQL"
        end
      end
      super
    end
  end
end

ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/postgresql_adapter"
  ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend(Workerly::SchemaDumperTriggers)
end
