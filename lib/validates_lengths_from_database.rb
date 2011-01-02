require "rubygems"
require "active_record"

module ValidatesLengthsFromDatabase
  def self.included(base)
    base.send(:extend, ClassMethods)
    base.send(:include, InstanceMethods)
  end

  module ClassMethods
    def validates_lengths_from_database(options = {})
      options.symbolize_keys!

      if options[:only]
        columns_to_validate = Array(options[:only]).map(&:to_s)
      else
        columns_to_validate = column_names.map(&:to_s)
        columns_to_validate -= Array(options[:except]).map(&:to_s) if options[:except]
      end

      columns_to_validate.each do |column|
        column_schema = columns.find {|c| c.name == column }
        next if column_schema.nil?
        next if column_schema.name[/id$/]
        next if ![:string, :text, :decimal, :integer].include?(column_schema.type)

        class_eval do
          validates_length_of column, :maximum => column_schema.limit, :allow_blank => true if column_schema.limit.present? and [:string, :text].include?(column_schema.type)
          if column_schema.type == :decimal
            before_validation {|record| errors.add(column, "Precision must have a maximum length of #{column_schema.precision}") if record[column].to_s.gsub('.','').length > column_schema.precision }
            before_validation {|record| errors.add(column, "Scale must have a maximum length of #{column_schema.scale}") if a = record[column].to_s.split('.')[1] and a.length > column_schema.scale }
          end
          if column_schema.type == :integer and Testing.configurations[Rails.env]['adapter'][/mysql/]
            validates_numericality_of column, :greater_than_or_equal_to => -2**(column_schema.limit*8) / 2, :less_than => (2**(column_schema.limit*8) / 2), :allow_blank => true
          end
        end 
      end
      nil
    end

  end

  module InstanceMethods
  end
end

require "validates_lengths_from_database/railtie"
